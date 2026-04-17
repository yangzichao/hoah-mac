import Foundation
import KeyboardShortcuts
import Carbon
import AppKit
import Combine

extension KeyboardShortcuts.Name {
    static let toggleMiniRecorder = Self("toggleMiniRecorder")
    static let toggleMiniRecorder2 = Self("toggleMiniRecorder2")
    static let toggleMiniRecorderAppend = Self("toggleMiniRecorderAppend")
    static let pasteLastTranscription = Self("pasteLastTranscription")
    static let pasteLastEnhancement = Self("pasteLastEnhancement")
    static let retryLastTranscription = Self("retryLastTranscription")
}

// Hotkey configuration is managed by AppSettingsStore. Read settings from appSettings parameter.
@MainActor
class HotkeyManager: ObservableObject {
    // MARK: - Computed Properties (read from AppSettingsStore)
    
    /// Primary hotkey option - reads from AppSettingsStore
    var selectedHotkey1: HotkeyOption {
        get { HotkeyOption(rawValue: appSettings.selectedHotkey1) ?? .rightOption }
        set { appSettings.selectedHotkey1 = newValue.rawValue }
    }
    
    /// Secondary hotkey option - reads from AppSettingsStore
    var selectedHotkey2: HotkeyOption {
        get { HotkeyOption(rawValue: appSettings.selectedHotkey2) ?? .none }
        set { 
            if newValue == .none {
                KeyboardShortcuts.setShortcut(nil, for: .toggleMiniRecorder2)
            }
            appSettings.selectedHotkey2 = newValue.rawValue 
        }
    }
    
    /// Whether middle-click toggle is enabled - reads from AppSettingsStore
    var isMiddleClickToggleEnabled: Bool {
        get { appSettings.isMiddleClickToggleEnabled }
        set { appSettings.isMiddleClickToggleEnabled = newValue }
    }
    
    /// Middle-click activation delay - reads from AppSettingsStore
    var middleClickActivationDelay: Int {
        get { appSettings.middleClickActivationDelay }
        set { appSettings.middleClickActivationDelay = newValue }
    }
    
    // MARK: - Dependencies
    private var whisperState: WhisperState
    private var appSettings: AppSettingsStore
    private var cancellables = Set<AnyCancellable>()
    private var miniRecorderShortcutManager: MiniRecorderShortcutManager
    private var clipboardAIActionShortcutManager: ClipboardAIActionShortcutManager?
    
    // MARK: - Helper Properties
    private var canProcessHotkeyAction: Bool {
        whisperState.recordingState != .finishing &&
        whisperState.recordingState != .transcribing &&
        whisperState.recordingState != .enhancing &&
        whisperState.recordingState != .busy
    }
    
    // NSEvent monitoring for modifier keys
    private var globalEventMonitor: Any?
    private var localEventMonitor: Any?
    
    // Middle-click event monitoring
    private var middleClickMonitors: [Any?] = []
    private var middleClickTask: Task<Void, Never>?
    
    // Key state tracking
    private var currentKeyState = false
    private var optionAutoSendKeyState = false
    private var keyPressStartTime: Date?
    private let briefPressThreshold = 1.7
    private var isHandsFreeMode = false

    // Multi-press gesture detection (AirPods-style)
    // See docs/specs/MULTI_PRESS_GESTURE.md
    private var multiPressGesture = MultiPressGestureStateMachine()
    private var multiPressWindowTask: Task<Void, Never>?
    private let multiPressWindow: TimeInterval = 0.5
    
    // Debounce for Fn key
    private var fnDebounceTask: Task<Void, Never>?
    private var pendingFnKeyState: Bool? = nil
    
    // Keyboard shortcut state tracking
    private var shortcutKeyPressStartTime: Date?
    private var isShortcutHandsFreeMode = false
    private var shortcutCurrentKeyState = false
    private var lastShortcutTriggerTime: Date?
    private var lastAppendShortcutTriggerTime: Date?
    private let shortcutCooldownInterval: TimeInterval = 0.5
    
