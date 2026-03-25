import Foundation
import SwiftUI
import AVFoundation
import SwiftData
import AppKit
import KeyboardShortcuts
import os

// MARK: - Recording State Machine
enum RecordingState: Equatable {
    case idle
    case recording
    case finishing
    case transcribing
    case enhancing
    case busy
}

@MainActor
class WhisperState: NSObject, ObservableObject {
    @Published var recordingState: RecordingState = .idle
    @Published var isModelLoaded = false
    @Published var loadedLocalModel: WhisperModel?
    @Published var currentTranscriptionModel: (any TranscriptionModel)?
    @Published var isModelLoading = false
    @Published var availableModels: [WhisperModel] = []
    @Published var allAvailableModels: [any TranscriptionModel] = PredefinedModels.models
    @Published var clipboardMessage = ""
    @Published var miniRecorderError: String?
    @Published var shouldCancelRecording = false
    var isTogglingRecorder = false
    @Published var liveCommittedTranscript = ""
    @Published var livePartialTranscript = ""
    @Published var liveStreamingError: String?
    private var recordingTimeoutTask: Task<Void, Never>?

    // Recorder type is managed by AppSettingsStore
    // This computed property provides read access for compatibility
    var recorderType: String {
        // Will be injected via appSettings reference
        return appSettings?.recorderType ?? "mini"
    }
    
    // Reference to AppSettingsStore (injected)
    weak var appSettings: AppSettingsStore?
    
    @Published var isMiniRecorderVisible = false {
        didSet {
            if isMiniRecorderVisible {
                showRecorderPanel()
            } else {
                hideRecorderPanel()
            }
        }
    }
    
    var whisperContext: WhisperContext?
    let recorder = Recorder()
    var recordedFile: URL? = nil
    let whisperPrompt = WhisperPrompt()
    private let realtimeTranscriptBuffer = RealtimeTranscriptBuffer()
    private var realtimeStreamingService: (any StreamingTranscriptionService)?
    private var realtimeEventsTask: Task<Void, Never>?
    private var realtimeAudioChunkContinuation: AsyncStream<Data>.Continuation?
    private var realtimeAudioSendTask: Task<Void, Never>?
    private var realtimeSessionStartedAt: Date?
    private var lastRealtimeEventAt: Date?
    private var recordingSessionModel: (any TranscriptionModel)?
    private var lastRealtimeStreamingFailure: Error?
    private var isRealtimeRecordingSession = false
    private var isShuttingDown = false
    
    let modelContext: ModelContext
    
    // Transcription Services
    private var localTranscriptionService: LocalTranscriptionService!
    private lazy var cloudTranscriptionService = CloudTranscriptionService()
    private lazy var nativeAppleTranscriptionService = NativeAppleTranscriptionService()
    
    let modelsDirectory: URL
    let recordingsDirectory: URL
    let enhancementService: AIEnhancementService?
    let logger = Logger(subsystem: "com.yangzichao.hoah", category: "WhisperState")
    var notchWindowManager: NotchWindowManager?
    var miniWindowManager: MiniWindowManager?
    
    // For model progress tracking
    @Published var downloadProgress: [String: Double] = [:]
    
    init(modelContext: ModelContext, enhancementService: AIEnhancementService? = nil) {
        self.modelContext = modelContext
        let appSupportDirectory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("com.yangzichao.HoAh")
        
        self.modelsDirectory = appSupportDirectory.appendingPathComponent("WhisperModels")
        self.recordingsDirectory = appSupportDirectory.appendingPathComponent("Recordings")
        
        self.enhancementService = enhancementService
        
        super.init()
        
        // Set the whisperState reference after super.init()
        self.localTranscriptionService = LocalTranscriptionService(modelsDirectory: self.modelsDirectory, whisperState: self)
        
        setupNotifications()
        createModelsDirectoryIfNeeded()
        createRecordingsDirectoryIfNeeded()
        loadAvailableModels()
        loadCurrentTranscriptionModel()
        refreshAllAvailableModels()
    }
    
