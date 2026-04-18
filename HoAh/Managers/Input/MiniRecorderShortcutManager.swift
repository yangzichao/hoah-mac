import Foundation
import KeyboardShortcuts
import AppKit

extension KeyboardShortcuts.Name {
    static let escapeRecorder = Self("escapeRecorder")
    static let cancelRecorder = Self("cancelRecorder")
    // AI Prompt selection shortcuts.
    //
    // Two-name pattern mirroring ClipboardAIActionShortcutManager:
    // - `selectPromptNConfig` persists the user's chosen binding (defaults
    //   declared here so first-launch users get ⌘1…⌘0 automatically).
    // - `selectPromptN` is the active runtime name that is toggled on/off as
    //   the mini-recorder shows/hides.
    // The old single-name layout wrote the default to UserDefaults on every
    // show, which clobbered any user override on the next recorder open.
    static let selectPrompt1Config = Self("selectPrompt1Config", default: .init(.one, modifiers: .command))
    static let selectPrompt2Config = Self("selectPrompt2Config", default: .init(.two, modifiers: .command))
    static let selectPrompt3Config = Self("selectPrompt3Config", default: .init(.three, modifiers: .command))
    static let selectPrompt4Config = Self("selectPrompt4Config", default: .init(.four, modifiers: .command))
    static let selectPrompt5Config = Self("selectPrompt5Config", default: .init(.five, modifiers: .command))
    static let selectPrompt6Config = Self("selectPrompt6Config", default: .init(.six, modifiers: .command))
    static let selectPrompt7Config = Self("selectPrompt7Config", default: .init(.seven, modifiers: .command))
    static let selectPrompt8Config = Self("selectPrompt8Config", default: .init(.eight, modifiers: .command))
    static let selectPrompt9Config = Self("selectPrompt9Config", default: .init(.nine, modifiers: .command))
    static let selectPrompt10Config = Self("selectPrompt10Config", default: .init(.zero, modifiers: .command))

    static let selectPrompt1 = Self("selectPrompt1")
    static let selectPrompt2 = Self("selectPrompt2")
    static let selectPrompt3 = Self("selectPrompt3")
    static let selectPrompt4 = Self("selectPrompt4")
    static let selectPrompt5 = Self("selectPrompt5")
    static let selectPrompt6 = Self("selectPrompt6")
    static let selectPrompt7 = Self("selectPrompt7")
    static let selectPrompt8 = Self("selectPrompt8")
    static let selectPrompt9 = Self("selectPrompt9")
    static let selectPrompt10 = Self("selectPrompt10")
}

@MainActor
class MiniRecorderShortcutManager: ObservableObject {
    private var whisperState: WhisperState
    private var visibilityTask: Task<Void, Never>?
    private let promptShortcutNames: [KeyboardShortcuts.Name] = [
        .selectPrompt1, .selectPrompt2, .selectPrompt3, .selectPrompt4, .selectPrompt5,
        .selectPrompt6, .selectPrompt7, .selectPrompt8, .selectPrompt9, .selectPrompt10
    ]
    private let promptConfigShortcutNames: [KeyboardShortcuts.Name] = [
        .selectPrompt1Config, .selectPrompt2Config, .selectPrompt3Config, .selectPrompt4Config, .selectPrompt5Config,
        .selectPrompt6Config, .selectPrompt7Config, .selectPrompt8Config, .selectPrompt9Config, .selectPrompt10Config
    ]

    private var isCancelHandlerSetup = false

    // Double-tap Escape handling
    private var escFirstPressTime: Date? = nil
    private let escSecondPressThreshold: TimeInterval = 1.5
    private var isEscapeHandlerSetup = false
    private var escapeTimeoutTask: Task<Void, Never>?

    init(whisperState: WhisperState) {
        self.whisperState = whisperState
        setupVisibilityObserver()
        setupEscapeHandlerOnce()
        setupCancelHandlerOnce()
    }

    private func setupVisibilityObserver() {
        visibilityTask = Task { @MainActor in
            for await isVisible in whisperState.$isMiniRecorderVisible.values {
                if isVisible {
                    activateEscapeShortcut()
                    activateCancelShortcut()
                    setupPromptShortcuts()
                } else {
                    deactivateEscapeShortcut()
                    deactivateCancelShortcut()
                    removePromptShortcuts()
                }
            }
        }
    }