    enum HotkeyOption: String, CaseIterable {
        case none = "none"
        case rightOption = "rightOption"
        case leftOption = "leftOption"
        case leftControl = "leftControl" 
        case rightControl = "rightControl"
        case fn = "fn"
        case rightCommand = "rightCommand"
        case rightShift = "rightShift"
        case custom = "custom"
        
        var displayName: String {
            switch self {
            case .none: return NSLocalizedString("None", comment: "")
            case .rightOption: return NSLocalizedString("Right Option (⌥)", comment: "")
            case .leftOption: return NSLocalizedString("Left Option (⌥)", comment: "")
            case .leftControl: return NSLocalizedString("Left Control (⌃)", comment: "")
            case .rightControl: return NSLocalizedString("Right Control (⌃)", comment: "")
            case .fn: return NSLocalizedString("Fn", comment: "")
            case .rightCommand: return NSLocalizedString("Right Command (⌘)", comment: "")
            case .rightShift: return NSLocalizedString("Right Shift (⇧)", comment: "")
            case .custom: return NSLocalizedString("Custom", comment: "")
            }
        }
        
        var keyCode: CGKeyCode? {
            switch self {
            case .rightOption: return 0x3D
            case .leftOption: return 0x3A
            case .leftControl: return 0x3B
            case .rightControl: return 0x3E
            case .fn: return 0x3F
            case .rightCommand: return 0x36
            case .rightShift: return 0x3C
            case .custom, .none: return nil
            }
        }
        
        var isModifierKey: Bool {
            return self != .custom && self != .none
        }
    }

    // MARK: - Display Helpers
    var primaryHotkeyShortcut: KeyboardShortcuts.Shortcut? {
        guard selectedHotkey1 == .custom else { return nil }
        return KeyboardShortcuts.getShortcut(for: .toggleMiniRecorder)
    }

    var secondaryHotkeyShortcut: KeyboardShortcuts.Shortcut? {
        guard selectedHotkey2 == .custom else { return nil }
        return KeyboardShortcuts.getShortcut(for: .toggleMiniRecorder2)
    }

    var hasConfiguredRecordingTrigger: Bool {
        let primaryConfigured = selectedHotkey1 != .none && (selectedHotkey1 != .custom || primaryHotkeyShortcut != nil)
        let secondaryConfigured = selectedHotkey2 != .none && (selectedHotkey2 != .custom || secondaryHotkeyShortcut != nil)
        return primaryConfigured || secondaryConfigured
    }

    var primaryHotkeyDisplayName: String {
        if let shortcut = primaryHotkeyShortcut {
            return "\(shortcut)"
        }
        return selectedHotkey1.displayName
    }

    var primaryHotkeyDisplayNameShort: String {
        let displayName = primaryHotkeyDisplayName
        if let shortName = displayName.split(separator: "(").first {
            return shortName.trimmingCharacters(in: .whitespaces)
        }
        return displayName
    }
    