    private func createRecordingsDirectoryIfNeeded() {
        do {
            try FileManager.default.createDirectory(at: recordingsDirectory, withIntermediateDirectories: true, attributes: nil)
        } catch {
            logger.error("Error creating recordings directory: \(error.localizedDescription)")
        }
    }
    
    func toggleRecord() async {
        if recordingState == .recording {
            cancelRecordingTimeout()
            await MainActor.run {
                recordingState = .finishing
            }
            await recorder.stopRecording()
            if let recordedFile {
                if !shouldCancelRecording {
                    let audioAsset = AVURLAsset(url: recordedFile)
                    let duration = (try? CMTimeGetSeconds(await audioAsset.load(.duration))) ?? 0.0

                    let transcription = Transcription(
                        text: "",
                        duration: duration,
                        audioFileURL: recordedFile.absoluteString,
                        transcriptionStatus: .pending
                    )
                    modelContext.insert(transcription)
                    try? modelContext.save()
                    NotificationCenter.default.post(name: .transcriptionCreated, object: transcription)

                    if isRealtimeRecordingSession {
                        await finalizeRealtimeTranscription(on: transcription, recordedFile: recordedFile)
                    } else {
                        await transcribeAudio(on: transcription)
                    }
                } else {
                    await MainActor.run {
                        recordingState = .idle
                    }
                    await cleanupRealtimeStreamingSession()
                    await cleanupModelResources()
                    recordingSessionModel = nil
                    lastRealtimeStreamingFailure = nil
                }
            } else {
                logger.error("❌ No recorded file found after stopping recording")
                await MainActor.run {
                    recordingState = .idle
                }
                recordingSessionModel = nil
                lastRealtimeStreamingFailure = nil
            }
        } else {
            guard currentTranscriptionModel != nil else {
                await MainActor.run {
                    NotificationManager.shared.showNotification(
                        title: "No AI Model Selected",
                        type: .error
                    )
                }
                return
            }
            shouldCancelRecording = false
            requestRecordPermission { [self] granted in
                if granted {
                    Task {
                        do {
                            guard let selectedModel = self.currentTranscriptionModel else {
                                throw WhisperStateError.transcriptionFailed
                            }

                            // --- Prepare permanent file URL ---
                            let fileName = "\(UUID().uuidString).wav"
                            let permanentURL = self.recordingsDirectory.appendingPathComponent(fileName)
                            self.recordedFile = permanentURL
                            self.recordingSessionModel = selectedModel
                            self.lastRealtimeStreamingFailure = nil

                            if self.supportsRealtimeStreaming(for: selectedModel) {
                                do {
                                    try await self.startRealtimeRecording(with: selectedModel, toOutputFile: permanentURL)
                                } catch {
                                    if let fallbackModel = self.offlineFallbackLocalModel(for: selectedModel, error: error) {
                                        self.logger.warning(
                                            "Realtime start failed with connectivity issue. Falling back to local model \(fallbackModel.name, privacy: .public)"
                                        )
                                        self.recordingSessionModel = fallbackModel
                                        await self.cleanupRealtimeStreamingSession()
                                        try await self.recorder.startRecording(toOutputFile: permanentURL)
                                        await self.showOfflineFallbackNotification(from: selectedModel, to: fallbackModel)
                                    } else {
                                        throw error
                                    }
                                }
                            } else {
                                try await self.recorder.startRecording(toOutputFile: permanentURL)
                            }
                            
                            await MainActor.run {
                                self.recordingState = .recording
                                self.startRecordingTimeoutIfNeeded()
                            }
                            
                            // Only load model if it's a local model and not already loaded
                            if let model = self.recordingSessionModel, model.provider == .local {
                                if let localWhisperModel = self.availableModels.first(where: { $0.name == model.name }),
                                   self.whisperContext == nil {
                                    do {
                                        try await self.loadModel(localWhisperModel)
                                    } catch {
                                        self.logger.error("❌ Model loading failed: \(error.localizedDescription)")
                                    }
                                }
                            }
        
                        } catch {
                            self.logger.error("❌ Failed to start recording: \(error.localizedDescription)")
                            await NotificationManager.shared.showNotification(title: "Recording failed to start", type: .error)
                            await self.dismissMiniRecorder()
                            // Do not remove the file on a failed start, to preserve all recordings.
                            self.recordedFile = nil
                            self.recordingSessionModel = nil
                            self.lastRealtimeStreamingFailure = nil
                        }
                    }
                } else {
                    logger.error("❌ Recording permission denied.")
                }
            }
        }
    }
    
