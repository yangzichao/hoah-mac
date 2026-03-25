import Foundation
import os
import Zip
import SwiftUI
import Atomics


struct WhisperModel: Identifiable {
    let id = UUID()
    let name: String
    let url: URL
    var coreMLEncoderURL: URL? // Path to the unzipped .mlmodelc directory
    var isCoreMLDownloaded: Bool { coreMLEncoderURL != nil }
    
    private var downloadURLPaths: [String] {
        [
            "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/\(filename)",
            "https://hf-mirror.com/ggerganov/whisper.cpp/resolve/main/\(filename)"
        ]
    }

    var downloadURL: String {
        // Keep compatibility for existing call sites while using the primary source.
        downloadURLPaths[0]
    }

    var downloadURLCandidates: [String] {
        downloadURLPaths
    }
    
    var filename: String {
        "\(name).bin"
    }
    
    // Core ML related properties
    private var coreMLZipDownloadURLPaths: [String]? {
        // Only non-quantized models have Core ML versions
        guard !name.contains("q5") && !name.contains("q8") else { return nil }
        return [
            "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/\(name)-encoder.mlmodelc.zip",
            "https://hf-mirror.com/ggerganov/whisper.cpp/resolve/main/\(name)-encoder.mlmodelc.zip"
        ]
    }

    var coreMLZipDownloadURL: String? {
        coreMLZipDownloadURLPaths?.first
    }

    var coreMLZipDownloadURLCandidates: [String] {
        coreMLZipDownloadURLPaths ?? []
    }
    
    var coreMLEncoderDirectoryName: String? {
        guard coreMLZipDownloadURL != nil else { return nil }
        return "\(name)-encoder.mlmodelc"
    }
}

private class TaskDelegate: NSObject, URLSessionTaskDelegate {
    private let continuation: CheckedContinuation<Void, Never>
    private let finished = ManagedAtomic(false)

    init(_ continuation: CheckedContinuation<Void, Never>) {
        self.continuation = continuation
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        // Ensure continuation is resumed only once, even if called multiple times
        if finished.exchange(true, ordering: .acquiring) == false {
            continuation.resume()
        }
    }
}

// MARK: - Model Management Extension
extension WhisperState {

    
    
    // MARK: - Model Directory Management
    
    func createModelsDirectoryIfNeeded() {
        do {
            try FileManager.default.createDirectory(at: modelsDirectory, withIntermediateDirectories: true, attributes: nil)
        } catch {
            logError("Error creating models directory", error)
        }
    }
    
    func loadAvailableModels() {
        do {
            let fileURLs = try FileManager.default.contentsOfDirectory(at: modelsDirectory, includingPropertiesForKeys: nil)
            availableModels = fileURLs.compactMap { url in
                guard url.pathExtension == "bin" else { return nil }
                return WhisperModel(name: url.deletingPathExtension().lastPathComponent, url: url)
            }
        } catch {
            logError("Error loading available models", error)
        }
    }
    
    // MARK: - Model Loading
    
    func loadModel(_ model: WhisperModel) async throws {
        guard whisperContext == nil, !isModelLoading else { return }

        isModelLoading = true
        defer { isModelLoading = false }
        
        do {
            whisperContext = try await WhisperContext.createContext(path: model.url.path)
            
            // Set the prompt from UserDefaults to ensure we have the latest
            let currentPrompt = UserDefaults.hoah.string(forKey: "TranscriptionPrompt") ?? whisperPrompt.transcriptionPrompt
            await whisperContext?.setPrompt(currentPrompt)
            
            isModelLoaded = true
            loadedLocalModel = model
        } catch {
            throw WhisperStateError.modelLoadFailed
        }
    }
    
    // MARK: - Model Download & Management
    
    /// Helper function to download a file from a URL with progress tracking
    private func downloadFileWithProgress(from url: URL, progressKey: String) async throws -> Data {
        let destinationURL = modelsDirectory.appendingPathComponent(UUID().uuidString)

        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Data, Error>) in
            // Guard to prevent double resume
            let finished = ManagedAtomic(false)

            func finishOnce(_ result: Result<Data, Error>) {
                if finished.exchange(true, ordering: .acquiring) == false {
                    continuation.resume(with: result)
                }
            }

            let task = URLSession.shared.downloadTask(with: url) { tempURL, response, error in
                if let error = error {
                    finishOnce(.failure(error))
                    return
                }

                guard let httpResponse = response as? HTTPURLResponse,
                      (200...299).contains(httpResponse.statusCode),
                      let tempURL = tempURL else {
                    finishOnce(.failure(URLError(.badServerResponse)))
                    return
                }

                do {
                    // Move the downloaded file to the final destination
                    try FileManager.default.moveItem(at: tempURL, to: destinationURL)

                    // Read the file in chunks to avoid memory pressure
                    let data = try Data(contentsOf: destinationURL, options: .mappedIfSafe)
                    finishOnce(.success(data))

                    // Clean up the temporary file
                    try? FileManager.default.removeItem(at: destinationURL)
                } catch {
                    finishOnce(.failure(error))
                }
            }