    init(whisperState: WhisperState, appSettings: AppSettingsStore) {
        self.whisperState = whisperState
        self.appSettings = appSettings
        self.miniRecorderShortcutManager = MiniRecorderShortcutManager(whisperState: whisperState)
        if let enhancementService = whisperState.enhancementService {
            self.clipboardAIActionShortcutManager = ClipboardAIActionShortcutManager(
                enhancementService: enhancementService,
                appSettings: appSettings,
                modelContext: whisperState.modelContext
            )
        }

        KeyboardShortcuts.onKeyUp(for: .pasteLastTranscription) { [weak self] in
            guard let self = self else { return }
            Task { @MainActor in
                LastTranscriptionService.pasteLastTranscription(from: self.whisperState.modelContext)
            }
        }

        KeyboardShortcuts.onKeyUp(for: .pasteLastEnhancement) { [weak self] in
            guard let self = self else { return }
            Task { @MainActor in
                LastTranscriptionService.pasteLastEnhancement(from: self.whisperState.modelContext)
            }
        }

        KeyboardShortcuts.onKeyUp(for: .retryLastTranscription) { [weak self] in
            guard let self = self else { return }
            Task { @MainActor in
                LastTranscriptionService.retryLastTranscription(from: self.whisperState.modelContext, whisperState: self.whisperState)
            }
        }
        
        // Subscribe to hotkey settings changes from AppSettingsStore
        setupSettingsObservers()
        
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 100_000_000)
            self.setupHotkeyMonitoring()
        }
    }
    
    // MARK: - Settings Observers
    
    private func setupSettingsObservers() {
        // Observe hotkey1 changes
        appSettings.$selectedHotkey1
            .dropFirst() // Skip initial value
            .sink { [weak self] _ in
                self?.objectWillChange.send()
                self?.setupHotkeyMonitoring()
            }
            .store(in: &cancellables)
        
        // Observe hotkey2 changes
        appSettings.$selectedHotkey2
            .dropFirst()
            .sink { [weak self] newValue in
                self?.objectWillChange.send()
                if newValue == "none" {
                    KeyboardShortcuts.setShortcut(nil, for: .toggleMiniRecorder2)
                }
                self?.setupHotkeyMonitoring()
            }
            .store(in: &cancellables)
        
        // Observe middle-click toggle changes
        appSettings.$isMiddleClickToggleEnabled
            .dropFirst()
            .sink { [weak self] _ in
                self?.objectWillChange.send()
                self?.setupHotkeyMonitoring()
            }
            .store(in: &cancellables)
        
        // Observe middle-click delay changes
        appSettings.$middleClickActivationDelay
            .dropFirst()
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)

        appSettings.$multiPressGestureAutoSendEnabled
            .dropFirst()
            .sink { [weak self] _ in
                self?.objectWillChange.send()
                self?.setupHotkeyMonitoring()
            }
            .store(in: &cancellables)

        whisperState.$isMiniRecorderVisible
            .dropFirst()
            .sink { [weak self] isVisible in
                guard let self, !isVisible else { return }
                self.cancelMultiPressWindowTimer()
                self.multiPressGesture.reset()
            }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: Notification.Name("KeyboardShortcuts_shortcutByNameDidChange"))
            .sink { [weak self] notification in
                guard let self = self,
                      let name = Self.shortcutName(from: notification),
                      name == .toggleMiniRecorder || name == .toggleMiniRecorder2 || name == .toggleMiniRecorderAppend else { return }
                self.objectWillChange.send()
                self.updateShortcutStatus()
            }
            .store(in: &cancellables)
    }
    
    private func setupHotkeyMonitoring() {
        removeAllMonitoring()
        removeCustomShortcutHandlers()
        
        setupModifierKeyMonitoring()
        setupCustomShortcutMonitoring()
        setupMiddleClickMonitoring()
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

    private func removeCustomShortcutHandlers() {
        KeyboardShortcuts.removeHandler(for: .toggleMiniRecorder)
        KeyboardShortcuts.removeHandler(for: .toggleMiniRecorder2)
        KeyboardShortcuts.removeHandler(for: .toggleMiniRecorderAppend)
    }
    
    private func setupModifierKeyMonitoring() {
        let hasModifierRecordingHotkey = (selectedHotkey1.isModifierKey && selectedHotkey1 != .none) || (selectedHotkey2.isModifierKey && selectedHotkey2 != .none)
        guard hasModifierRecordingHotkey || appSettings.multiPressGestureAutoSendEnabled else { return }

        globalEventMonitor = NSEvent.addGlobalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
            guard let self = self else { return }
            Task { @MainActor in
                await self.handleModifierKeyEvent(event)
            }
        }
        
        localEventMonitor = NSEvent.addLocalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
            guard let self = self else { return event }
            Task { @MainActor in
                await self.handleModifierKeyEvent(event)
            }
            return event
        }
    }
    
    private func setupMiddleClickMonitoring() {
        guard isMiddleClickToggleEnabled else { return }

        // Mouse Down
        let downMonitor = NSEvent.addGlobalMonitorForEvents(matching: .otherMouseDown) { [weak self] event in
            guard let self = self, event.buttonNumber == 2 else { return }

            self.middleClickTask?.cancel()
            self.middleClickTask = Task {
                do {
                    let delay = UInt64(self.middleClickActivationDelay) * 1_000_000 // ms to ns
                    try await Task.sleep(nanoseconds: delay)
                    
                    guard self.isMiddleClickToggleEnabled, !Task.isCancelled else { return }
                    
                    Task { @MainActor in
                        guard self.canProcessHotkeyAction else { return }
                        await self.whisperState.handleToggleMiniRecorder()
                    }
                } catch {
                    // Cancelled
                }
            }
        }

        // Mouse Up
        let upMonitor = NSEvent.addGlobalMonitorForEvents(matching: .otherMouseUp) { [weak self] event in
            guard let self = self, event.buttonNumber == 2 else { return }
            self.middleClickTask?.cancel()
        }

        middleClickMonitors = [downMonitor, upMonitor]
    }
    
    private func setupCustomShortcutMonitoring() {
        // Hotkey 1
        if selectedHotkey1 == .custom {
            KeyboardShortcuts.onKeyDown(for: .toggleMiniRecorder) { [weak self] in
                Task { @MainActor in await self?.handleCustomShortcutKeyDown() }
            }
            KeyboardShortcuts.onKeyUp(for: .toggleMiniRecorder) { [weak self] in
                Task { @MainActor in await self?.handleCustomShortcutKeyUp() }
            }
        }
        // Hotkey 2
        if selectedHotkey2 == .custom {
            KeyboardShortcuts.onKeyDown(for: .toggleMiniRecorder2) { [weak self] in
                Task { @MainActor in await self?.handleCustomShortcutKeyDown() }
            }
            KeyboardShortcuts.onKeyUp(for: .toggleMiniRecorder2) { [weak self] in
                Task { @MainActor in await self?.handleCustomShortcutKeyUp() }
            }
        }

        if KeyboardShortcuts.getShortcut(for: .toggleMiniRecorderAppend) != nil {
            KeyboardShortcuts.onKeyUp(for: .toggleMiniRecorderAppend) { [weak self] in
                Task { @MainActor in await self?.handleAppendShortcutTrigger() }
            }
        }
    }
    
    private func removeAllMonitoring() {
        if let monitor = globalEventMonitor {
            NSEvent.removeMonitor(monitor)
            globalEventMonitor = nil
        }
        
        if let monitor = localEventMonitor {
            NSEvent.removeMonitor(monitor)
            localEventMonitor = nil
        }
        
        for monitor in middleClickMonitors {
            if let monitor = monitor {
                NSEvent.removeMonitor(monitor)
            }
        }
        middleClickMonitors = []
        middleClickTask?.cancel()
        
        resetKeyStates()
    }
    
    private func resetKeyStates() {
        currentKeyState = false
        optionAutoSendKeyState = false
        keyPressStartTime = nil
        isHandsFreeMode = false
        shortcutCurrentKeyState = false
        shortcutKeyPressStartTime = nil
        isShortcutHandsFreeMode = false
        multiPressWindowTask?.cancel()
        multiPressWindowTask = nil
        multiPressGesture.reset()
    }
    
    private func handleModifierKeyEvent(_ event: NSEvent) async {
        let keycode = event.keyCode
        let flags = event.modifierFlags

        if appSettings.multiPressGestureAutoSendEnabled, keycode == HotkeyOption.rightOption.keyCode {
            await processOptionAutoSendKeyPress(isKeyPressed: !optionAutoSendKeyState)
        }
        
        // Determine which hotkey (if any) is being triggered
        let activeHotkey: HotkeyOption?
        if selectedHotkey1.isModifierKey && selectedHotkey1.keyCode == keycode {
            activeHotkey = selectedHotkey1
        } else if selectedHotkey2.isModifierKey && selectedHotkey2.keyCode == keycode {
            activeHotkey = selectedHotkey2
        } else {
            activeHotkey = nil
        }
        
        guard let hotkey = activeHotkey else { return }
        if appSettings.multiPressGestureAutoSendEnabled, hotkey == .rightOption {
            return
        }
        
        var isKeyPressed = false
        
        switch hotkey {
        case .rightOption, .leftOption:
            isKeyPressed = flags.contains(.option)
        case .leftControl, .rightControl:
            isKeyPressed = flags.contains(.control)
        case .fn:
            isKeyPressed = flags.contains(.function)
            // Debounce Fn key
            pendingFnKeyState = isKeyPressed
            fnDebounceTask?.cancel()
            fnDebounceTask = Task { [pendingState = isKeyPressed] in
                try? await Task.sleep(nanoseconds: 75_000_000) // 75ms
                if pendingFnKeyState == pendingState {
                    await self.processKeyPress(isKeyPressed: pendingState)
                }
            }
            return
        case .rightCommand:
            isKeyPressed = flags.contains(.command)
        case .rightShift:
            isKeyPressed = flags.contains(.shift)
        case .custom, .none:
            return // Should not reach here
        }

        await processKeyPress(isKeyPressed: isKeyPressed)
    }

    private func processKeyPress(isKeyPressed: Bool) async {
        guard isKeyPressed != currentKeyState else { return }
        currentKeyState = isKeyPressed
        await processLegacyKeyPress(isKeyPressed: isKeyPressed)
    }

    private func processOptionAutoSendKeyPress(isKeyPressed: Bool) async {
        guard isKeyPressed != optionAutoSendKeyState else { return }
        optionAutoSendKeyState = isKeyPressed
        await processMultiPressGestureKeyPress(isKeyPressed: isKeyPressed)
    }

    private func processLegacyKeyPress(isKeyPressed: Bool) async {
        if isKeyPressed {
            keyPressStartTime = Date()
            if isHandsFreeMode {
                isHandsFreeMode = false
                keyPressStartTime = nil
                guard canProcessHotkeyAction else { return }
                await whisperState.handleToggleMiniRecorder()
                return
            }

            if !whisperState.isMiniRecorderVisible {
                guard canProcessHotkeyAction else { return }
                await whisperState.handleToggleMiniRecorder()
            }
        } else {
            if let startTime = keyPressStartTime {
                let pressDuration = Date().timeIntervalSince(startTime)

                if pressDuration < briefPressThreshold {
                    isHandsFreeMode = true
                } else {
                    keyPressStartTime = nil
                    guard canProcessHotkeyAction else { return }
                    await whisperState.handleToggleMiniRecorder()
                    return
                }
            }

            keyPressStartTime = nil
        }
    }

    private func processMultiPressGestureKeyPress(isKeyPressed: Bool) async {
        let actions = if isKeyPressed {
            multiPressGesture.handleKeyDown(isRecorderVisible: whisperState.isMiniRecorderVisible)
        } else {
            multiPressGesture.handleKeyUp()
        }

        await applyMultiPressGestureActions(actions)
    }

    private func applyMultiPressGestureActions(_ actions: [MultiPressGestureAction]) async {
        for action in actions {
            switch action {
            case .startRecording(let mode):
                guard canProcessHotkeyAction else {
                    cancelMultiPressWindowTimer()
                    multiPressGesture.reset()
                    return
                }
                whisperState.recordingMode = mode
                await whisperState.handleToggleMiniRecorder()
            case .updateMode(let mode):
                whisperState.recordingMode = mode
            case .restartWindowTimer:
                resetMultiPressWindowTimer()
            case .cancelWindowTimer:
                cancelMultiPressWindowTimer()
            case .stopRecording:
                cancelMultiPressWindowTimer()
                guard canProcessHotkeyAction else {
                    multiPressGesture.reset()
                    return
                }
                await whisperState.handleToggleMiniRecorder()
                multiPressGesture.reset()
            }
        }
    }

    private func resetMultiPressWindowTimer() {
        cancelMultiPressWindowTimer()
        multiPressWindowTask = Task { [weak self] in
            let window = self?.multiPressWindow ?? 0.5
            try? await Task.sleep(nanoseconds: UInt64(window * 1_000_000_000))
            guard let self, !Task.isCancelled else { return }
            let actions = self.multiPressGesture.handleWindowExpired()
            await self.applyMultiPressGestureActions(actions)
        }
    }

    private func cancelMultiPressWindowTimer() {
        multiPressWindowTask?.cancel()
        multiPressWindowTask = nil
    }

    private func handleCustomShortcutKeyDown() async {
        if let lastTrigger = lastShortcutTriggerTime,
           Date().timeIntervalSince(lastTrigger) < shortcutCooldownInterval {
            return
        }
        
        guard !shortcutCurrentKeyState else { return }
        shortcutCurrentKeyState = true
        lastShortcutTriggerTime = Date()
        shortcutKeyPressStartTime = Date()
        
        if isShortcutHandsFreeMode {
            isShortcutHandsFreeMode = false
            guard canProcessHotkeyAction else { return }
            await whisperState.handleToggleMiniRecorder()
            return
        }
        
        if !whisperState.isMiniRecorderVisible {
            guard canProcessHotkeyAction else { return }
            await whisperState.handleToggleMiniRecorder()
        }
    }
    
    private func handleCustomShortcutKeyUp() async {
        guard shortcutCurrentKeyState else { return }
        shortcutCurrentKeyState = false
        
        let now = Date()
        
        if let startTime = shortcutKeyPressStartTime {
            let pressDuration = now.timeIntervalSince(startTime)
            
            if pressDuration < briefPressThreshold {
                isShortcutHandsFreeMode = true
            } else {
                guard canProcessHotkeyAction else { return }
                await whisperState.handleToggleMiniRecorder()
            }
        }
        
        shortcutKeyPressStartTime = nil
    }

    private func handleAppendShortcutTrigger() async {
        if let lastTrigger = lastAppendShortcutTriggerTime,
           Date().timeIntervalSince(lastTrigger) < shortcutCooldownInterval {
            return
        }

        lastAppendShortcutTriggerTime = Date()
        guard canProcessHotkeyAction else { return }
        whisperState.recordingMode = .append
        await whisperState.handleToggleMiniRecorder()
    }
    
    // Computed property for backward compatibility with UI
    var isShortcutConfigured: Bool {
        let isHotkey1Configured = (selectedHotkey1 == .custom) ? (KeyboardShortcuts.getShortcut(for: .toggleMiniRecorder) != nil) : true
        let isHotkey2Configured = (selectedHotkey2 == .custom) ? (KeyboardShortcuts.getShortcut(for: .toggleMiniRecorder2) != nil) : true
        return isHotkey1Configured && isHotkey2Configured
    }
    
    func updateShortcutStatus() {
        // Re-register monitors whenever any relevant shortcut changes, including append.
        setupHotkeyMonitoring()
    }
    
    deinit {
        // Capture state synchronously; referencing self in the Task below would
        // be a use-after-free since self is already being deallocated.
        let globalMonitor = globalEventMonitor
        let localMonitor = localEventMonitor
        let clickMonitors = middleClickMonitors

        // Task.cancel() is thread-safe, so cancel synchronously without self hop.
        middleClickTask?.cancel()
        multiPressWindowTask?.cancel()
        fnDebounceTask?.cancel()

        Task { @MainActor in
            if let monitor = globalMonitor { NSEvent.removeMonitor(monitor) }
            if let monitor = localMonitor { NSEvent.removeMonitor(monitor) }
            for case let monitor? in clickMonitors { NSEvent.removeMonitor(monitor) }

            KeyboardShortcuts.removeHandler(for: .toggleMiniRecorder)
            KeyboardShortcuts.removeHandler(for: .toggleMiniRecorder2)
            KeyboardShortcuts.removeHandler(for: .toggleMiniRecorderAppend)
        }
    }
}