    private func requestRecordPermission(response: @escaping (Bool) -> Void) {
        response(true)
    }
    
    private func transcribeAudio(on transcription: Transcription) async {
        defer {
            recordingSessionModel = nil
            lastRealtimeStreamingFailure = nil
        }

        guard let urlString = transcription.audioFileURL, let url = URL(string: urlString) else {
            logger.error("❌ Invalid audio file URL in transcription object.")
            await MainActor.run {
                recordingState = .idle
            }
            transcription.text = "Transcription Failed: Invalid audio file URL"
            transcription.transcriptionStatus = TranscriptionStatus.failed.rawValue
            try? modelContext.save()
            return
        }

        if shouldCancelRecording {
            await MainActor.run {
                recordingState = .idle
            }
            await cleanupModelResources()
            return
        }

        await MainActor.run {
            recordingState = .transcribing
        }

        // Play stop sound when transcription starts with a small delay
        Task {
            let isSystemMuteEnabled = UserDefaults.hoah.bool(forKey: "isSystemMuteEnabled")
            if isSystemMuteEnabled {
                try? await Task.sleep(nanoseconds: 200_000_000) // 200 milliseconds delay
            }
            await MainActor.run {
                SoundManager.shared.playStopSound()
            }
        }

        defer {
            if shouldCancelRecording {
                Task {
                    await cleanupModelResources()
                }
            }
        }

        logger.notice("🔄 Starting transcription...")
        
        var finalPastedText: String?

        do {
            guard let model = recordingSessionModel ?? currentTranscriptionModel else {
                throw WhisperStateError.transcriptionFailed
            }

            let transcriptionStart = Date()
            let result = try await transcribeWithOfflineFallback(audioURL: url, preferredModel: model)
            let transcriptionDuration = Date().timeIntervalSince(transcriptionStart)
            let text = result.text
            let effectiveModel = result.model
            recordingSessionModel = effectiveModel
            logger.notice("📝 Raw transcript: \(text, privacy: .public)")
            finalPastedText = try await processTranscriptionResult(
                rawText: text,
                audioURL: url,
                transcription: transcription,
                model: effectiveModel,
                transcriptionDuration: transcriptionDuration
            )

        } catch {
            let errorDescription = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            let recoverySuggestion = (error as? LocalizedError)?.recoverySuggestion ?? ""
            let fullErrorText = recoverySuggestion.isEmpty ? errorDescription : "\(errorDescription) \(recoverySuggestion)"

            transcription.text = "Transcription Failed: \(fullErrorText)"
            transcription.transcriptionStatus = TranscriptionStatus.failed.rawValue
        }

        // Drop noisy/empty transcriptions: if both original and enhanced are empty after processing.
        let trimmedOriginal = transcription.text.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedEnhanced = transcription.enhancedText?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if trimmedOriginal.isEmpty && trimmedEnhanced.isEmpty {
            modelContext.delete(transcription)
            try? modelContext.save()
            await self.dismissMiniRecorder()
            shouldCancelRecording = false
            return
        }

        // --- Finalize and save ---
        try? modelContext.save()
        
        // Auto export to daily log if enabled
        AutoExportService.shared.appendTranscriptionIfEnabled(
            text: transcription.text,
            enhancedText: transcription.enhancedText,
            timestamp: transcription.timestamp
        )
        
        if transcription.transcriptionStatus == TranscriptionStatus.completed.rawValue {
            NotificationCenter.default.post(name: .transcriptionCompleted, object: transcription)
        }

        if await checkCancellationAndCleanup() { return }

        if let textToPaste = finalPastedText, transcription.transcriptionStatus == TranscriptionStatus.completed.rawValue {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                CursorPaster.pasteAtCursor(textToPaste + " ")
            }
        }

