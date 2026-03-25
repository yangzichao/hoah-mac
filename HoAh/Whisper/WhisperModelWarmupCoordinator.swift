import Foundation
import Combine

@MainActor
final class WhisperModelWarmupCoordinator: ObservableObject {
    static let shared = WhisperModelWarmupCoordinator()
    
    @Published private(set) var warmingModels: Set<String> = []
    private var warmupTimestamps: [String: Date] = [:]
    private var failedWarmups: Set<String> = []
    private var warmupTasks: [String: Task<Void, Never>] = [:]
    private var retryTasks: [String: Task<Void, Never>] = [:]
    private var isShuttingDown = false
    private let retryDelayNanoseconds: UInt64 = 5_000_000_000
    private let warmupStaleness: TimeInterval = 30 * 60
    
    private init() {}
    
    func isWarming(modelNamed name: String) -> Bool {
        warmingModels.contains(name)
    }
    
    func scheduleWarmup(
        for model: LocalModel,
        whisperState: WhisperState,
        reason: String? = nil,
        allowRetry: Bool = true,
        force: Bool = false
    ) {
        guard !isShuttingDown else { return }
        guard shouldWarmup(modelName: model.name),
              !warmingModels.contains(model.name) else {
            return
        }
        
        if !force, let lastWarmup = warmupTimestamps[model.name], Date().timeIntervalSince(lastWarmup) < warmupStaleness {
            return
        }
        
        warmingModels.insert(model.name)
        if let reason {
            whisperState.logger.info("Scheduling warmup for \(model.name, privacy: .public) (\(reason))")
        }
        
        warmupTasks[model.name]?.cancel()
        let warmupTask = Task {
            var didSucceed = false
            do {
                try await runWarmup(for: model, whisperState: whisperState)
                didSucceed = true
            } catch {
                guard !Task.isCancelled, !self.isShuttingDown else {
                    await MainActor.run {
                        self.warmingModels.remove(model.name)
                        self.warmupTasks[model.name] = nil
                    }
                    return
                }
                await MainActor.run {
                    if !failedWarmups.contains(model.name) {
                        NotificationManager.shared.showNotification(
                            title: "Model warmup failed for \(model.displayName)",
                            type: .warning
                        )
                    }
                    failedWarmups.insert(model.name)
                    whisperState.logger.error("Warmup failed for \(model.name): \(error.localizedDescription)")
                }
            }
            
            await MainActor.run {
                self.warmingModels.remove(model.name)
                self.warmupTasks[model.name] = nil
                if didSucceed {
                    self.warmupTimestamps[model.name] = Date()
                    self.failedWarmups.remove(model.name)
                } else if allowRetry, !self.isShuttingDown {
                    self.retryTasks[model.name]?.cancel()
                    self.retryTasks[model.name] = Task {
                        try? await Task.sleep(nanoseconds: retryDelayNanoseconds)
                        guard !Task.isCancelled else { return }
                        await MainActor.run {
                            self.retryTasks[model.name] = nil
                            self.scheduleWarmup(
                                for: model,
                                whisperState: whisperState,
                                reason: "retry after failure",
                                allowRetry: false,
                                force: force
                            )
                        }
                    }
                }
            }
        }
        warmupTasks[model.name] = warmupTask
    }

    func cancelAllWarmups() {
        isShuttingDown = true
        // Cancel retry tasks immediately — they are only sleeping, no Metal work in progress.
        for task in retryTasks.values {
            task.cancel()
        }
        retryTasks.removeAll()
        // Warmup tasks are intentionally NOT cancelled here.
        // Cancelling a Swift Task does not interrupt the underlying C-level whisper inference
        // or Metal resource initialization already in progress. Calling cleanupModelResources()
        // while those ops are live causes ggml_metal_rsets_free to abort (rsets->data count != 0).
        // Callers must await waitForPendingWarmups() before releasing any WhisperContext.
    }

    /// Waits for all in-flight warmup tasks to finish releasing their WhisperContexts.
    /// Must be called after cancelAllWarmups() and before cleanupModelResources().
    func waitForPendingWarmups() async {
        let tasks = Array(warmupTasks.values)
        warmupTasks.removeAll()
        warmingModels.removeAll()
        for task in tasks {
            _ = await task.value
        }
    }
    
    private func runWarmup(for model: LocalModel, whisperState: WhisperState) async throws {
        guard let sampleURL = warmupSampleURL() else {
            throw WarmupError.sampleMissing
        }
        let service = LocalTranscriptionService(
            modelsDirectory: whisperState.modelsDirectory,
            whisperState: whisperState
        )
        _ = try await service.transcribe(audioURL: sampleURL, model: model)
    }
    
    private func warmupSampleURL() -> URL? {
        let bundle = Bundle.main
        let candidates: [URL?] = [
            bundle.url(forResource: "esc", withExtension: "wav", subdirectory: "Resources/Sounds"),
            bundle.url(forResource: "esc", withExtension: "wav", subdirectory: "Sounds"),
            bundle.url(forResource: "esc", withExtension: "wav")
        ]

        for candidate in candidates {
            if let url = candidate {
                return url
            }
        }

        return nil
    }
    
    private func shouldWarmup(modelName: String) -> Bool {
        true
    }
}

private enum WarmupError: LocalizedError {
    case sampleMissing
    
    var errorDescription: String? {
        switch self {
        case .sampleMissing:
            return "Warmup sample audio is missing"
        }
    }
}
