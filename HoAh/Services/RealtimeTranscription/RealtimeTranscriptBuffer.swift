import Foundation

@MainActor
final class RealtimeTranscriptBuffer {
    private(set) var committedText = ""
    private(set) var partialText = ""

    var mergedText: String {
        let committed = committedText.trimmingCharacters(in: .whitespacesAndNewlines)
        let partial = partialText.trimmingCharacters(in: .whitespacesAndNewlines)

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

    func reset() {
        committedText = ""
        partialText = ""
    }

    func apply(event: StreamingTranscriptEvent) {
        switch event {
        case .partial(let text):
            partialText = text
        case .final(let text):
            committedText = appendCommitted(text, to: committedText)
            partialText = ""
        case .finalWithMetadata(let text, _, _):
            committedText = appendCommitted(text, to: committedText)
            partialText = ""
        default:
            break
        }
    }

    private func appendCommitted(_ text: String, to base: String) -> String {
        let trimmedBase = base.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedText.isEmpty else { return trimmedBase }
        guard !trimmedBase.isEmpty else { return trimmedText }

        if trimmedBase.hasSuffix(trimmedText) {
            return trimmedBase
        }

        return "\(trimmedBase) \(trimmedText)"
    }
}

