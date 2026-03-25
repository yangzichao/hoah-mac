import Foundation
import os

enum OpenAIRealtimeError: LocalizedError {
    case missingAPIKey
    case invalidURL
    case notConnected
    case transportError(String)

    var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            return "OpenAI API key is missing."
        case .invalidURL:
            return "Failed to construct the OpenAI realtime URL."
        case .notConnected:
            return "The OpenAI realtime session is not connected."
        case .transportError(let message):
            return message
        }
    }
}

actor OpenAIRealtimeTranscriptionService: StreamingTranscriptionService {
    nonisolated let events: AsyncStream<StreamingTranscriptEvent>
    private static let realtimeConnectionModel = "gpt-realtime"

    private let session: URLSession
    private let logger = Logger(subsystem: "com.yangzichao.hoah", category: "OpenAIRealtimeTranscription")
    private var eventsContinuation: AsyncStream<StreamingTranscriptEvent>.Continuation?
    private var webSocketTask: URLSessionWebSocketTask?
    private var receiveTask: Task<Void, Never>?
    private var currentConfig: StreamingSessionConfig?
    private var activePartialItemID: String?
    private var activePartialText = ""
    private var sentChunkCount = 0
    private var receivedEventCount = 0
    private var audioSinceLastCompletedMs = 0.0
    private var lastAudioAppendAt: Date?
    private var lastCompletedAt: Date?
    private var didEmitSessionStarted = false
    private var sessionIsActive = false

    init(session: URLSession = .shared) {
        self.session = session

        var continuation: AsyncStream<StreamingTranscriptEvent>.Continuation?
        self.events = AsyncStream { streamContinuation in
            continuation = streamContinuation
        }
        self.eventsContinuation = continuation
    }

    func startSession(config: StreamingSessionConfig) async throws {
        await cancel()

        guard let apiKey = CloudAPIKeyManager.shared.activeKey(for: "OpenAI")?.value,
              !apiKey.isEmpty else {
            throw OpenAIRealtimeError.missingAPIKey
        }

        var components = URLComponents(string: "wss://api.openai.com/v1/realtime")
        components?.queryItems = [
            URLQueryItem(name: "model", value: Self.realtimeConnectionModel)
        ]

        guard let url = components?.url else {
            throw OpenAIRealtimeError.invalidURL
        }

        var request = URLRequest(url: url)
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("realtime=v1", forHTTPHeaderField: "OpenAI-Beta")

        let task = session.webSocketTask(with: request)
        webSocketTask = task
        currentConfig = config
        activePartialItemID = nil
        activePartialText = ""
        sentChunkCount = 0
        receivedEventCount = 0
        audioSinceLastCompletedMs = 0
        lastAudioAppendAt = nil
        lastCompletedAt = nil
        didEmitSessionStarted = false
        sessionIsActive = true

        logger.notice(
            "Starting OpenAI realtime session. websocketModel=\(Self.realtimeConnectionModel, privacy: .public) transcriptionModel=\(config.modelName, privacy: .public) sampleRate=\(config.sampleRate) language=\(config.languageCode ?? "auto", privacy: .public) commitStrategy=\(config.commitStrategy.rawValue, privacy: .public)"
        )
        task.resume()

        eventsContinuation?.yield(.providerState("connecting"))

        receiveTask = Task { [weak self] in
            await self?.receiveLoop()
        }

        let payload = buildSessionUpdatePayload(config: config)
        logger.debug("Sending OpenAI session.update payload.")
        try await send(payload, on: task)
    }

    func appendAudio(_ chunk: Data) async throws {
        guard let webSocketTask else {
            throw OpenAIRealtimeError.notConnected
        }

        sentChunkCount += 1
        audioSinceLastCompletedMs += (Double(chunk.count) / 2.0 / Double(currentConfig?.sampleRate ?? 24_000)) * 1000.0
        lastAudioAppendAt = Date()
        if sentChunkCount <= 5 || sentChunkCount.isMultiple(of: 20) {
            logger.debug(
                "Sending OpenAI audio chunk #\(self.sentChunkCount). bytes=\(chunk.count) taskState=\(webSocketTask.state.rawValue)"
            )
        }

        let payload: [String: Any] = [
            "type": "input_audio_buffer.append",
            "audio": chunk.base64EncodedString()
        ]

        try await send(payload, on: webSocketTask)
    }

    func commitCurrentUtterance() async throws {
        guard let webSocketTask else {
            throw OpenAIRealtimeError.notConnected
        }

        logger.notice(
            "Sending OpenAI input_audio_buffer.commit. chunksSent=\(self.sentChunkCount) taskState=\(webSocketTask.state.rawValue)"
        )

        let payload: [String: Any] = [
            "type": "input_audio_buffer.commit"
        ]

        try await send(payload, on: webSocketTask)
    }

    func finish() async throws {
        logger.notice("Finishing OpenAI realtime session.")

        if currentConfig?.commitStrategy == .vad {
            if shouldForceCommitTrailingAudio() {
                logger.notice(
                    "Forcing OpenAI trailing commit in VAD mode. audioSinceLastCompletedMs=\(String(format: "%.1f", self.audioSinceLastCompletedMs), privacy: .public)"
                )
                try await commitCurrentUtterance()
            } else {
                logger.debug("Skipping manual commit for VAD-based OpenAI session.")
            }
            return
        }

        try await commitCurrentUtterance()
    }

    func cancel() async {
        let hadActiveSession = sessionIsActive || webSocketTask != nil || receiveTask != nil || currentConfig != nil

        if let webSocketTask {
            logger.notice(
                "Cancelling OpenAI realtime session. closeCode=\(webSocketTask.closeCode.rawValue) reason=\(String(data: webSocketTask.closeReason ?? Data(), encoding: .utf8) ?? "none", privacy: .public) chunksSent=\(self.sentChunkCount) eventsReceived=\(self.receivedEventCount)"
            )
        }
        receiveTask?.cancel()
        receiveTask = nil

        webSocketTask?.cancel(with: .goingAway, reason: nil)
        webSocketTask = nil
        currentConfig = nil
        activePartialItemID = nil
        activePartialText = ""
        audioSinceLastCompletedMs = 0
        lastAudioAppendAt = nil
        lastCompletedAt = nil
        if hadActiveSession {
            emitSessionEndedIfNeeded()
            eventsContinuation?.finish()
        }
    }

    private func buildSessionUpdatePayload(config: StreamingSessionConfig) -> [String: Any] {
        var transcription: [String: Any] = [
            "model": config.modelName
        ]

        if let languageCode = config.languageCode, !languageCode.isEmpty {
            transcription["language"] = languageCode
        }

        var sessionPayload: [String: Any] = [
            "input_audio_format": "pcm16",
            "input_audio_transcription": transcription
        ]

        if config.commitStrategy == .vad {
            sessionPayload["turn_detection"] = [
                "type": "server_vad"
            ]
        }

        return [
            "type": "session.update",
            "session": sessionPayload
        ]
    }

    private func receiveLoop() async {
        guard let webSocketTask else { return }

        logger.debug("OpenAI receive loop started.")

        while !Task.isCancelled {
            do {
                let message = try await receive(on: webSocketTask)
                switch message {
                case .string(let text):
                    handleTextMessage(text)
                case .data(let data):
                    if let text = String(data: data, encoding: .utf8) {
                        handleTextMessage(text)
                    }
                @unknown default:
                    break
                }
            } catch {
                if Task.isCancelled {
                    break
                }

                logger.error(
                    "OpenAI receive loop failed. error=\(error.localizedDescription, privacy: .public) closeCode=\(webSocketTask.closeCode.rawValue) reason=\(String(data: webSocketTask.closeReason ?? Data(), encoding: .utf8) ?? "none", privacy: .public)"
                )
                eventsContinuation?.yield(.error(error.localizedDescription))
                break
            }
        }

        logger.debug("OpenAI receive loop ended.")
        emitSessionEndedIfNeeded()
        eventsContinuation?.finish()
    }

    private func handleTextMessage(_ text: String) {
        guard let data = text.data(using: .utf8),
              let payload = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let eventType = payload["type"] as? String else {
            logger.debug("OpenAI non-JSON providerState payload: \(text, privacy: .public)")
            eventsContinuation?.yield(.providerState(text))
            return
        }

        receivedEventCount += 1
        if receivedEventCount <= 10 || receivedEventCount.isMultiple(of: 25) {
            logger.debug("OpenAI event #\(self.receivedEventCount): \(eventType, privacy: .public)")
        }

        switch eventType {
        case "session.created":
            logger.notice("OpenAI realtime session acknowledged with event=\(eventType, privacy: .public)")
            if !didEmitSessionStarted {
                didEmitSessionStarted = true
                eventsContinuation?.yield(.sessionStarted)
            }
        case "session.updated":
            logger.notice("OpenAI realtime session acknowledged with event=\(eventType, privacy: .public)")
            eventsContinuation?.yield(.providerState(eventType))
        case "conversation.item.input_audio_transcription.delta":
            guard let delta = payload["delta"] as? String else { return }
            let itemID = payload["item_id"] as? String
            applyPartial(delta: delta, itemID: itemID)
        case "conversation.item.input_audio_transcription.completed":
            applyCompletedEvent(payload)
        case "error":
            let message = extractErrorMessage(from: payload)
            if shouldIgnoreProviderError(message) {
                logger.notice("Ignoring benign OpenAI realtime error event: \(message, privacy: .public)")
                eventsContinuation?.yield(.providerState("ignored_error:\(message)"))
            } else {
                logger.error("OpenAI realtime error event: \(message, privacy: .public)")
                eventsContinuation?.yield(.error(message))
            }
        default:
            eventsContinuation?.yield(.providerState(eventType))
        }
    }

    private func applyPartial(delta: String, itemID: String?) {
        if let itemID {
            if activePartialItemID != itemID {
                logger.debug("OpenAI partial stream switched to item_id=\(itemID, privacy: .public)")
                activePartialItemID = itemID
                activePartialText = ""
            }
        }

        activePartialText += delta
        if activePartialText.count <= 48 || activePartialText.count.isMultiple(of: 64) {
            logger.debug("OpenAI partial transcript length=\(self.activePartialText.count)")
        }
        eventsContinuation?.yield(.partial(text: activePartialText))
    }

    private func applyCompletedEvent(_ payload: [String: Any]) {
        let itemID = payload["item_id"] as? String
        let transcript = (
            payload["transcript"] as? String ??
            payload["text"] as? String ??
            activePartialText
        ).trimmingCharacters(in: .whitespacesAndNewlines)

        if let itemID, activePartialItemID == itemID {
            activePartialItemID = nil
        }
        activePartialText = ""
        audioSinceLastCompletedMs = 0
        lastCompletedAt = Date()

        guard !transcript.isEmpty else { return }
        logger.notice(
            "OpenAI completed transcript received. itemID=\(itemID ?? "none", privacy: .public) characters=\(transcript.count)"
        )
        eventsContinuation?.yield(.final(text: transcript))
    }

    private func extractErrorMessage(from payload: [String: Any]) -> String {
        if let errorObject = payload["error"] as? [String: Any],
           let message = errorObject["message"] as? String,
           !message.isEmpty {
            return message
        }

        if let message = payload["message"] as? String, !message.isEmpty {
            return message
        }

        return "OpenAI realtime session failed."
    }

    private func send(_ payload: [String: Any], on task: URLSessionWebSocketTask) async throws {
        let data = try JSONSerialization.data(withJSONObject: payload)
        guard let text = String(data: data, encoding: .utf8) else {
            throw OpenAIRealtimeError.transportError("Failed to encode OpenAI realtime request.")
        }

        let payloadType = (payload["type"] as? String) ?? "unknown"

        do {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                task.send(.string(text)) { error in
                    if let error {
                        continuation.resume(throwing: error)
                    } else {
                        continuation.resume()
                    }
                }
            }
        } catch {
            logger.error(
                "OpenAI send failed. type=\(payloadType, privacy: .public) taskState=\(task.state.rawValue) closeCode=\(task.closeCode.rawValue) reason=\(String(data: task.closeReason ?? Data(), encoding: .utf8) ?? "none", privacy: .public) error=\(error.localizedDescription, privacy: .public)"
            )
            throw error
        }
    }

    private func receive(on task: URLSessionWebSocketTask) async throws -> URLSessionWebSocketTask.Message {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<URLSessionWebSocketTask.Message, Error>) in
            task.receive { result in
                continuation.resume(with: result)
            }
        }
    }

    private func shouldForceCommitTrailingAudio() -> Bool {
        guard audioSinceLastCompletedMs >= 100 else { return false }

        let lastAppend = lastAudioAppendAt ?? .distantPast
        let lastCompleted = lastCompletedAt ?? .distantPast
        return lastAppend > lastCompleted
    }

    private func shouldIgnoreProviderError(_ message: String) -> Bool {
        guard currentConfig?.commitStrategy == .vad else { return false }

        let normalized = message.lowercased()
        return normalized.contains("buffer too small")
    }

    private func emitSessionEndedIfNeeded() {
        guard sessionIsActive else { return }
        sessionIsActive = false
        eventsContinuation?.yield(.sessionEnded)
    }
}
