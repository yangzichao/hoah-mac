import Foundation
import KeyboardShortcuts
import AppKit
import Combine
import SwiftData

extension KeyboardShortcuts.Name {
    fileprivate static let clipboardDefaultModifiers: NSEvent.ModifierFlags = [.option, .shift]

    static let clipboardPrompt1 = Self("clipboardPrompt1")
    static let clipboardPrompt2 = Self("clipboardPrompt2")
    static let clipboardPrompt3 = Self("clipboardPrompt3")
    static let clipboardPrompt4 = Self("clipboardPrompt4")
    static let clipboardPrompt5 = Self("clipboardPrompt5")
    static let clipboardPrompt6 = Self("clipboardPrompt6")
    static let clipboardPrompt7 = Self("clipboardPrompt7")
    static let clipboardPrompt8 = Self("clipboardPrompt8")
    static let clipboardPrompt9 = Self("clipboardPrompt9")
    static let clipboardPrompt10 = Self("clipboardPrompt10")

    static let clipboardPrompt1Config = Self("clipboardPrompt1Config", default: .init(.one, modifiers: clipboardDefaultModifiers))
    static let clipboardPrompt2Config = Self("clipboardPrompt2Config", default: .init(.two, modifiers: clipboardDefaultModifiers))
    static let clipboardPrompt3Config = Self("clipboardPrompt3Config", default: .init(.three, modifiers: clipboardDefaultModifiers))
    static let clipboardPrompt4Config = Self("clipboardPrompt4Config", default: .init(.four, modifiers: clipboardDefaultModifiers))
    static let clipboardPrompt5Config = Self("clipboardPrompt5Config", default: .init(.five, modifiers: clipboardDefaultModifiers))
    static let clipboardPrompt6Config = Self("clipboardPrompt6Config", default: .init(.six, modifiers: clipboardDefaultModifiers))
    static let clipboardPrompt7Config = Self("clipboardPrompt7Config", default: .init(.seven, modifiers: clipboardDefaultModifiers))
    static let clipboardPrompt8Config = Self("clipboardPrompt8Config", default: .init(.eight, modifiers: clipboardDefaultModifiers))
    static let clipboardPrompt9Config = Self("clipboardPrompt9Config", default: .init(.nine, modifiers: clipboardDefaultModifiers))
    static let clipboardPrompt10Config = Self("clipboardPrompt10Config", default: .init(.zero, modifiers: clipboardDefaultModifiers))

    static let clipboardPrompt1Active = Self("clipboardPrompt1Active")
    static let clipboardPrompt2Active = Self("clipboardPrompt2Active")
    static let clipboardPrompt3Active = Self("clipboardPrompt3Active")
    static let clipboardPrompt4Active = Self("clipboardPrompt4Active")
    static let clipboardPrompt5Active = Self("clipboardPrompt5Active")
    static let clipboardPrompt6Active = Self("clipboardPrompt6Active")
    static let clipboardPrompt7Active = Self("clipboardPrompt7Active")
    static let clipboardPrompt8Active = Self("clipboardPrompt8Active")
    static let clipboardPrompt9Active = Self("clipboardPrompt9Active")
    static let clipboardPrompt10Active = Self("clipboardPrompt10Active")
}

@MainActor
final class ClipboardAIActionShortcutManager {
    private let enhancementService: AIEnhancementService
    private let appSettings: AppSettingsStore
    private let modelContext: ModelContext
    private var cancellables = Set<AnyCancellable>()
    private var isProcessingShortcut = false

    static let configuredShortcutNames: [KeyboardShortcuts.Name] = [
        .clipboardPrompt1Config, .clipboardPrompt2Config, .clipboardPrompt3Config, .clipboardPrompt4Config, .clipboardPrompt5Config,
        .clipboardPrompt6Config, .clipboardPrompt7Config, .clipboardPrompt8Config, .clipboardPrompt9Config, .clipboardPrompt10Config
    ]

    static let activeShortcutNames: [KeyboardShortcuts.Name] = [
        .clipboardPrompt1Active, .clipboardPrompt2Active, .clipboardPrompt3Active, .clipboardPrompt4Active, .clipboardPrompt5Active,
        .clipboardPrompt6Active, .clipboardPrompt7Active, .clipboardPrompt8Active, .clipboardPrompt9Active, .clipboardPrompt10Active
    ]