            task.resume()

            var lastUpdateTime = Date()
            var lastProgressValue: Double = 0

            let observation = task.progress.observe(\.fractionCompleted) { progress, _ in
                let currentTime = Date()
                let timeSinceLastUpdate = currentTime.timeIntervalSince(lastUpdateTime)
                let currentProgress = round(progress.fractionCompleted * 100) / 100

                if timeSinceLastUpdate >= 0.5 && abs(currentProgress - lastProgressValue) >= 0.01 {
                    lastUpdateTime = currentTime
                    lastProgressValue = currentProgress

                    DispatchQueue.main.async {
                        self.downloadProgress[progressKey] = currentProgress
                    }
                }
            }

            Task {
                await withTaskCancellationHandler {
                    observation.invalidate()
                    // Also ensure continuation is resumed with cancellation if task is cancelled
                    if finished.exchange(true, ordering: .acquiring) == false {
                        continuation.resume(throwing: CancellationError())
                    }
                } operation: {
                    await withCheckedContinuation { (_: CheckedContinuation<Void, Never>) in }
                }
            }
        }
    }
    func downloadModel(_ model: LocalModel) async {
        let mainKey = model.name + "_main"
        let coreMLKey = model.name + "_coreml"

        // Prevent duplicate taps from spawning parallel downloads for the same model.
        if downloadProgress[mainKey] != nil || downloadProgress[coreMLKey] != nil {
            return
        }

        // Mark downloading immediately so UI can switch to "Downloading..." instantly.
        await MainActor.run {
            self.downloadProgress[mainKey] = 0.0
        }

        await performModelDownload(model)
    }
    
    private func performModelDownload(_ model: LocalModel) async {
        do {
            var whisperModel = try await downloadMainModel(model)
            
            if !whisperModel.coreMLZipDownloadURLCandidates.isEmpty {
                whisperModel = try await downloadAndSetupCoreMLModel(for: whisperModel)
            }
            
            availableModels.append(whisperModel)
            self.downloadProgress.removeValue(forKey: model.name + "_main")

            if shouldWarmup(model) {
                WhisperModelWarmupCoordinator.shared.scheduleWarmup(
                    for: model,
                    whisperState: self,
                    reason: "post download"
                )
            }
        } catch {
            handleModelDownloadError(model, error)
        }
    }
    
    private func downloadMainModel(_ model: LocalModel) async throws -> WhisperModel {
        let progressKeyMain = model.name + "_main"
        var lastError: Error?
        var data: Data?
        for candidate in model.downloadURLCandidates {
            guard let url = URL(string: candidate) else { continue }
            do {
                data = try await downloadFileWithProgress(from: url, progressKey: progressKeyMain)
                break
            } catch {
                lastError = error
            }
        }
        guard let data else {
            throw lastError ?? URLError(.badURL)
        }
        
        let destinationURL = modelsDirectory.appendingPathComponent(model.filename)
        try data.write(to: destinationURL)
        
        return WhisperModel(name: model.name, url: destinationURL)
    }
    
    private func downloadAndSetupCoreMLModel(for model: WhisperModel) async throws -> WhisperModel {
        let progressKeyCoreML = model.name + "_coreml"
        var lastError: Error?
        var coreMLData: Data?
        for candidate in model.coreMLZipDownloadURLCandidates {
            guard let url = URL(string: candidate) else { continue }
            do {
                coreMLData = try await downloadFileWithProgress(from: url, progressKey: progressKeyCoreML)
                break
            } catch {
                lastError = error
            }
        }
        guard let coreMLData else {
            throw lastError ?? URLError(.badURL)
        }
        
        let coreMLZipPath = modelsDirectory.appendingPathComponent("\(model.name)-encoder.mlmodelc.zip")
        try coreMLData.write(to: coreMLZipPath)
        
        return try await unzipAndSetupCoreMLModel(for: model, zipPath: coreMLZipPath, progressKey: progressKeyCoreML)
    }
    
    private func unzipAndSetupCoreMLModel(for model: WhisperModel, zipPath: URL, progressKey: String) async throws -> WhisperModel {
        let coreMLDestination = modelsDirectory.appendingPathComponent("\(model.name)-encoder.mlmodelc")
        
        try? FileManager.default.removeItem(at: coreMLDestination)
        try await unzipCoreMLFile(zipPath, to: modelsDirectory)
        return try verifyAndCleanupCoreMLFiles(model, coreMLDestination, zipPath, progressKey)
    }
    
    private func unzipCoreMLFile(_ zipPath: URL, to destination: URL) async throws {
        let finished = ManagedAtomic(false)

        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            func finishOnce(_ result: Result<Void, Error>) {
                if finished.exchange(true, ordering: .acquiring) == false {
                    continuation.resume(with: result)
                }
            }

            do {
                try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true)
                try Zip.unzipFile(zipPath, destination: destination, overwrite: true, password: nil)
                finishOnce(.success(()))
            } catch {
                finishOnce(.failure(error))
            }
        }
    }
    
    private func verifyAndCleanupCoreMLFiles(_ model: WhisperModel, _ destination: URL, _ zipPath: URL, _ progressKey: String) throws -> WhisperModel {
        var model = model
        
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: destination.path, isDirectory: &isDirectory), isDirectory.boolValue else {
            try? FileManager.default.removeItem(at: zipPath)
            throw WhisperStateError.unzipFailed
        }
        
        try? FileManager.default.removeItem(at: zipPath)
        model.coreMLEncoderURL = destination
        self.downloadProgress.removeValue(forKey: progressKey)
        
        return model
    }

    private func shouldWarmup(_ model: LocalModel) -> Bool {
        true
    }
    
    private func handleModelDownloadError(_ model: LocalModel, _ error: Error) {
        self.downloadProgress.removeValue(forKey: model.name + "_main")
        self.downloadProgress.removeValue(forKey: model.name + "_coreml")
    }
    
    func deleteModel(_ model: WhisperModel) async {
        do {
            // Delete main model file
            try FileManager.default.removeItem(at: model.url)
            
            // Delete CoreML model if it exists
            if let coreMLURL = model.coreMLEncoderURL {
                try? FileManager.default.removeItem(at: coreMLURL)
            } else {
                // Check if there's a CoreML directory matching the model name
                let coreMLDir = modelsDirectory.appendingPathComponent("\(model.name)-encoder.mlmodelc")
                if FileManager.default.fileExists(atPath: coreMLDir.path) {
                    try? FileManager.default.removeItem(at: coreMLDir)
                }
            }
            
            // Update model state
            availableModels.removeAll { $0.id == model.id }
            if currentTranscriptionModel?.name == model.name {

                currentTranscriptionModel = nil
                UserDefaults.hoah.removeObject(forKey: "CurrentTranscriptionModel")

                loadedLocalModel = nil
                recordingState = .idle
                UserDefaults.hoah.removeObject(forKey: "CurrentModel")
            }
        } catch {
            logError("Error deleting model: \(model.name)", error)
        }

        // Ensure UI reflects removal of imported models as well
        await MainActor.run {
            self.refreshAllAvailableModels()
        }
    }
    
    func unloadModel() {
        Task {
            await whisperContext?.releaseResources()
            whisperContext = nil
            isModelLoaded = false
            
            if let recordedFile = recordedFile {
                try? FileManager.default.removeItem(at: recordedFile)
                self.recordedFile = nil
            }
        }
    }
    
    func clearDownloadedModels() async {
        for model in availableModels {
            do {
                try FileManager.default.removeItem(at: model.url)
            } catch {
                logError("Error deleting model during cleanup", error)
            }
        }
        availableModels.removeAll()
    }
    
    // MARK: - Resource Management
    
    func cleanupModelResources() async {
        await whisperContext?.releaseResources()
        whisperContext = nil
        isModelLoaded = false
    }
    
    // MARK: - Helper Methods
    
    func warmupActiveLocalModel(reason: String, force: Bool = false) {
        guard let localModel = currentTranscriptionModel as? LocalModel else { return }
        guard availableModels.contains(where: { $0.name == localModel.name }) else { return }
        WhisperModelWarmupCoordinator.shared.scheduleWarmup(
            for: localModel,
            whisperState: self,
            reason: reason,
            force: force
        )
    }
    
    private func logError(_ message: String, _ error: Error) {
        self.logger.error("\(message): \(error.localizedDescription)")
    }

}

