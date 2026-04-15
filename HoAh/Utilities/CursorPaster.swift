import Foundation
import AppKit

class CursorPaster {
    private static let pasteTriggerDelay: UInt64 = 50_000_000
    private static let pasteCompletionDelay: UInt64 = 150_000_000
    static let autoSendPasteCompletionDelay: UInt64 = 500_000_000

    private typealias SavedPasteboardContents = [(NSPasteboard.PasteboardType, Data)]

    static func pasteAtCursor(
        _ text: String,
        preserveClipboardOverride: Bool? = nil,
        appendTrailingSpaceOverride: Bool? = nil
    ) {
        let savedContents = preparePasteboard(
            text,
            preserveClipboardOverride: preserveClipboardOverride,
            appendTrailingSpaceOverride: appendTrailingSpaceOverride
        )
        scheduleClipboardRestoreIfNeeded(savedContents)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            pasteUsingCommandV()
        }
    }

    @MainActor
    static func pasteAtCursorAndWait(
        _ text: String,
        preserveClipboardOverride: Bool? = nil,
        appendTrailingSpaceOverride: Bool? = nil,
        completionDelayOverride: UInt64? = nil
    ) async {
        let savedContents = preparePasteboard(
            text,
            preserveClipboardOverride: preserveClipboardOverride,
            appendTrailingSpaceOverride: appendTrailingSpaceOverride
        )
        scheduleClipboardRestoreIfNeeded(savedContents)

        try? await Task.sleep(nanoseconds: pasteTriggerDelay)
        pasteUsingCommandV()
        try? await Task.sleep(nanoseconds: completionDelayOverride ?? pasteCompletionDelay)
    }

    private static func pasteUsingCommandV() {
        guard AXIsProcessTrusted() else {
            return
        }
        
        let source = CGEventSource(stateID: .hidSystemState)
        
        let cmdDown = CGEvent(keyboardEventSource: source, virtualKey: 0x37, keyDown: true)
        let vDown = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: true)
        let vUp = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: false)
        let cmdUp = CGEvent(keyboardEventSource: source, virtualKey: 0x37, keyDown: false)
        
        cmdDown?.flags = .maskCommand
        vDown?.flags = .maskCommand
        vUp?.flags = .maskCommand
        
        cmdDown?.post(tap: .cghidEventTap)
        vDown?.post(tap: .cghidEventTap)
        vUp?.post(tap: .cghidEventTap)
        cmdUp?.post(tap: .cghidEventTap)
    }

    // Simulate pressing the Return / Enter key
    static func pressEnter() {
        guard AXIsProcessTrusted() else { return }
        let source = CGEventSource(stateID: .hidSystemState)
        let enterDown = CGEvent(keyboardEventSource: source, virtualKey: 0x24, keyDown: true)
        let enterUp = CGEvent(keyboardEventSource: source, virtualKey: 0x24, keyDown: false)
        enterDown?.post(tap: .cghidEventTap)
        enterUp?.post(tap: .cghidEventTap)
    }

    private static func preparePasteboard(
        _ text: String,
        preserveClipboardOverride: Bool?,
        appendTrailingSpaceOverride: Bool?
    ) -> SavedPasteboardContents {
        let pasteboard = NSPasteboard.general
        // Read from the legacy key (synced by AppSettingsStore).
        // This class is intentionally static because it is called from low-level paste flows,
        // so we bridge through UserDefaults until that call chain can take injected state.
        // Default to true if not set, to prevent data loss on paste failure
        let preserveTranscript = preserveClipboardOverride
            ?? (UserDefaults.hoah.object(forKey: "preserveTranscriptInClipboard") as? Bool ?? true)

        var savedContents: SavedPasteboardContents = []

        if !preserveTranscript {
            let currentItems = pasteboard.pasteboardItems ?? []

            for item in currentItems {
                for type in item.types {
                    if let data = item.data(forType: type) {
                        savedContents.append((type, data))
                    }
                }
            }
        }

        let shouldAppendTrailingSpace = appendTrailingSpaceOverride ?? AppSettingsSnapshot.current().appendTrailingSpace
        let finalText: String
        if shouldAppendTrailingSpace,
           !text.isEmpty,
           text.last?.isWhitespace != true {
            finalText = text + " "
        } else {
            finalText = text
        }

        let _ = ClipboardManager.setClipboard(finalText, transient: !preserveTranscript)
        return savedContents
    }

    private static func scheduleClipboardRestoreIfNeeded(_ savedContents: SavedPasteboardContents) {
        guard !savedContents.isEmpty else { return }

        let pasteboard = NSPasteboard.general
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) {
            pasteboard.clearContents()
            for (type, data) in savedContents {
                pasteboard.setData(data, forType: type)
            }
        }
    }
}