    private static let allShortcutEditorSlots: [(index: Int, name: KeyboardShortcuts.Name)] = [
        (0, .clipboardPrompt1Config),
        (1, .clipboardPrompt2Config),
        (2, .clipboardPrompt3Config),
        (3, .clipboardPrompt4Config),
        (4, .clipboardPrompt5Config),
        (5, .clipboardPrompt6Config),
        (6, .clipboardPrompt7Config),
        (7, .clipboardPrompt8Config),
        (8, .clipboardPrompt9Config),
        (9, .clipboardPrompt10Config)
    ]

    private var availableShortcutCount: Int {
        Self.activeShortcutCount(for: enhancementService.promptShortcutPrompts.count)
    }

    init(enhancementService: AIEnhancementService, appSettings: AppSettingsStore, modelContext: ModelContext) {
        self.enhancementService = enhancementService
        self.appSettings = appSettings
        self.modelContext = modelContext

        migrateLegacyShortcutsIfNeeded()
        setupHandlers()
        setupObservers()
        updateShortcutRegistration()
    }

    private func setupObservers() {
        appSettings.$isClipboardEnhancementShortcutsEnabled
            .dropFirst()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.updateShortcutRegistration()
            }
            .store(in: &cancellables)

        appSettings.$clipboardEnhancementShortcutSlotEnabledStates
            .dropFirst()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.updateShortcutRegistration()
            }
            .store(in: &cancellables)

        enhancementService.$activePrompts
            .dropFirst()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.updateShortcutRegistration()
            }
            .store(in: &cancellables)

        appSettings.$isSecondTranslationEnabled
            .dropFirst()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.updateShortcutRegistration()
            }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: Notification.Name("KeyboardShortcuts_shortcutByNameDidChange"))
            .sink { [weak self] notification in
                guard let self,
                      let name = Self.shortcutName(from: notification),
                      Self.configuredShortcutNames.contains(name) else { return }
                self.updateShortcutRegistration()
            }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: NSApplication.didFinishLaunchingNotification)
            .merge(with: NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification))
            .sink { [weak self] _ in
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    self?.updateShortcutRegistration()
                }
            }
            .store(in: &cancellables)
    }

    private func setupHandlers() {
        for (index, name) in Self.activeShortcutNames.enumerated() {
            KeyboardShortcuts.removeHandler(for: name)
            KeyboardShortcuts.onKeyDown(for: name) { [weak self] in
                Task { @MainActor in
                    await self?.runClipboardAction(at: index)
                }
            }
        }
    }

    private func updateShortcutRegistration() {
        syncActiveShortcuts()
        if appSettings.isClipboardEnhancementShortcutsEnabled {
            setupHandlers()
        }
    }

    private func migrateLegacyShortcutsIfNeeded() {
        let legacyNames: [KeyboardShortcuts.Name] = [
            .clipboardPrompt1, .clipboardPrompt2, .clipboardPrompt3, .clipboardPrompt4, .clipboardPrompt5,
            .clipboardPrompt6, .clipboardPrompt7, .clipboardPrompt8, .clipboardPrompt9, .clipboardPrompt10
        ]

        for index in Self.configuredShortcutNames.indices {
            let configuredName = Self.configuredShortcutNames[index]
            let activeName = Self.activeShortcutNames[index]
            let legacyName = legacyNames[index]
            let configuredShortcut = KeyboardShortcuts.getShortcut(for: configuredName)
            let defaultShortcut = Self.defaultShortcut(for: index)

            if let activeShortcut = KeyboardShortcuts.getShortcut(for: activeName),
               configuredShortcut == nil || configuredShortcut == defaultShortcut {
                KeyboardShortcuts.setShortcut(activeShortcut, for: configuredName)
            } else if let legacyShortcut = KeyboardShortcuts.getShortcut(for: legacyName),
                      configuredShortcut == nil || configuredShortcut == defaultShortcut {
                KeyboardShortcuts.setShortcut(legacyShortcut, for: configuredName)
            }

            if KeyboardShortcuts.getShortcut(for: legacyName) != nil {
                KeyboardShortcuts.setShortcut(nil, for: legacyName)
            }
        }
    }

    private func syncActiveShortcuts() {
        for index in Self.configuredShortcutNames.indices {
            let configuredName = Self.configuredShortcutNames[index]
            let activeName = Self.activeShortcutNames[index]
            let isSlotAvailable = index < availableShortcutCount
            let isSlotEnabled = appSettings.isClipboardEnhancementShortcutSlotEnabled(at: index)
            let activeShortcut = appSettings.isClipboardEnhancementShortcutsEnabled && isSlotAvailable
                && isSlotEnabled
                ? resolvedShortcut(for: configuredName, index: index)
                : nil
            KeyboardShortcuts.setShortcut(activeShortcut, for: activeName)
        }
    }

    private func runClipboardAction(at index: Int) async {
        guard appSettings.isClipboardEnhancementShortcutsEnabled else { return }
        guard appSettings.isClipboardEnhancementShortcutSlotEnabled(at: index) else { return }

        if isProcessingShortcut {
            NotificationManager.shared.showNotification(
                title: NSLocalizedString("Another selection AI Action is still running", comment: "Shown when selection action shortcut is triggered while another one is still running"),
                type: .warning
            )
            return
        }

        guard await ClipboardManager.copySelectedTextToClipboard(),
              let clipboardText = ClipboardManager.getClipboardContent()?.trimmingCharacters(in: .whitespacesAndNewlines),
              !clipboardText.isEmpty else {
            NotificationManager.shared.showNotification(
                title: NSLocalizedString("No selected text found", comment: "Shown when clipboard action shortcut is triggered without any selected text to copy"),
                type: .warning
            )
            return
        }

        guard !appSettings.validAIConfigurations.isEmpty else {
            NotificationManager.shared.showNotification(
                title: NSLocalizedString("Please add a valid AI configuration first", comment: "Shown when clipboard action shortcut is triggered without a valid AI configuration"),
                type: .warning
            )
            return
        }

        let prompts = enhancementService.promptShortcutPrompts
        guard index < prompts.count else {
            NotificationManager.shared.showNotification(
                title: String(
                    format: NSLocalizedString("No AI Action assigned to shortcut %@", comment: "Shown when a clipboard action shortcut slot does not have a corresponding AI action"),
                    shortcutSlotLabel(for: index)
                ),
                type: .warning
            )
            return
        }

        let prompt = prompts[index]

        isProcessingShortcut = true
        NotificationManager.shared.showNotification(
            title: String(
                format: NSLocalizedString("Applying AI Action: %@", comment: "Shown when a clipboard AI action starts processing"),
                prompt.displayTitle
            ),
            type: .info,
            duration: nil
        )

        defer {
            isProcessingShortcut = false
        }

        do {
            let (result, enhancementDuration, promptName) = try await enhancementService.enhance(
                clipboardText,
                promptOverride: prompt
            )
            archiveClipboardAction(
                originalText: clipboardText,
                enhancedText: result,
                promptName: promptName,
                enhancementDuration: enhancementDuration,
                status: .completed
            )
            // Clipboard Action should be one-shot but keep the AI result in clipboard.
            // We still attempt to paste into the focused input field.
            await CursorPaster.pasteAtCursorAndWait(result, preserveClipboardOverride: true)
            NotificationManager.shared.dismissNotification()
        } catch {
            let message = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            archiveClipboardAction(
                originalText: clipboardText,
                enhancedText: String(format: NSLocalizedString("AI Action failed: %@", comment: "AI Action failure message"), message),
                promptName: prompt.displayTitle,
                enhancementDuration: nil,
                status: .failed
            )
            NotificationManager.shared.showNotification(
                title: String(format: NSLocalizedString("AI Action failed: %@", comment: "AI Action failure message"), message),
                type: .error
            )
        }
    }

    private func archiveClipboardAction(
        originalText: String,
        enhancedText: String?,
        promptName: String?,
        enhancementDuration: TimeInterval?,
        status: TranscriptionStatus
    ) {
        let transcription = Transcription(
            text: originalText,
            duration: 0,
            enhancedText: enhancedText,
            aiEnhancementModelName: enhancementService.getAIService()?.currentModel,
            promptName: promptName,
            enhancementDuration: enhancementDuration,
            aiRequestSystemMessage: enhancementService.lastSystemMessageSent,
            aiRequestUserMessage: enhancementService.lastUserMessageSent,
            transcriptionStatus: status,
            source: .clipboardAction
        )

        modelContext.insert(transcription)

        do {
            try modelContext.save()
            NotificationCenter.default.post(name: .transcriptionCreated, object: transcription)
        } catch {
            modelContext.delete(transcription)
        }
    }

    private func shortcutSlotLabel(for index: Int) -> String {
        guard (0..<Self.activeShortcutNames.count).contains(index) else { return "?" }
        return index == 9 ? "0" : String(index + 1)
    }

    private func resolvedShortcut(for configuredName: KeyboardShortcuts.Name, index: Int) -> KeyboardShortcuts.Shortcut? {
        KeyboardShortcuts.getShortcut(for: configuredName) ?? Self.defaultShortcut(for: index)
    }

    private static func shortcutName(from notification: Notification) -> KeyboardShortcuts.Name? {
        if let name = notification.userInfo?["name"] as? KeyboardShortcuts.Name {
            return name
        }

        if let rawName = notification.userInfo?["name"] as? String {
            return KeyboardShortcuts.Name(rawName)
        }

        return nil
    }

    static func defaultShortcut(for index: Int) -> KeyboardShortcuts.Shortcut? {
        switch index {
        case 0: return .init(.one, modifiers: KeyboardShortcuts.Name.clipboardDefaultModifiers)
        case 1: return .init(.two, modifiers: KeyboardShortcuts.Name.clipboardDefaultModifiers)
        case 2: return .init(.three, modifiers: KeyboardShortcuts.Name.clipboardDefaultModifiers)
        case 3: return .init(.four, modifiers: KeyboardShortcuts.Name.clipboardDefaultModifiers)
        case 4: return .init(.five, modifiers: KeyboardShortcuts.Name.clipboardDefaultModifiers)
        case 5: return .init(.six, modifiers: KeyboardShortcuts.Name.clipboardDefaultModifiers)
        case 6: return .init(.seven, modifiers: KeyboardShortcuts.Name.clipboardDefaultModifiers)
        case 7: return .init(.eight, modifiers: KeyboardShortcuts.Name.clipboardDefaultModifiers)
        case 8: return .init(.nine, modifiers: KeyboardShortcuts.Name.clipboardDefaultModifiers)
        case 9: return .init(.zero, modifiers: KeyboardShortcuts.Name.clipboardDefaultModifiers)
        default: return nil
        }
    }

    static func activeShortcutCount(for promptCount: Int) -> Int {
        min(max(promptCount, 0), configuredShortcutNames.count)
    }

    static func enabledShortcutIndices(for promptCount: Int, enabledStates: [Bool]) -> [Int] {
        let availableCount = activeShortcutCount(for: promptCount)
        let normalizedStates = AppSettingsState.normalizedClipboardEnhancementShortcutSlotEnabledStates(enabledStates)
        return Array(0..<availableCount).filter { normalizedStates[$0] }
    }

    static func shortcutEditorSlots(for promptCount: Int) -> [(index: Int, name: KeyboardShortcuts.Name)] {
        Array(allShortcutEditorSlots.prefix(activeShortcutCount(for: promptCount)))
    }

    static func shortcutRangeLabel(for slotCount: Int) -> String {
        let resolvedCount = activeShortcutCount(for: slotCount)

        switch resolvedCount {
        case ..<1:
            return "-"
        case 1:
            return "1"
        case 10:
            return "1–0"
        default:
            return "1–\(resolvedCount)"
        }
    }

    static func shortcutSummaryLabel(for indices: [Int]) -> String {
        let sortedIndices = indices.sorted()
        guard let firstIndex = sortedIndices.first else { return "-" }

        var components: [String] = []
        var rangeStart = firstIndex
        var previous = firstIndex

        for index in sortedIndices.dropFirst() {
            if index == previous + 1 {
                previous = index
                continue
            }

            components.append(formattedShortcutRange(start: rangeStart, end: previous))
            rangeStart = index
            previous = index
        }

        components.append(formattedShortcutRange(start: rangeStart, end: previous))
        return components.joined(separator: ", ")
    }

    private static func formattedShortcutRange(start: Int, end: Int) -> String {
        if start == end {
            return shortcutSlotLabel(for: start)
        }
        return "\(shortcutSlotLabel(for: start))–\(shortcutSlotLabel(for: end))"
    }

    private static func shortcutSlotLabel(for index: Int) -> String {
        index == 9 ? "0" : String(index + 1)
    }
}
