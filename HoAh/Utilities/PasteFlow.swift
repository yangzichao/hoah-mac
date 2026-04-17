import Foundation
import AppKit
import os

/// State machine for the paste / auto-send pipeline.
///
/// Stages: prepare → ack → paste → consume → [enter] → restore
///
/// Invariants:
/// - `ClipboardIO.prepare` is the only code path that reads the
///   `appendTrailingSpace` setting and writes the pasteboard. Callers must
///   never pre-concatenate whitespace.
/// - `KeyEventIO` posts CGEvent sequences atomically: if any event in a
///   sequence fails to construct, the whole sequence is aborted so the
///   target app cannot be left holding a phantom modifier.
/// - The returned `Task` represents the paste + optional Enter. Cancelling
///   it aborts before the Enter is synthesised. Clipboard restoration is
///   scheduled via a detached timer so cancel does not strand the user's
///   original clipboard contents.
@MainActor
enum PasteFlow {
    struct Config {
        let text: String
        let autoSend: Bool
        let preserveClipboard: Bool?
        let appendTrailingSpace: Bool?

        init(
            text: String,
            autoSend: Bool = false,
            preserveClipboard: Bool? = nil,
            appendTrailingSpace: Bool? = nil
        ) {
            self.text = text
            self.autoSend = autoSend
            self.preserveClipboard = preserveClipboard
            self.appendTrailingSpace = appendTrailingSpace
        }
    }

    // Single source of truth for the pipeline's timing.
    private static let ackDelayNanos: UInt64         = 50_000_000
    private static let consumeDelayNanos: UInt64     = 150_000_000
    private static let autoSendConsumeNanos: UInt64  = 500_000_000
    private static let restoreSafetyMarginNanos: UInt64 = 500_000_000
    private static let minRestoreDelayNanos: UInt64  = 900_000_000

    private static let logger = Logger(subsystem: "com.yangzichao.hoah", category: "PasteFlow")

    @discardableResult
    static func run(_ config: Config) -> Task<Void, Never> {
        Task { @MainActor in
            await execute(config)
        }
    }

    private static func execute(_ config: Config) async {
        let saved = ClipboardIO.prepare(
            text: config.text,
            preserveClipboard: config.preserveClipboard,
            appendTrailingSpace: config.appendTrailingSpace
        )

        let consumeNanos = config.autoSend ? autoSendConsumeNanos : consumeDelayNanos
        let restoreAfter = max(
            ackDelayNanos + consumeNanos + restoreSafetyMarginNanos,
            minRestoreDelayNanos
        )

        // Deferred so restore still happens if the task is cancelled mid-flow.
        // ClipboardIO.scheduleRestore runs on a detached timer immune to cancel.
        defer { ClipboardIO.scheduleRestore(saved, afterNanos: restoreAfter) }

        do { try await Task.sleep(nanoseconds: ackDelayNanos) } catch { return }

        guard KeyEventIO.pasteCmdVAtomic() else { return }

        do { try await Task.sleep(nanoseconds: consumeNanos) } catch { return }

        if config.autoSend {
            KeyEventIO.pressReturnAtomic()
        }
    }
}

// MARK: - Clipboard IO

@MainActor
enum ClipboardIO {
    typealias SavedContents = [(NSPasteboard.PasteboardType, Data)]

    static func prepare(
        text: String,
        preserveClipboard: Bool?,
        appendTrailingSpace: Bool?
    ) -> SavedContents {
        let pasteboard = NSPasteboard.general
        let preserve = preserveClipboard
            ?? (UserDefaults.hoah.object(forKey: "preserveTranscriptInClipboard") as? Bool ?? true)

        var saved: SavedContents = []
        if !preserve {
            let items = pasteboard.pasteboardItems ?? []
            for item in items {
                for type in item.types {
                    if let data = item.data(forType: type) {
                        saved.append((type, data))
                    }
                }
            }
        }

        let appendSpace = appendTrailingSpace ?? AppSettingsSnapshot.current().appendTrailingSpace
        let finalText: String
        if appendSpace, !text.isEmpty, text.last?.isWhitespace != true {
            finalText = text + " "
        } else {
            finalText = text
        }

        _ = ClipboardManager.setClipboard(finalText, transient: !preserve)
        return saved
    }

    static func scheduleRestore(_ saved: SavedContents, afterNanos delayNanos: UInt64) {
        guard !saved.isEmpty else { return }

        let seconds = Double(delayNanos) / 1_000_000_000.0
        let pasteboard = NSPasteboard.general
        DispatchQueue.main.asyncAfter(deadline: .now() + seconds) {
            pasteboard.clearContents()
            for (type, data) in saved {
                pasteboard.setData(data, forType: type)
            }
        }
    }
}

// MARK: - Key Event IO

enum KeyEventIO {
    private static let cmdKey: CGKeyCode = 0x37
    private static let vKey: CGKeyCode = 0x09
    private static let returnKey: CGKeyCode = 0x24

    private static let logger = Logger(subsystem: "com.yangzichao.hoah", category: "KeyEventIO")

    /// Posts Cmd+V atomically. Returns false (without posting) if any event
    /// in the sequence could not be constructed, so the target app never
    /// sees a lone Cmd-down.
    @discardableResult
    static func pasteCmdVAtomic() -> Bool {
        guard AXIsProcessTrusted() else {
            logger.warning("pasteCmdVAtomic: accessibility not trusted")
            return false
        }

        let source = CGEventSource(stateID: .hidSystemState)
        guard
            let cmdDown = CGEvent(keyboardEventSource: source, virtualKey: cmdKey, keyDown: true),
            let vDown   = CGEvent(keyboardEventSource: source, virtualKey: vKey,   keyDown: true),
            let vUp     = CGEvent(keyboardEventSource: source, virtualKey: vKey,   keyDown: false),
            let cmdUp   = CGEvent(keyboardEventSource: source, virtualKey: cmdKey, keyDown: false)
        else {
            logger.error("pasteCmdVAtomic: CGEvent construction failed; aborting to avoid stuck Cmd")
            return false
        }

        cmdDown.flags = .maskCommand
        vDown.flags = .maskCommand
        vUp.flags = .maskCommand

        cmdDown.post(tap: .cghidEventTap)
        vDown.post(tap: .cghidEventTap)
        vUp.post(tap: .cghidEventTap)
        cmdUp.post(tap: .cghidEventTap)
        return true
    }

    @discardableResult
    static func pressReturnAtomic() -> Bool {
        guard AXIsProcessTrusted() else {
            logger.warning("pressReturnAtomic: accessibility not trusted")
            return false
        }

        let source = CGEventSource(stateID: .hidSystemState)
        guard
            let down = CGEvent(keyboardEventSource: source, virtualKey: returnKey, keyDown: true),
            let up   = CGEvent(keyboardEventSource: source, virtualKey: returnKey, keyDown: false)
        else {
            logger.error("pressReturnAtomic: CGEvent construction failed")
            return false
        }

        down.post(tap: .cghidEventTap)
        up.post(tap: .cghidEventTap)
        return true
    }
}