    // Setup escape handler once
    private func setupEscapeHandlerOnce() {
        guard !isEscapeHandlerSetup else { return }
        isEscapeHandlerSetup = true

        KeyboardShortcuts.onKeyDown(for: .escapeRecorder) { [weak self] in
            Task { @MainActor in
                guard let self = self,
                      await self.whisperState.isMiniRecorderVisible else { return }

                // Don't process if custom shortcut is configured
                guard KeyboardShortcuts.getShortcut(for: .cancelRecorder) == nil else { return }

                let now = Date()
                if let firstTime = self.escFirstPressTime,
                   now.timeIntervalSince(firstTime) <= self.escSecondPressThreshold {
                    self.escFirstPressTime = nil
                    await self.whisperState.cancelRecording()
                } else {
                    self.escFirstPressTime = now
                    SoundManager.shared.playEscSound()
                    NotificationManager.shared.showNotification(
                        title: "Press ESC again to cancel recording",
                        type: .info,
                        duration: self.escSecondPressThreshold
                    )
                    self.escapeTimeoutTask?.cancel()
                    self.escapeTimeoutTask = Task { [weak self] in
                        try? await Task.sleep(nanoseconds: UInt64((self?.escSecondPressThreshold ?? 1.5) * 1_000_000_000))
                        if Task.isCancelled { return }
                        await MainActor.run {
                            self?.escFirstPressTime = nil
                        }
                    }
                }
            }
        }
    }

    private func activateEscapeShortcut() {
        // Don't activate if custom shortcut is configured
        guard KeyboardShortcuts.getShortcut(for: .cancelRecorder) == nil else { return }
        KeyboardShortcuts.setShortcut(.init(.escape), for: .escapeRecorder)
    }

    // Setup cancel handler once
    private func setupCancelHandlerOnce() {
        guard !isCancelHandlerSetup else { return }
        isCancelHandlerSetup = true

        KeyboardShortcuts.onKeyDown(for: .cancelRecorder) { [weak self] in
            Task { @MainActor in
                guard let self = self,
                      await self.whisperState.isMiniRecorderVisible,
                      KeyboardShortcuts.getShortcut(for: .cancelRecorder) != nil else { return }

                await self.whisperState.cancelRecording()
            }
        }
    }

    private func activateCancelShortcut() {
        // Handler checks if shortcut exists
    }

    private func deactivateEscapeShortcut() {
        KeyboardShortcuts.setShortcut(nil, for: .escapeRecorder)
        escFirstPressTime = nil
        escapeTimeoutTask?.cancel()
        escapeTimeoutTask = nil
    }

    private func deactivateCancelShortcut() {
        // Shortcut managed by user settings
    }

    private func setupPromptShortcuts() {
        removePromptHandlers()

        // Copy from the persisted config names to the active runtime names.
        // `getShortcut` on a Name declared with `default:` returns the default
        // on first run and the user's override afterwards, so this preserves
        // any customization across show/hide cycles.
        for (configName, activeName) in zip(promptConfigShortcutNames, promptShortcutNames) {
            KeyboardShortcuts.setShortcut(KeyboardShortcuts.getShortcut(for: configName), for: activeName)
        }

        for (index, activeName) in promptShortcutNames.enumerated() {
            setupPromptHandler(for: activeName, index: index)
        }
    }

    private func removePromptHandlers() {
        for name in promptShortcutNames {
            KeyboardShortcuts.removeHandler(for: name)
        }
    }

    private func setupPromptHandler(for shortcutName: KeyboardShortcuts.Name, index: Int) {
        KeyboardShortcuts.onKeyDown(for: shortcutName) { [weak self] in
            Task { @MainActor in
                guard let self = self,
                      await self.whisperState.isMiniRecorderVisible else { return }

                guard let enhancementService = await self.whisperState.getEnhancementService() else { return }

                let availablePrompts = enhancementService.promptShortcutPrompts
                if index < availablePrompts.count {
                    if !enhancementService.isEnhancementEnabled {
                        enhancementService.isEnhancementEnabled = true
                    }

                    enhancementService.setActivePrompt(availablePrompts[index])
                }
            }
        }
    }

    private func removePromptShortcuts() {
        for name in promptShortcutNames {
            KeyboardShortcuts.setShortcut(nil, for: name)
        }
        removePromptHandlers()
    }

    deinit {
        // Task.cancel() is thread-safe; cancel synchronously without self hop.
        visibilityTask?.cancel()
        escapeTimeoutTask?.cancel()

        // Capture the names array; referencing self inside the Task would be a
        // use-after-free since self is already being deallocated.
        let shortcutNames = promptShortcutNames

        Task { @MainActor in
            KeyboardShortcuts.setShortcut(nil, for: .escapeRecorder)
            for name in shortcutNames {
                KeyboardShortcuts.setShortcut(nil, for: name)
                KeyboardShortcuts.removeHandler(for: name)
            }
        }
    }
}
