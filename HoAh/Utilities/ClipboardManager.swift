import SwiftUI
import AppKit

struct ClipboardManager {
    enum ClipboardError: Error {
        case copyFailed
        case accessDenied
    }

    private static let commandKeyCode: CGKeyCode = 0x37
    private static let cKeyCode: CGKeyCode = 0x08

    static func setClipboard(_ text: String, transient: Bool = false) -> Bool {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)

        if let bundleIdentifier = Bundle.main.bundleIdentifier {
            pasteboard.setString(bundleIdentifier, forType: NSPasteboard.PasteboardType("org.nspasteboard.source"))
        }

        if transient {
            pasteboard.setData(Data(), forType: NSPasteboard.PasteboardType("org.nspasteboard.TransientType"))
        }

        return true
    }

    static func copyToClipboard(_ text: String) -> Bool {
        return setClipboard(text, transient: false)
    }

    static func getClipboardContent() -> String? {
        return NSPasteboard.general.string(forType: .string)
    }

    static func copySelectedTextToClipboard() async -> Bool {
        guard AXIsProcessTrusted() else {
            return false
        }

        let pasteboard = NSPasteboard.general
        let initialChangeCount = pasteboard.changeCount

        try? await Task.sleep(nanoseconds: 60_000_000)
        postCommandCopy()

        for _ in 0..<8 {
            try? await Task.sleep(nanoseconds: 50_000_000)
            if pasteboard.changeCount != initialChangeCount {
                return true
            }
        }

        return false
    }

    private static func postCommandCopy() {
        let source = CGEventSource(stateID: .hidSystemState)

        let commandDown = CGEvent(keyboardEventSource: source, virtualKey: commandKeyCode, keyDown: true)
        let cDown = CGEvent(keyboardEventSource: source, virtualKey: cKeyCode, keyDown: true)
        let cUp = CGEvent(keyboardEventSource: source, virtualKey: cKeyCode, keyDown: false)
        let commandUp = CGEvent(keyboardEventSource: source, virtualKey: commandKeyCode, keyDown: false)

        commandDown?.flags = .maskCommand
        cDown?.flags = .maskCommand
        cUp?.flags = .maskCommand

        commandDown?.post(tap: .cghidEventTap)
        cDown?.post(tap: .cghidEventTap)
        cUp?.post(tap: .cghidEventTap)
        commandUp?.post(tap: .cghidEventTap)
    }
}

struct ClipboardMessageModifier: ViewModifier {
    @Binding var message: String
    @Environment(\.theme) private var theme
    
    func body(content: Content) -> some View {
        content
            .overlay(
                Group {
                    if !message.isEmpty {
                        Text(message)
                            .font(.caption)
                            .foregroundColor(theme.statusSuccess)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(theme.statusSuccess.opacity(0.1))
                            .cornerRadius(4)
                            .transition(.opacity)
                            .animation(.easeInOut, value: message)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                .padding()
            )
    }
}

extension View {
    func clipboardMessage(_ message: Binding<String>) -> some View {
        self.modifier(ClipboardMessageModifier(message: message))
    }
}
