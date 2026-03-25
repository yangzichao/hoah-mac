import Foundation

struct StreamingWord: Decodable, Sendable {
    let text: String
    let start: Double?
    let end: Double?
    let type: String?
    let logprob: Double?
}

struct StreamingSessionConfig: Sendable {
    enum CommitStrategy: String, Sendable {
        case manual
        case vad
    }

    let modelName: String
    let languageCode: String?
    let sampleRate: Int
    let includeTimestamps: Bool
    let commitStrategy: CommitStrategy
}

enum StreamingTranscriptEvent: Sendable {
    case sessionStarted
    case partial(text: String)
    case final(text: String)
    case finalWithMetadata(text: String, words: [StreamingWord], languageCode: String?)
    case providerState(String)
    case error(String)
    case sessionEnded
}

protocol StreamingTranscriptionService: Sendable {
    var events: AsyncStream<StreamingTranscriptEvent> { get }

    func startSession(config: StreamingSessionConfig) async throws
    func appendAudio(_ chunk: Data) async throws
    func commitCurrentUtterance() async throws
    func finish() async throws
    func cancel() async
}