// MARK: - Download Progress View
struct DownloadProgressView: View {
    let modelName: String
    let downloadProgress: [String: Double]
    
    @Environment(\.colorScheme) private var colorScheme
    
    private var mainProgress: Double {
        downloadProgress[modelName + "_main"] ?? 0
    }
    
    private var coreMLProgress: Double {
        supportsCoreML ? (downloadProgress[modelName + "_coreml"] ?? 0) : 0
    }
    
    private var supportsCoreML: Bool {
        !modelName.contains("q5") && !modelName.contains("q8")
    }
    
    private var totalProgress: Double {
        supportsCoreML ? (mainProgress * 0.5) + (coreMLProgress * 0.5) : mainProgress
    }
    
    private var downloadPhase: String {
        // Check if we're currently downloading the CoreML model
        if supportsCoreML && downloadProgress[modelName + "_coreml"] != nil {
            return "Downloading Core ML Model for \(modelName)"
        }
        // Otherwise, we're downloading the main model
        return "Downloading \(modelName) Model"
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Status text with clean typography
            Text(downloadPhase)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(Color(.secondaryLabelColor))
            
            // Clean progress bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Background track
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color(.separatorColor).opacity(0.3))
                        .frame(height: 6)
                    
                    // Progress indicator
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color(.controlAccentColor))
                        .frame(width: max(0, min(geometry.size.width * totalProgress, geometry.size.width)), height: 6)
                }
            }
            .frame(height: 6)
            
            // Percentage indicator in Apple style
            HStack {
                Spacer()
                Text("\(Int(totalProgress * 100))%")
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundColor(Color(.secondaryLabelColor))
            }
        }
        .padding(.vertical, 4)
        .animation(.smooth, value: totalProgress)
    }
} 