        await self.dismissMiniRecorder()

        shouldCancelRecording = false
    }

    private func processTranscriptionResult(
        rawText: String,
        audioURL: URL,
        transcription: Transcription,
        model: any TranscriptionModel,
        transcriptionDuration: TimeInterval
    ) async throws -> String {
        var text = TranscriptionOutputFilter.filter(rawText)
        logger.notice("📝 Output filter result: \(text, privacy: .public)")

        if await checkCancellationAndCleanup() {
            throw WhisperStateError.transcriptionFailed
        }

        text = text.trimmingCharacters(in: .whitespacesAndNewlines)

        if UserDefaults.hoah.object(forKey: "IsTextFormattingEnabled") as? Bool ?? true {
            text = WhisperTextFormatter.format(text)
            logger.notice("📝 Formatted transcript: \(text, privacy: .public)")
        }

        let audioAsset = AVURLAsset(url: audioURL)
        let actualDuration = (try? CMTimeGetSeconds(await audioAsset.load(.duration))) ?? 0.0

        transcription.text = text
        transcription.duration = actualDuration
        transcription.transcriptionModelName = model.displayName
        transcription.transcriptionDuration = transcriptionDuration

        var finalPastedText = text

        if let enhancementService = enhancementService,
           enhancementService.isEnhancementEnabled,
           enhancementService.isConfigured {
            if await checkCancellationAndCleanup() {
                throw WhisperStateError.transcriptionFailed
            }

            await MainActor.run { self.recordingState = .enhancing }
            let textForAI = text

            do {
                let (enhancedText, enhancementDuration, promptName) = try await enhancementService.enhance(textForAI)
                logger.notice("📝 AI enhancement: \(enhancedText, privacy: .public)")
                transcription.enhancedText = enhancedText
                transcription.aiEnhancementModelName = enhancementService.getAIService()?.currentModel
                transcription.promptName = promptName
                transcription.enhancementDuration = enhancementDuration
                transcription.aiRequestSystemMessage = enhancementService.lastSystemMessageSent
                transcription.aiRequestUserMessage = enhancementService.lastUserMessageSent
                finalPastedText = enhancedText
            } catch {
                let errorDescription = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
                transcription.enhancedText = String(
                    format: NSLocalizedString("AI Action failed: %@", comment: "AI Action failure message"),
                    errorDescription
                )

                if await checkCancellationAndCleanup() {
                    throw WhisperStateError.transcriptionFailed
                }
            }
        }

        transcription.transcriptionStatus = TranscriptionStatus.completed.rawValue
        return finalPastedText
    }

    private func supportsRealtimeStreaming(for model: any TranscriptionModel) -> Bool {
        model.usesRealtimeStreaming
    }

    private func transcriptionService(for model: any TranscriptionModel) -> any TranscriptionService {
        switch model.provider {
        case .local:
            return localTranscriptionService
        case .nativeApple:
            return nativeAppleTranscriptionService
        default:
            return cloudTranscriptionService
        }
    }

    private func transcribeWithOfflineFallback(
        audioURL: URL,
        preferredModel: any TranscriptionModel
    ) async throws -> (text: String, model: any TranscriptionModel) {
        do {
            let text = try await transcriptionService(for: preferredModel).transcribe(audioURL: audioURL, model: preferredModel)
            return (text, preferredModel)
        } catch {
            guard let fallbackModel = offlineFallbackLocalModel(for: preferredModel, error: error) else {
                throw error
            }

            logger.warning(
                "Cloud transcription failed with connectivity issue. Falling back to local model \(fallbackModel.name, privacy: .public)"
            )
            await showOfflineFallbackNotification(from: preferredModel, to: fallbackModel)
            let fallbackText = try await localTranscriptionService.transcribe(audioURL: audioURL, model: fallbackModel)
            return (fallbackText, fallbackModel)
        }
    }

    private func showOfflineFallbackNotification(from primaryModel: any TranscriptionModel, to fallbackModel: any TranscriptionModel) async {
        logger.notice(
            "Using offline fallback. primary=\(primaryModel.name, privacy: .public) fallback=\(fallbackModel.name, privacy: .public)"
        )
        await NotificationManager.shared.showNotification(
            title: "Network unavailable. Using local model: \(fallbackModel.displayName)",
            type: .warning
        )
    }

    private func processOfflineFallbackResult(
        fallbackModel: LocalModel,
        originalModel: any TranscriptionModel,
        audioURL: URL,
        transcription: Transcription,
        transcriptionDuration: TimeInterval
    ) async throws -> String {
        logger.warning(
            "Using local fallback model \(fallbackModel.name, privacy: .public) after connectivity failure on \(originalModel.name, privacy: .public)"
        )
        recordingSessionModel = fallbackModel
        await showOfflineFallbackNotification(from: originalModel, to: fallbackModel)
        let fallbackText = try await localTranscriptionService.transcribe(audioURL: audioURL, model: fallbackModel)
        return try await processTranscriptionResult(
            rawText: fallbackText,
            audioURL: audioURL,
            transcription: transcription,
            model: fallbackModel,
            transcriptionDuration: transcriptionDuration
        )
    }

    private func startRealtimeRecording(with model: any TranscriptionModel, toOutputFile url: URL) async throws {
        await cleanupRealtimeStreamingSession()

        let service: any StreamingTranscriptionService
        let sampleRate: Int
        let commitStrategy: StreamingSessionConfig.CommitStrategy

        switch model.provider {
        case .elevenLabs:
            service = ElevenLabsRealtimeTranscriptionService()
            sampleRate = 16_000
            commitStrategy = .manual
        case .openAI:
            service = OpenAIRealtimeTranscriptionService()
            sampleRate = 24_000
            commitStrategy = .vad
        case .amazonTranscribe:
            service = AmazonTranscribeRealtimeTranscriptionService()
            sampleRate = 16_000
            commitStrategy = .manual
        default:
            throw WhisperStateError.transcriptionFailed
        }

        realtimeStreamingService = service
        realtimeTranscriptBuffer.reset()
        liveCommittedTranscript = ""
        livePartialTranscript = ""
        liveStreamingError = nil
        lastRealtimeStreamingFailure = nil
        realtimeSessionStartedAt = Date()
        lastRealtimeEventAt = Date()
        isRealtimeRecordingSession = true

        let languageCode = normalizedRealtimeLanguageCode()
        let config = StreamingSessionConfig(
            modelName: model.name,
            languageCode: languageCode,
            sampleRate: sampleRate,
            includeTimestamps: false,
            commitStrategy: commitStrategy
        )

        logger.notice(
            "Starting realtime recording. provider=\(model.provider.rawValue, privacy: .public) model=\(model.name, privacy: .public) sampleRate=\(sampleRate) language=\(languageCode ?? "auto", privacy: .public) commitStrategy=\(commitStrategy.rawValue, privacy: .public)"
        )

        realtimeEventsTask = Task { [weak self] in
            guard let self else { return }
            for await event in service.events {
                await self.handleRealtimeTranscriptEvent(event)
            }
        }

        try await service.startSession(config: config)

        var audioChunkContinuation: AsyncStream<Data>.Continuation?
        let audioChunkStream = AsyncStream<Data> { continuation in
            audioChunkContinuation = continuation
        }

        guard let audioChunkContinuation else {
            throw WhisperStateError.transcriptionFailed
        }

        realtimeAudioChunkContinuation = audioChunkContinuation
        realtimeAudioSendTask = Task { [weak self] in
            guard let self else { return }

            for await chunk in audioChunkStream {
                do {
                    try await service.appendAudio(chunk)
                } catch {
                    await self.handleRealtimeStreamingFailure(error)
                    break
                }
            }
        }

        do {
            try await recorder.startStreaming(toOutputFile: url, sampleRate: Double(sampleRate)) { [continuation = audioChunkContinuation] chunk in
                continuation.yield(chunk)
            }
        } catch {
            realtimeAudioChunkContinuation?.finish()
            realtimeAudioChunkContinuation = nil
            realtimeAudioSendTask?.cancel()
            realtimeAudioSendTask = nil
            throw error
        }
    }

    private func finalizeRealtimeTranscription(on transcription: Transcription, recordedFile: URL) async {
        defer {
            recordingSessionModel = nil
            lastRealtimeStreamingFailure = nil
        }

        guard let model = recordingSessionModel ?? currentTranscriptionModel else {
            transcription.text = "Transcription Failed: No model selected"
            transcription.transcriptionStatus = TranscriptionStatus.failed.rawValue
            try? modelContext.save()
            return
        }

        logger.notice(
            "Finalizing realtime transcription. provider=\(model.provider.rawValue, privacy: .public) model=\(model.name, privacy: .public)"
        )

        await MainActor.run {
            recordingState = .finishing
        }

        Task {
            let isSystemMuteEnabled = UserDefaults.hoah.bool(forKey: "isSystemMuteEnabled")
            if isSystemMuteEnabled {
                try? await Task.sleep(nanoseconds: 200_000_000)
            }
            await MainActor.run {
                SoundManager.shared.playStopSound()
            }
        }

        var finalPastedText: String?

        do {
            await finishRealtimeAudioChunkStream()

            if let service = realtimeStreamingService {
                switch model.provider {
                case .amazonTranscribe:
                    try await service.finish()
                    try? await Task.sleep(nanoseconds: 750_000_000)
                    await waitForRealtimeTranscriptDrain(timeout: 4.5, quietWindow: 1.0)
                case .openAI:
                    try await service.finish()
                    try? await Task.sleep(nanoseconds: 500_000_000)
                    await waitForRealtimeTranscriptDrain(timeout: 4.0, quietWindow: 0.9)
                default:
                    try await service.finish()
                    try? await Task.sleep(nanoseconds: 250_000_000)
                    await waitForRealtimeTranscriptDrain()
                }
            }

            let transcriptionDuration = Date().timeIntervalSince(realtimeSessionStartedAt ?? Date())
            await MainActor.run {
                recordingState = .transcribing
            }
            if let streamingFailure = lastRealtimeStreamingFailure,
               let fallbackModel = offlineFallbackLocalModel(for: model, error: streamingFailure) {
                finalPastedText = try await processOfflineFallbackResult(
                    fallbackModel: fallbackModel,
                    originalModel: model,
                    audioURL: recordedFile,
                    transcription: transcription,
                    transcriptionDuration: transcriptionDuration
                )
            } else {
                let rawText = realtimeTranscriptBuffer.mergedText
                logger.notice("Realtime transcription merged text length=\(rawText.count)")
                finalPastedText = try await processTranscriptionResult(
                    rawText: rawText,
                    audioURL: recordedFile,
                    transcription: transcription,
                    model: model,
                    transcriptionDuration: transcriptionDuration
                )
            }
        } catch {
            if let fallbackModel = offlineFallbackLocalModel(for: model, error: error) {
                do {
                    let transcriptionDuration = Date().timeIntervalSince(realtimeSessionStartedAt ?? Date())
                    finalPastedText = try await processOfflineFallbackResult(
                        fallbackModel: fallbackModel,
                        originalModel: model,
                        audioURL: recordedFile,
                        transcription: transcription,
                        transcriptionDuration: transcriptionDuration
                    )
                } catch {
                    let errorDescription = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
                    logger.error("Realtime transcription finalization failed after fallback: \(errorDescription, privacy: .public)")
                    transcription.text = "Transcription Failed: \(errorDescription)"
                    transcription.transcriptionStatus = TranscriptionStatus.failed.rawValue
                }
            } else {
                let errorDescription = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
                logger.error("Realtime transcription finalization failed: \(errorDescription, privacy: .public)")
                transcription.text = "Transcription Failed: \(errorDescription)"
                transcription.transcriptionStatus = TranscriptionStatus.failed.rawValue
            }
        }

        try? modelContext.save()

        AutoExportService.shared.appendTranscriptionIfEnabled(
            text: transcription.text,
            enhancedText: transcription.enhancedText,
            timestamp: transcription.timestamp
        )

        if transcription.transcriptionStatus == TranscriptionStatus.completed.rawValue {
            NotificationCenter.default.post(name: .transcriptionCompleted, object: transcription)
        }

        if let textToPaste = finalPastedText, transcription.transcriptionStatus == TranscriptionStatus.completed.rawValue {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                CursorPaster.pasteAtCursor(textToPaste + " ")
            }
        }

        await cleanupRealtimeStreamingSession()
        await self.dismissMiniRecorder()
        shouldCancelRecording = false
    }
    
    func startRecordingTimeoutIfNeeded() {
        recordingTimeoutTask?.cancel()
        
        let defaultMinutes = AppSettingsState().maxRecordingDurationMinutes
        let limitMinutes = appSettings?.maxRecordingDurationMinutes ?? defaultMinutes
        guard limitMinutes > 0 else { return }
        
        let durationSeconds = Double(limitMinutes) * 60
        recordingTimeoutTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(durationSeconds * 1_000_000_000))
            guard let self = self else { return }
            if Task.isCancelled { return }
            await self.handleRecordingTimeout(maxDurationSeconds: durationSeconds)
        }
    }
    
    func cancelRecordingTimeout() {
        recordingTimeoutTask?.cancel()
        recordingTimeoutTask = nil
    }
    
    @MainActor
    func handleRecordingTimeout(maxDurationSeconds: TimeInterval) async {
        guard recordingState == .recording else { return }
        logger.warning("Recording reached max duration (\(maxDurationSeconds) seconds), stopping automatically")
        
        NotificationManager.shared.showNotification(
            title: String(format: NSLocalizedString("Recording stopped after %d minutes (max limit reached).", comment: ""), Int(maxDurationSeconds / 60)),
            type: .warning
        )
        
        await toggleRecord()
    }

    func getEnhancementService() -> AIEnhancementService? {
        return enhancementService
    }
    
    private func checkCancellationAndCleanup() async -> Bool {
        if shouldCancelRecording {
            await cleanupRealtimeStreamingSession()
            await cleanupModelResources()
            return true
        }
        return false
    }

    private func cleanupAndDismiss() async {
        await dismissMiniRecorder()
    }

    private func handleRealtimeTranscriptEvent(_ event: StreamingTranscriptEvent) async {
        lastRealtimeEventAt = Date()
        realtimeTranscriptBuffer.apply(event: event)
        liveCommittedTranscript = realtimeTranscriptBuffer.committedText
        livePartialTranscript = realtimeTranscriptBuffer.partialText

        switch event {
        case .sessionStarted:
            logger.notice("Realtime session started event received.")
        case .partial(let text):
            logger.debug("Realtime partial event received. characters=\(text.count)")
        case .final(let text):
            logger.notice("Realtime final event received. characters=\(text.count)")
        case .finalWithMetadata(let text, let words, let languageCode):
            logger.notice(
                "Realtime final-with-metadata event received. characters=\(text.count) words=\(words.count) language=\(languageCode ?? "unknown", privacy: .public)"
            )
        case .providerState(let value):
            logger.debug("Realtime provider state: \(value, privacy: .public)")
        case .error(let message):
            liveStreamingError = message
            if let model = recordingSessionModel ?? currentTranscriptionModel,
               offlineFallbackLocalModel(for: model, errorMessage: message) != nil {
                lastRealtimeStreamingFailure = NSError(
                    domain: NSURLErrorDomain,
                    code: URLError.networkConnectionLost.rawValue,
                    userInfo: [
                        NSLocalizedDescriptionKey: message
                    ]
                )
            }
            logger.error("Realtime event error: \(message, privacy: .public)")
        case .sessionEnded:
            logger.notice("Realtime session ended event received.")
        default:
            break
        }
    }

    private func handleRealtimeStreamingFailure(_ error: Error) async {
        liveStreamingError = error.localizedDescription
        lastRealtimeStreamingFailure = error
        logger.error(
            "Realtime streaming error: \(error.localizedDescription, privacy: .public). provider=\(self.currentTranscriptionModel?.provider.rawValue ?? "unknown", privacy: .public) model=\(self.currentTranscriptionModel?.name ?? "none", privacy: .public)"
        )
    }

    private func waitForRealtimeTranscriptDrain(timeout: TimeInterval = 2.0, quietWindow: TimeInterval = 0.35) async {
        let startedAt = Date()

        while Date().timeIntervalSince(startedAt) < timeout {
            let quietFor = Date().timeIntervalSince(lastRealtimeEventAt ?? startedAt)
            if quietFor >= quietWindow {
                break
            }

            try? await Task.sleep(nanoseconds: 100_000_000)
        }
    }

    private func finishRealtimeAudioChunkStream() async {
        realtimeAudioChunkContinuation?.finish()
        realtimeAudioChunkContinuation = nil

        let sendTask = realtimeAudioSendTask
        realtimeAudioSendTask = nil
        _ = await sendTask?.result
    }

    private func cleanupRealtimeStreamingSession() async {
        logger.debug(
            "Cleaning up realtime session. committedChars=\(self.liveCommittedTranscript.count) partialChars=\(self.livePartialTranscript.count)"
        )
        realtimeAudioChunkContinuation?.finish()
        realtimeAudioChunkContinuation = nil
        realtimeAudioSendTask?.cancel()
        realtimeAudioSendTask = nil
        realtimeEventsTask?.cancel()
        realtimeEventsTask = nil
        if let service = realtimeStreamingService {
            await service.cancel()
        }
        realtimeStreamingService = nil
        realtimeSessionStartedAt = nil
        lastRealtimeEventAt = nil
        isRealtimeRecordingSession = false
        liveStreamingError = nil
        lastRealtimeStreamingFailure = nil
    }

    private func normalizedRealtimeLanguageCode() -> String? {
        let selectedLanguage = UserDefaults.hoah.string(forKey: "SelectedLanguage") ?? "auto"
        guard selectedLanguage != "auto", !selectedLanguage.isEmpty else {
            return nil
        }

        if let separatorIndex = selectedLanguage.firstIndex(of: "-") {
            return String(selectedLanguage[..<separatorIndex]).lowercased()
        }

        return selectedLanguage.lowercased()
    }

    var isStreamingSessionActive: Bool {
        isRealtimeRecordingSession
    }

    var liveTranscriptPreview: String {
        let committed = liveCommittedTranscript.trimmingCharacters(in: .whitespacesAndNewlines)
        let partial = livePartialTranscript.trimmingCharacters(in: .whitespacesAndNewlines)

        switch (committed.isEmpty, partial.isEmpty) {
        case (true, true):
            return ""
        case (false, true):
            return committed
        case (true, false):
            return partial
        case (false, false):
            return "\(committed) \(partial)"
        }
    }

    func shutdownForTermination() async {
        guard !isShuttingDown else { return }
        isShuttingDown = true

        logger.notice("Shutting down WhisperState before app termination")
        NotificationCenter.default.removeObserver(self)
        NSWorkspace.shared.notificationCenter.removeObserver(self)
        WhisperModelWarmupCoordinator.shared.cancelAllWarmups()

        cancelRecordingTimeout()
        await recorder.stopRecording()
        hideRecorderPanel()
        await cleanupRealtimeStreamingSession()
        await cleanupModelResources()

        isMiniRecorderVisible = false
        shouldCancelRecording = false
        liveCommittedTranscript = ""
        livePartialTranscript = ""
        miniRecorderError = nil
        recordingState = .idle
    }
}
