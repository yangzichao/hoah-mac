import Foundation
import KeyboardShortcuts
import AppKit

extension KeyboardShortcuts.Name {
    static let escapeRecorder = Self("escapeRecorder")
    static let cancelRecorder = Self("cancelRecorder")
    // AI Prompt selection shortcuts
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
                    self.escapeTimeoutTask = Task { [weak self] in
                        try? await Task.sleep(nanoseconds: UInt64((self?.escSecondPressThreshold ?? 1.5) * 1_000_000_000))
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

        KeyboardShortcuts.setShortcut(.init(.one, modifiers: .command), for: .selectPrompt1)
        KeyboardShortcuts.setShortcut(.init(.two, modifiers: .command), for: .selectPrompt2)
        KeyboardShortcuts.setShortcut(.init(.three, modifiers: .command), for: .selectPrompt3)
        KeyboardShortcuts.setShortcut(.init(.four, modifiers: .command), for: .selectPrompt4)
        KeyboardShortcuts.setShortcut(.init(.five, modifiers: .command), for: .selectPrompt5)
        KeyboardShortcuts.setShortcut(.init(.six, modifiers: .command), for: .selectPrompt6)
        KeyboardShortcuts.setShortcut(.init(.seven, modifiers: .command), for: .selectPrompt7)
        KeyboardShortcuts.setShortcut(.init(.eight, modifiers: .command), for: .selectPrompt8)
        KeyboardShortcuts.setShortcut(.init(.nine, modifiers: .command), for: .selectPrompt9)
        KeyboardShortcuts.setShortcut(.init(.zero, modifiers: .command), for: .selectPrompt10)

        // Setup handlers
        setupPromptHandler(for: .selectPrompt1, index: 0)
        setupPromptHandler(for: .selectPrompt2, index: 1)
        setupPromptHandler(for: .selectPrompt3, index: 2)
        setupPromptHandler(for: .selectPrompt4, index: 3)
        setupPromptHandler(for: .selectPrompt5, index: 4)
        setupPromptHandler(for: .selectPrompt6, index: 5)
        setupPromptHandler(for: .selectPrompt7, index: 6)
        setupPromptHandler(for: .selectPrompt8, index: 7)
        setupPromptHandler(for: .selectPrompt9, index: 8)
        setupPromptHandler(for: .selectPrompt10, index: 9)
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
        KeyboardShortcuts.setShortcut(nil, for: .selectPrompt1)
        KeyboardShortcuts.setShortcut(nil, for: .selectPrompt2)
        KeyboardShortcuts.setShortcut(nil, for: .selectPrompt3)
        KeyboardShortcuts.setShortcut(nil, for: .selectPrompt4)
        KeyboardShortcuts.setShortcut(nil, for: .selectPrompt5)
        KeyboardShortcuts.setShortcut(nil, for: .selectPrompt6)
        KeyboardShortcuts.setShortcut(nil, for: .selectPrompt7)
        KeyboardShortcuts.setShortcut(nil, for: .selectPrompt8)
        KeyboardShortcuts.setShortcut(nil, for: .selectPrompt9)
        KeyboardShortcuts.setShortcut(nil, for: .selectPrompt10)
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
