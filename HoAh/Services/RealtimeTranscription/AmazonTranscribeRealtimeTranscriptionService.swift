import Foundation
import os

enum AmazonTranscribeRealtimeError: LocalizedError {
    case missingConfiguration
    case invalidURL
    case notConnected
    case transportError(String)

    var errorDescription: String? {
        switch self {
        case .missingConfiguration:
            return "Amazon Transcribe is not configured."
        case .invalidURL:
            return "Failed to construct the Amazon Transcribe streaming URL."
        case .notConnected:
            return "The Amazon Transcribe realtime session is not connected."
        case .transportError(let message):
            return message
        }
    }
}

actor AmazonTranscribeRealtimeTranscriptionService: StreamingTranscriptionService {
    nonisolated let events: AsyncStream<StreamingTranscriptEvent>

    private let session: URLSession
    private let logger = Logger(subsystem: "com.yangzichao.hoah", category: "AmazonTranscribeRealtime")
    private let configurationStore = AmazonTranscribeConfigurationStore.shared
    private var eventsContinuation: AsyncStream<StreamingTranscriptEvent>.Continuation?
    private var webSocketTask: URLSessionWebSocketTask?
    private var receiveTask: Task<Void, Never>?
    private var receiveBuffer = Data()
    private var currentConfig: StreamingSessionConfig?
    private var didSendEndFrame = false
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

        guard configurationStore.isConfigured() else {
            throw AmazonTranscribeRealtimeError.missingConfiguration
        }

        let resolved = try await configurationStore.resolveCredentials()
        let signedURL = try makeSignedWebSocketURL(config: config, credentials: resolved.credentials, region: resolved.region)

        let task = session.webSocketTask(with: signedURL)
        webSocketTask = task
        currentConfig = config
        receiveBuffer = Data()
        didSendEndFrame = false
        sessionIsActive = true

        logger.notice(
            "Starting Amazon Transcribe realtime session. region=\(resolved.region, privacy: .public) sampleRate=\(config.sampleRate) language=\(config.languageCode ?? "auto", privacy: .public)"
        )

        task.resume()
        eventsContinuation?.yield(.providerState("connecting"))
        eventsContinuation?.yield(.sessionStarted)

        receiveTask = Task { [weak self] in
            await self?.receiveLoop()
        }
    }

    func appendAudio(_ chunk: Data) async throws {
        guard let webSocketTask else {
            throw AmazonTranscribeRealtimeError.notConnected
        }
        guard !didSendEndFrame else {
            return
        }

        let frame = AmazonEventStreamCodec.encodeMessage(
            headers: [
                ":content-type": "application/octet-stream",
                ":event-type": "AudioEvent",
                ":message-type": "event"
            ],
            payload: chunk
        )

        try await send(.data(frame), on: webSocketTask)
    }

    func commitCurrentUtterance() async throws {
        try await sendEndFrameIfNeeded()
    }

    func finish() async throws {
        logger.notice("Finishing Amazon Transcribe realtime session.")
        try await sendEndFrameIfNeeded()
    }

    func cancel() async {
        let hadActiveSession = sessionIsActive || webSocketTask != nil || receiveTask != nil || currentConfig != nil

        receiveTask?.cancel()
        receiveTask = nil

        webSocketTask?.cancel(with: .goingAway, reason: nil)
        webSocketTask = nil
        currentConfig = nil
        receiveBuffer = Data()
        didSendEndFrame = false
        if hadActiveSession {
            emitSessionEndedIfNeeded()
            eventsContinuation?.finish()
        }
    }

    private func sendEndFrameIfNeeded() async throws {
        guard let webSocketTask else {
            throw AmazonTranscribeRealtimeError.notConnected
        }
        guard !didSendEndFrame else { return }

        didSendEndFrame = true

        let frame = AmazonEventStreamCodec.encodeMessage(
            headers: [
                ":content-type": "application/octet-stream",
                ":event-type": "AudioEvent",
                ":message-type": "event"
            ],
            payload: Data()
        )

        try await send(.data(frame), on: webSocketTask)
    }

    private func makeSignedWebSocketURL(
        config: StreamingSessionConfig,
        credentials: AWSCredentials,
        region: String
    ) throws -> URL {
        var components = URLComponents()
        components.scheme = "wss"
        components.host = "transcribestreaming.\(region).amazonaws.com"
        components.port = 8443
        components.path = "/stream-transcription-websocket"

        let queryItems = buildQueryItems(config: config)
        guard let baseURL = components.url else {
            throw AmazonTranscribeRealtimeError.invalidURL
        }

        return try AWSSigV4Signer.presignURL(
            baseURL: baseURL,
            credentials: credentials,
            region: region,
            service: "transcribe",
            expiresIn: 300,
            additionalQueryItems: queryItems
        )
    }

    private func buildQueryItems(config: StreamingSessionConfig) -> [URLQueryItem] {
        var queryItems: [URLQueryItem] = [
            URLQueryItem(name: "media-encoding", value: "pcm"),
            URLQueryItem(name: "sample-rate", value: String(config.sampleRate)),
            URLQueryItem(name: "enable-partial-results-stabilization", value: "true"),
            URLQueryItem(name: "partial-results-stability", value: "high"),
            URLQueryItem(name: "session-id", value: UUID().uuidString.lowercased())
        ]

        if let awsLanguageCode = Self.amazonLanguageCode(from: config.languageCode) {
            queryItems.append(URLQueryItem(name: "language-code", value: awsLanguageCode))
        } else {
            let languageOptions = configurationStore.effectivePreferredLanguageCodes()

            if languageOptions.count <= 1, let onlyLanguage = languageOptions.first {
                queryItems.append(URLQueryItem(name: "language-code", value: onlyLanguage))
            } else {
                queryItems.append(URLQueryItem(name: "identify-language", value: "true"))
                queryItems.append(URLQueryItem(name: "language-options", value: languageOptions.joined(separator: ",")))
                if let preferred = languageOptions.first {
                    queryItems.append(URLQueryItem(name: "preferred-language", value: preferred))
                }
            }
        }

        return queryItems
    }

    private func receiveLoop() async {
        guard let webSocketTask else { return }

        while !Task.isCancelled {
            do {
                let message = try await receive(on: webSocketTask)
                switch message {
                case .data(let data):
                    try handleBinaryMessage(data)
                case .string(let text):
                    logger.debug("Amazon Transcribe provider state: \(text, privacy: .public)")
                    eventsContinuation?.yield(.providerState(text))
                @unknown default:
                    break
                }
            } catch {
                if Task.isCancelled {
                    break
                }

                if shouldIgnoreReceiveLoopError(error, task: webSocketTask) {
                    logger.notice("Ignoring expected Amazon Transcribe receive loop closure: \(error.localizedDescription, privacy: .public)")
                } else {
                    logger.error("Amazon Transcribe receive loop failed: \(error.localizedDescription, privacy: .public)")
                    eventsContinuation?.yield(.error(error.localizedDescription))
                }
                break
            }
        }

        emitSessionEndedIfNeeded()
        eventsContinuation?.finish()
    }

    private func handleBinaryMessage(_ data: Data) throws {
        receiveBuffer.append(data)
        let messages = try AmazonEventStreamCodec.decodeMessages(from: &receiveBuffer)

        for message in messages {
            try handleEventStreamMessage(message)
        }
    }

    private func handleEventStreamMessage(_ message: AmazonEventStreamMessage) throws {
        let messageType = message.headers[":message-type"] ?? ""

        if messageType == "exception" {
            let exceptionType = message.headers[":exception-type"] ?? "AmazonTranscribeException"
            let errorMessage = String(data: message.payload, encoding: .utf8) ?? exceptionType
            logger.error("Amazon Transcribe exception: \(exceptionType, privacy: .public) \(errorMessage, privacy: .public)")
            eventsContinuation?.yield(.error("\(exceptionType): \(errorMessage)"))
            return
        }

        guard messageType == "event",
              let eventType = message.headers[":event-type"],
              eventType == "TranscriptEvent" else {
            return
        }

        let transcriptEvent = try JSONDecoder().decode(AmazonTranscriptEnvelope.self, from: message.payload)
        for result in transcriptEvent.transcript.results {
            guard let transcript = result.alternatives.first?.transcript?
                .trimmingCharacters(in: .whitespacesAndNewlines),
                  !transcript.isEmpty else {
                continue
            }

            if result.isPartial {
                eventsContinuation?.yield(.partial(text: transcript))
            } else {
                eventsContinuation?.yield(.final(text: transcript))
            }
        }
    }

    private func send(_ message: URLSessionWebSocketTask.Message, on task: URLSessionWebSocketTask) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            task.send(message) { error in
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

    private static func amazonLanguageCode(from languageCode: String?) -> String? {
        guard let languageCode = languageCode?.lowercased(), !languageCode.isEmpty else {
            return nil
        }

        let mapping: [String: String] = [
            "en": "en-US",
            "zh": "zh-CN",
            "ja": "ja-JP",
            "ko": "ko-KR",
            "fr": "fr-FR",
            "de": "de-DE",
            "es": "es-US",
            "it": "it-IT",
            "pt": "pt-BR",
            "hi": "hi-IN",
            "ar": "ar-SA",
            "nl": "nl-NL",
            "pl": "pl-PL",
            "sv": "sv-SE",
            "fi": "fi-FI",
            "no": "no-NO",
            "da": "da-DK",
            "ru": "ru-RU",
            "tr": "tr-TR",
            "uk": "uk-UA",
            "vi": "vi-VN",
            "id": "id-ID"
        ]

        return mapping[languageCode]
    }

    private func emitSessionEndedIfNeeded() {
        guard sessionIsActive else { return }
        sessionIsActive = false
        eventsContinuation?.yield(.sessionEnded)
    }

    private func shouldIgnoreReceiveLoopError(_ error: Error, task: URLSessionWebSocketTask) -> Bool {
        let normalized = error.localizedDescription.lowercased()

        if didSendEndFrame && normalized.contains("socket is not connected") {
            return true
        }

        return didSendEndFrame && task.closeCode != .invalid
    }
}

private struct AmazonTranscriptEnvelope: Decodable {
    let transcript: AmazonTranscript

    enum CodingKeys: String, CodingKey {
        case transcript = "Transcript"
    }
}

private struct AmazonTranscript: Decodable {
    let results: [AmazonTranscriptResult]

    enum CodingKeys: String, CodingKey {
        case results = "Results"
    }
}

private struct AmazonTranscriptResult: Decodable {
    let alternatives: [AmazonTranscriptAlternative]
    let isPartial: Bool

    enum CodingKeys: String, CodingKey {
        case alternatives = "Alternatives"
        case isPartial = "IsPartial"
    }
}

private struct AmazonTranscriptAlternative: Decodable {
    let transcript: String?

    enum CodingKeys: String, CodingKey {
        case transcript = "Transcript"
    }
}
