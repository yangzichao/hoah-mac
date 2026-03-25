import Foundation
import Combine

@MainActor
final class WhisperModelWarmupCoordinator: ObservableObject {
    static let shared = WhisperModelWarmupCoordinator()
    
    @Published private(set) var warmingModels: Set<String> = []
    private var warmupTimestamps: [String: Date] = [:]
    private var failedWarmups: Set<String> = []
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
        
        Task {
            var didSucceed = false
            do {
                try await runWarmup(for: model, whisperState: whisperState)
                didSucceed = true
            } catch {
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
                if didSucceed {
                    self.warmupTimestamps[model.name] = Date()
                    self.failedWarmups.remove(model.name)
                } else if allowRetry {
                    Task {
                        try? await Task.sleep(nanoseconds: retryDelayNanoseconds)
                        await MainActor.run {
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
