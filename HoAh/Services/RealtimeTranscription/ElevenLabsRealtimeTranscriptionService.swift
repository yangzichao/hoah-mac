import Foundation

enum ElevenLabsRealtimeError: LocalizedError {
    case missingAPIKey
    case invalidURL
    case notConnected
    case transportError(String)

    var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            return "ElevenLabs API key is missing."
        case .invalidURL:
            return "Failed to construct the ElevenLabs realtime URL."
        case .notConnected:
            return "The ElevenLabs realtime session is not connected."
        case .transportError(let message):
            return message
        }
    }
}

actor ElevenLabsRealtimeTranscriptionService: StreamingTranscriptionService {
    nonisolated let events: AsyncStream<StreamingTranscriptEvent>

    private let session: URLSession
    private var eventsContinuation: AsyncStream<StreamingTranscriptEvent>.Continuation?
    private var webSocketTask: URLSessionWebSocketTask?
    private var receiveTask: Task<Void, Never>?
    private var currentConfig: StreamingSessionConfig?
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

        guard let apiKey = CloudAPIKeyManager.shared.activeKey(for: "ElevenLabs")?.value,
              !apiKey.isEmpty else {
            throw ElevenLabsRealtimeError.missingAPIKey
        }

        let realtimeModelName = Self.realtimeModelName(for: config.modelName)

        var components = URLComponents(string: "wss://api.elevenlabs.io/v1/speech-to-text/realtime")
        components?.queryItems = buildQueryItems(config: config, realtimeModelName: realtimeModelName)

        guard let url = components?.url else {
            throw ElevenLabsRealtimeError.invalidURL
        }

        var request = URLRequest(url: url)
        request.setValue(apiKey, forHTTPHeaderField: "xi-api-key")

        let task = session.webSocketTask(with: request)
        webSocketTask = task
        currentConfig = config
        sessionIsActive = true
        task.resume()

        eventsContinuation?.yield(.providerState("connecting"))

        receiveTask = Task { [weak self] in
            await self?.receiveLoop()
        }
    }

    func appendAudio(_ chunk: Data) async throws {
        guard let webSocketTask else {
            throw ElevenLabsRealtimeError.notConnected
        }
        guard let currentConfig else {
            throw ElevenLabsRealtimeError.notConnected
        }

        let payload = InputAudioChunkPayload(
            message_type: "input_audio_chunk",
            audio_base_64: chunk.base64EncodedString(),
            commit: nil,
            sample_rate: currentConfig.sampleRate,
            previous_text: nil
        )

        try await send(payload, on: webSocketTask)
    }

    func commitCurrentUtterance() async throws {
        guard let webSocketTask else {
            throw ElevenLabsRealtimeError.notConnected
        }
        guard let currentConfig else {
            throw ElevenLabsRealtimeError.notConnected
        }

        let payload = InputAudioChunkPayload(
            message_type: "input_audio_chunk",
            audio_base_64: "",
            commit: true,
            sample_rate: currentConfig.sampleRate,
            previous_text: nil
        )

        try await send(payload, on: webSocketTask)
    }

    func finish() async throws {
        try await commitCurrentUtterance()
    }

    func cancel() async {
        let hadActiveSession = sessionIsActive || webSocketTask != nil || receiveTask != nil || currentConfig != nil

        receiveTask?.cancel()
        receiveTask = nil

        webSocketTask?.cancel(with: .goingAway, reason: nil)
        webSocketTask = nil
        currentConfig = nil
        if hadActiveSession {
            emitSessionEndedIfNeeded()
            eventsContinuation?.finish()
        }
    }

    private func buildQueryItems(config: StreamingSessionConfig, realtimeModelName: String) -> [URLQueryItem] {
        var queryItems: [URLQueryItem] = [
            URLQueryItem(name: "model_id", value: realtimeModelName),
            URLQueryItem(name: "audio_format", value: "pcm_16000"),
            URLQueryItem(name: "include_timestamps", value: config.includeTimestamps ? "true" : "false"),
            URLQueryItem(name: "commit_strategy", value: config.commitStrategy.rawValue)
        ]

        if let languageCode = config.languageCode, !languageCode.isEmpty {
            queryItems.append(URLQueryItem(name: "language_code", value: languageCode))
        }

        return queryItems
    }

    private func receiveLoop() async {
        guard let webSocketTask else { return }

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

                eventsContinuation?.yield(.error(error.localizedDescription))
                break
            }
        }

        emitSessionEndedIfNeeded()
        eventsContinuation?.finish()
    }

    private func handleTextMessage(_ text: String) {
        guard let data = text.data(using: .utf8) else {
            eventsContinuation?.yield(.error("Received non-UTF8 ElevenLabs realtime payload."))
            return
        }

        guard let envelope = try? JSONDecoder().decode(MessageEnvelope.self, from: data) else {
            eventsContinuation?.yield(.providerState(text))
            return
        }

        switch envelope.message_type {
        case "session_started":
            eventsContinuation?.yield(.sessionStarted)
        case "partial_transcript":
            if let payload = try? JSONDecoder().decode(PartialTranscriptPayload.self, from: data) {
                eventsContinuation?.yield(.partial(text: payload.text))
            }
        case "committed_transcript":
            if let payload = try? JSONDecoder().decode(CommittedTranscriptPayload.self, from: data) {
                eventsContinuation?.yield(.final(text: payload.text))
            }
        case "committed_transcript_with_timestamps":
            if let payload = try? JSONDecoder().decode(CommittedTranscriptWithTimestampsPayload.self, from: data) {
                eventsContinuation?.yield(
                    .finalWithMetadata(
                        text: payload.text,
                        words: payload.words,
                        languageCode: payload.language_code
                    )
                )
            }
        default:
            if let errorPayload = try? JSONDecoder().decode(ErrorPayload.self, from: data),
               let message = errorPayload.message ?? errorPayload.error {
                eventsContinuation?.yield(.error(message))
            } else {
                eventsContinuation?.yield(.providerState(text))
            }
        }
    }

    private func send<T: Encodable>(_ payload: T, on task: URLSessionWebSocketTask) async throws {
        let data = try JSONEncoder().encode(payload)
        guard let text = String(data: data, encoding: .utf8) else {
            throw ElevenLabsRealtimeError.transportError("Failed to encode ElevenLabs realtime request.")
        }

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            task.send(.string(text)) { error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume()
                }
            }
        }
    }

    private func receive(on task: URLSessionWebSocketTask) async throws -> URLSessionWebSocketTask.Message {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<URLSessionWebSocketTask.Message, Error>) in
            task.receive { result in
                continuation.resume(with: result)
            }
        }
    }

    private static func realtimeModelName(for modelName: String) -> String {
        switch modelName {
        case "scribe_v2":
            return "scribe_v2_realtime"
        default:
            return modelName
        }
    }

    private func emitSessionEndedIfNeeded() {
        guard sessionIsActive else { return }
        sessionIsActive = false
        eventsContinuation?.yield(.sessionEnded)
    }
}

private extension ElevenLabsRealtimeTranscriptionService {
    struct InputAudioChunkPayload: Encodable {
        let message_type: String
        let audio_base_64: String
        let commit: Bool?
        let sample_rate: Int
        let previous_text: String?
    }

    struct MessageEnvelope: Decodable {
        let message_type: String
    }

    struct PartialTranscriptPayload: Decodable {
        let message_type: String
        let text: String
    }

    struct CommittedTranscriptPayload: Decodable {
        let message_type: String
        let text: String
    }

    struct CommittedTranscriptWithTimestampsPayload: Decodable {
        let message_type: String
        let text: String
        let language_code: String?
        let words: [StreamingWord]
    }

    struct ErrorPayload: Decodable {
        let message_type: String
        let message: String?
        let error: String?
    }
}
