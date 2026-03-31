import Testing
@testable import HoAh
import Foundation

// MARK: - Mock Storage for Testing

/// In-memory storage implementation for testing
class MockSettingsStorage: SettingsStorage {
    var savedState: AppSettingsState?
    var loadCallCount = 0
    var saveCallCount = 0
    
    func load() -> AppSettingsState? {
        loadCallCount += 1
        return savedState
    }
    
    func save(_ state: AppSettingsState) {
        saveCallCount += 1
        savedState = state
    }
    
    func reset() {
        savedState = nil
        loadCallCount = 0
        saveCallCount = 0
    }
}

// MARK: - AppSettingsState Tests

@Suite("AppSettingsState Tests")
struct AppSettingsStateTests {
    
    @Test("Default state has expected values")
    func defaultStateValues() {
        let state = AppSettingsState()
        
        #expect(state.version == 1)
        #expect(state.hasCompletedOnboarding == false)
        #expect(state.appInterfaceLanguage == "system")
        #expect(state.isMenuBarOnly == false)
        #expect(state.recorderType == "mini")
        #expect(state.preserveTranscriptInClipboard == true)
        #expect(state.selectedHotkey1 == "rightOption") // Default is rightOption, not none
        #expect(state.selectedHotkey2 == "none")
        #expect(state.isMiddleClickToggleEnabled == false)
        #expect(state.middleClickActivationDelay == 200) // Default is 200, not 0
        #expect(state.isSoundFeedbackEnabled == true)
        #expect(state.isSystemMuteEnabled == true) // Default is true
        #expect(state.isAIEnhancementEnabled == false)
        #expect(state.clipboardEnhancementShortcutSlotEnabledStates.count == AppSettingsState.clipboardEnhancementShortcutSlotCount)
        #expect(state.clipboardEnhancementShortcutSlotEnabledStates.allSatisfy { $0 })
        #expect(state.useScreenCaptureContext == false)
        #expect(state.arePromptTriggersEnabled == false)
    }
    
    @Test("State is Codable")
    func stateIsCodable() throws {
        var state = AppSettingsState()
        state.hasCompletedOnboarding = true
        state.appInterfaceLanguage = "en"
        state.recorderType = "notch"
        state.selectedHotkey1 = "option"
        state.clipboardEnhancementShortcutSlotEnabledStates = [true, false]

        let encoder = JSONEncoder()
        let data = try encoder.encode(state)
        
        let decoder = JSONDecoder()
        let decoded = try decoder.decode(AppSettingsState.self, from: data)
        
        #expect(decoded.hasCompletedOnboarding == true)
        #expect(decoded.appInterfaceLanguage == "en")
        #expect(decoded.recorderType == "notch")
        #expect(decoded.selectedHotkey1 == "option")
        #expect(decoded.clipboardEnhancementShortcutSlotEnabledStates.count == AppSettingsState.clipboardEnhancementShortcutSlotCount)
        #expect(decoded.clipboardEnhancementShortcutSlotEnabledStates[0] == true)
        #expect(decoded.clipboardEnhancementShortcutSlotEnabledStates[1] == false)
    }
    
    @Test("State validation passes for valid state")
    func validStateValidation() {
        let state = AppSettingsState()
        let result = state.validate()
        
        #expect(result.isValid)
        #expect(result.errors.isEmpty)
    }
    
    @Test("State validation fails for invalid language")
    func invalidLanguageValidation() {
        var state = AppSettingsState()
        state.appInterfaceLanguage = "invalid"
        
        let result = state.validate()
        
        #expect(!result.isValid)
        #expect(result.errors.contains { $0.lowercased().contains("language") })
    }
    
    @Test("State validation fails for invalid recorder type")
    func invalidRecorderTypeValidation() {
        var state = AppSettingsState()
        state.recorderType = "invalid"
        
        let result = state.validate()
        
        #expect(!result.isValid)
        #expect(result.errors.contains { $0.lowercased().contains("recorder") })
    }
    
    @Test("State validation fails for negative delay")
    func negativeDelayValidation() {
        var state = AppSettingsState()
        state.middleClickActivationDelay = -100
        
        let result = state.validate()
        
        #expect(!result.isValid)
        #expect(result.errors.contains { $0.lowercased().contains("delay") })
    }
    
    @Test("State validation fails for excessive delay")
    func excessiveDelayValidation() {
        var state = AppSettingsState()
        state.middleClickActivationDelay = 10000
        
        let result = state.validate()
        
        #expect(!result.isValid)
        #expect(result.errors.contains { $0.lowercased().contains("delay") })
    }
    
    @Test("State with safe defaults corrects invalid values")
    func withSafeDefaultsCorrectsInvalid() {
        var state = AppSettingsState()
        state.appInterfaceLanguage = "invalid"
        state.recorderType = "invalid"
        state.middleClickActivationDelay = -100
        
        let safeState = state.withSafeDefaults()
        
        #expect(safeState.appInterfaceLanguage == "system")
        #expect(safeState.recorderType == "mini")
        // withSafeDefaults clamps negative to 0
        #expect(safeState.middleClickActivationDelay == 0)
    }
    
    @Test("State preserves valid values when applying safe defaults")
    func withSafeDefaultsPreservesValid() {
        var state = AppSettingsState()
        state.hasCompletedOnboarding = true
        state.isSoundFeedbackEnabled = false
        state.selectedHotkey1 = "rightOption" // Use a valid hotkey value
        
        let safeState = state.withSafeDefaults()
        
        #expect(safeState.hasCompletedOnboarding == true)
        #expect(safeState.isSoundFeedbackEnabled == false)
        #expect(safeState.selectedHotkey1 == "rightOption")
    }

    @Test("State with safe defaults normalizes Selection Action slot states")
    func withSafeDefaultsNormalizesSelectionActionSlotStates() {
        var state = AppSettingsState()
        state.clipboardEnhancementShortcutSlotEnabledStates = [false, true]

        let safeState = state.withSafeDefaults()

        #expect(safeState.clipboardEnhancementShortcutSlotEnabledStates.count == AppSettingsState.clipboardEnhancementShortcutSlotCount)
        #expect(safeState.clipboardEnhancementShortcutSlotEnabledStates[0] == false)
        #expect(safeState.clipboardEnhancementShortcutSlotEnabledStates[1] == true)
        #expect(safeState.clipboardEnhancementShortcutSlotEnabledStates.dropFirst(2).allSatisfy { $0 })
    }
}

@Suite("AppSettingsSnapshot Tests")
struct AppSettingsSnapshotTests {
    @Test("Snapshot falls back to legacy system mute key")
    func snapshotFallsBackToLegacySystemMuteKey() {
        let suiteName = "AppSettingsSnapshotTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        defaults.set(false, forKey: "isSystemMuteEnabled")
        defer {
            defaults.removePersistentDomain(forName: suiteName)
        }

        let snapshot = AppSettingsSnapshot.current(userDefaults: defaults)

        #expect(snapshot.isSystemMuteEnabled == false)
    }
}

// MARK: - AppSettingsStore Tests

@MainActor
@Suite("AppSettingsStore Tests")
struct AppSettingsStoreTests {
    
    @Test("Store initializes with default values when no saved state")
    func storeInitializesWithDefaults() {
        let mockStorage = MockSettingsStorage()
        let store = AppSettingsStore(storage: mockStorage)
        
        #expect(store.hasCompletedOnboarding == false)
        #expect(store.appInterfaceLanguage == "system")
        #expect(store.recorderType == "mini")
        #expect(store.isAIEnhancementEnabled == false)
    }
    
    @Test("Store loads saved state")
    func storeLoadsSavedState() {
        let mockStorage = MockSettingsStorage()
        var savedState = AppSettingsState()
        savedState.hasCompletedOnboarding = true
        savedState.appInterfaceLanguage = "en"
        savedState.recorderType = "notch"
        savedState.clipboardEnhancementShortcutSlotEnabledStates = [true, false]
        mockStorage.savedState = savedState
        
        let store = AppSettingsStore(storage: mockStorage)
        
        #expect(store.hasCompletedOnboarding == true)
        #expect(store.appInterfaceLanguage == "en")
        #expect(store.recorderType == "notch")
        #expect(store.clipboardEnhancementShortcutSlotEnabledStates.count == AppSettingsState.clipboardEnhancementShortcutSlotCount)
        #expect(store.clipboardEnhancementShortcutSlotEnabledStates[0] == true)
        #expect(store.clipboardEnhancementShortcutSlotEnabledStates[1] == false)
    }

    @Test("Store syncs preserve clipboard setting to UserDefaults")
    func storeSyncsPreserveClipboardSettingToUserDefaults() {
        UserDefaults.hoah.removeObject(forKey: "preserveTranscriptInClipboard")
        defer { UserDefaults.hoah.removeObject(forKey: "preserveTranscriptInClipboard") }

        let mockStorage = MockSettingsStorage()
        var savedState = AppSettingsState()
        savedState.preserveTranscriptInClipboard = false
        mockStorage.savedState = savedState

        let store = AppSettingsStore(storage: mockStorage)
        #expect(UserDefaults.hoah.object(forKey: "preserveTranscriptInClipboard") as? Bool == false)

        store.preserveTranscriptInClipboard = true
        #expect(UserDefaults.hoah.object(forKey: "preserveTranscriptInClipboard") as? Bool == true)
    }

    @Test("Store syncs core runtime legacy keys to UserDefaults")
    func storeSyncsCoreRuntimeLegacyKeysToUserDefaults() {
        UserDefaults.hoah.removeObject(forKey: "isSystemMuteEnabled")
        UserDefaults.hoah.removeObject(forKey: "AppInterfaceLanguage")
        UserDefaults.hoah.removeObject(forKey: "selectedAIProvider")
        defer {
            UserDefaults.hoah.removeObject(forKey: "isSystemMuteEnabled")
            UserDefaults.hoah.removeObject(forKey: "AppInterfaceLanguage")
            UserDefaults.hoah.removeObject(forKey: "selectedAIProvider")
        }

        let mockStorage = MockSettingsStorage()
        let store = AppSettingsStore(storage: mockStorage)

        store.isSystemMuteEnabled = false
        store.appInterfaceLanguage = "en"
        store.selectedAIProvider = "OpenAI"

        #expect(UserDefaults.hoah.object(forKey: "isSystemMuteEnabled") as? Bool == false)
        #expect(UserDefaults.hoah.string(forKey: "AppInterfaceLanguage") == "en")
        #expect(UserDefaults.hoah.string(forKey: "selectedAIProvider") == "OpenAI")
    }

    @Test("Store syncs transcription settings to legacy runtime keys")
    func storeSyncsTranscriptionSettingsToLegacyRuntimeKeys() {
        let keys = [
            "SelectedLanguage",
            "HasManuallySelectedLanguage",
            "IsTextFormattingEnabled",
            "IsVADEnabled",
            "AppendTrailingSpace",
            "IsTranscriptionCleanupEnabled",
            "TranscriptionRetentionMinutes",
            "IsAudioCleanupEnabled",
            "AudioRetentionPeriod"
        ]
        keys.forEach { UserDefaults.hoah.removeObject(forKey: $0) }
        defer { keys.forEach { UserDefaults.hoah.removeObject(forKey: $0) } }

        let mockStorage = MockSettingsStorage()
        let store = AppSettingsStore(storage: mockStorage)

        store.selectedLanguage = "ja"
        store.hasManuallySelectedLanguage = true
        store.isTextFormattingEnabled = false
        store.isVADEnabled = false
        store.appendTrailingSpace = false
        store.isTranscriptionCleanupEnabled = false
        store.transcriptionRetentionMinutes = 60
        store.isAudioCleanupEnabled = true
        store.audioRetentionPeriod = 14

        #expect(UserDefaults.hoah.string(forKey: "SelectedLanguage") == "ja")
        #expect(UserDefaults.hoah.object(forKey: "HasManuallySelectedLanguage") as? Bool == true)
        #expect(UserDefaults.hoah.object(forKey: "IsTextFormattingEnabled") as? Bool == false)
        #expect(UserDefaults.hoah.object(forKey: "IsVADEnabled") as? Bool == false)
        #expect(UserDefaults.hoah.object(forKey: "AppendTrailingSpace") as? Bool == false)
        #expect(UserDefaults.hoah.object(forKey: "IsTranscriptionCleanupEnabled") as? Bool == false)
        #expect(UserDefaults.hoah.integer(forKey: "TranscriptionRetentionMinutes") == 60)
        #expect(UserDefaults.hoah.object(forKey: "IsAudioCleanupEnabled") as? Bool == true)
        #expect(UserDefaults.hoah.integer(forKey: "AudioRetentionPeriod") == 14)
    }
    
    @Test("Store saves when property changes")
    func storeSavesOnPropertyChange() {
        let mockStorage = MockSettingsStorage()
        let store = AppSettingsStore(storage: mockStorage)
        
        let initialSaveCount = mockStorage.saveCallCount
        store.hasCompletedOnboarding = true
        
        #expect(mockStorage.saveCallCount > initialSaveCount)
    }

    @Test("Store toggles Selection Action slot enabled state")
    func storeTogglesSelectionActionSlotEnabledState() {
        let mockStorage = MockSettingsStorage()
        let store = AppSettingsStore(storage: mockStorage)

        #expect(store.isClipboardEnhancementShortcutSlotEnabled(at: 1) == true)

        store.setClipboardEnhancementShortcutSlotEnabled(false, at: 1)

        #expect(store.isClipboardEnhancementShortcutSlotEnabled(at: 1) == false)
        #expect(mockStorage.savedState?.clipboardEnhancementShortcutSlotEnabledStates[1] == false)
    }
    
    @Test("Store validates language and resets invalid")
    func storeValidatesLanguage() {
        let mockStorage = MockSettingsStorage()
        let store = AppSettingsStore(storage: mockStorage)
        
        store.appInterfaceLanguage = "invalid"
        
        // Should be reset to "system"
        #expect(store.appInterfaceLanguage == "system")
    }
    
    @Test("Store validates recorder type and resets invalid")
    func storeValidatesRecorderType() {
        let mockStorage = MockSettingsStorage()
        let store = AppSettingsStore(storage: mockStorage)
        
        store.recorderType = "invalid"
        
        // Should be reset to "mini"
        #expect(store.recorderType == "mini")
    }

    @Test("Store keeps current Ollama and Doubao providers")
    func storeKeepsCurrentProviders() {
        let mockStorage = MockSettingsStorage()
        var savedState = AppSettingsState()
        savedState.selectedAIProvider = AIProvider.ollama.rawValue
        mockStorage.savedState = savedState

        let ollamaStore = AppSettingsStore(storage: mockStorage)
        #expect(ollamaStore.selectedAIProvider == AIProvider.ollama.rawValue)

        ollamaStore.selectedAIProvider = AIProvider.doubao.rawValue
        #expect(ollamaStore.selectedAIProvider == AIProvider.doubao.rawValue)
    }
    
    @Test("Store validates delay and clamps to range")
    func storeValidatesDelay() {
        let mockStorage = MockSettingsStorage()
        let store = AppSettingsStore(storage: mockStorage)
        
        store.middleClickActivationDelay = -100
        #expect(store.middleClickActivationDelay == 0)
        
        store.middleClickActivationDelay = 10000
        #expect(store.middleClickActivationDelay == 5000)
    }
    
    @Test("Store validates max recording duration")
    func storeValidatesMaxRecordingDuration() {
        let mockStorage = MockSettingsStorage()
        let store = AppSettingsStore(storage: mockStorage)
        
        store.maxRecordingDurationMinutes = -10
        #expect(store.maxRecordingDurationMinutes == 0)
        
        store.maxRecordingDurationMinutes = 500
        #expect(store.maxRecordingDurationMinutes == 180)
    }
    
    @Test("Store resolves hotkey conflicts")
    func storeResolvesHotkeyConflicts() {
        let mockStorage = MockSettingsStorage()
        let store = AppSettingsStore(storage: mockStorage)
        
        store.selectedHotkey1 = "option"
        store.selectedHotkey2 = "option"
        
        // Conflict should be resolved by setting hotkey2 to "none"
        #expect(store.selectedHotkey2 == "none")
    }
    
    @Test("Store allows same hotkey when one is none")
    func storeAllowsNoneHotkey() {
        let mockStorage = MockSettingsStorage()
        let store = AppSettingsStore(storage: mockStorage)
        
        store.selectedHotkey1 = "none"
        store.selectedHotkey2 = "none"
        
        // Both can be "none"
        #expect(store.selectedHotkey1 == "none")
        #expect(store.selectedHotkey2 == "none")
    }
    
    @Test("isRecorderConfigured returns true when hotkey1 is set")
    func isRecorderConfiguredWithHotkey1() {
        let mockStorage = MockSettingsStorage()
        let store = AppSettingsStore(storage: mockStorage)
        
        store.selectedHotkey1 = "option"
        store.selectedHotkey2 = "none"
        
        #expect(store.isRecorderConfigured == true)
    }
    
    @Test("isRecorderConfigured returns true when hotkey2 is set")
    func isRecorderConfiguredWithHotkey2() {
        let mockStorage = MockSettingsStorage()
        let store = AppSettingsStore(storage: mockStorage)
        
        store.selectedHotkey1 = "none"
        store.selectedHotkey2 = "control"
        
        #expect(store.isRecorderConfigured == true)
    }
    
    @Test("isRecorderConfigured returns false when no hotkeys set")
    func isRecorderConfiguredNoHotkeys() {
        let mockStorage = MockSettingsStorage()
        let store = AppSettingsStore(storage: mockStorage)
        
        store.selectedHotkey1 = "none"
        store.selectedHotkey2 = "none"
        
        #expect(store.isRecorderConfigured == false)
    }
    
    @Test("updateHotkeySettings resolves conflicts")
    func updateHotkeySettingsResolvesConflicts() {
        let mockStorage = MockSettingsStorage()
        let store = AppSettingsStore(storage: mockStorage)
        
        store.updateHotkeySettings(hotkey1: "option", hotkey2: "option")
        
        #expect(store.selectedHotkey1 == "option")
        #expect(store.selectedHotkey2 == "none")
    }
    
    @Test("updateHotkeySettings allows different hotkeys")
    func updateHotkeySettingsAllowsDifferent() {
        let mockStorage = MockSettingsStorage()
        let store = AppSettingsStore(storage: mockStorage)
        
        store.updateHotkeySettings(hotkey1: "option", hotkey2: "control")
        
        #expect(store.selectedHotkey1 == "option")
        #expect(store.selectedHotkey2 == "control")
    }
    
    @Test("Prompt triggers remain disabled regardless of saved state")
    func promptTriggersAlwaysDisabled() {
        let mockStorage = MockSettingsStorage()
        var savedState = AppSettingsState()
        // Set up a valid configuration so AI can be enabled
        let config = AIEnhancementConfiguration(
            name: "Test",
            provider: "Gemini",
            model: "gemini-pro",
            apiKey: "test-key"
        )
        savedState.aiEnhancementConfigurations = [config]
        savedState.activeAIConfigurationId = config.id
        savedState.isAIEnhancementEnabled = true
        savedState.arePromptTriggersEnabled = true
        mockStorage.savedState = savedState
        
        let store = AppSettingsStore(storage: mockStorage)

        // Triggers are deprecated and forced off even if persisted as true
        #expect(store.arePromptTriggersEnabled == false)
    }
    
    @Test("AI configuration management - add configuration")
    func addAIConfiguration() {
        let mockStorage = MockSettingsStorage()
        let store = AppSettingsStore(storage: mockStorage)
        
        let config = AIEnhancementConfiguration(
            name: "Test Config",
            provider: "OpenAI",
            model: "gpt-4.1",
            apiKey: "test-key"
        )
        
        store.addConfiguration(config)
        
        #expect(store.aiEnhancementConfigurations.count == 1)
        #expect(store.aiEnhancementConfigurations.first?.name == "Test Config")
    }
    
    @Test("AI configuration management - update configuration")
    func updateAIConfiguration() {
        let mockStorage = MockSettingsStorage()
        let store = AppSettingsStore(storage: mockStorage)
        
        var config = AIEnhancementConfiguration(
            name: "Original Name",
            provider: "OpenAI",
            model: "gpt-4.1",
            apiKey: "test-key"
        )
        store.addConfiguration(config)
        
        config.name = "Updated Name"
        store.updateConfiguration(config)
        
        #expect(store.aiEnhancementConfigurations.first?.name == "Updated Name")
    }
    
    @Test("AI configuration management - delete configuration")
    func deleteAIConfiguration() {
        let mockStorage = MockSettingsStorage()
        let store = AppSettingsStore(storage: mockStorage)
        
        let config = AIEnhancementConfiguration(
            name: "Test Config",
            provider: "OpenAI",
            model: "gpt-4.1",
            apiKey: "test-key"
        )
        store.addConfiguration(config)
        #expect(store.aiEnhancementConfigurations.count == 1)
        
        store.deleteConfiguration(id: config.id)
        #expect(store.aiEnhancementConfigurations.isEmpty)
    }
    
    @Test("AI configuration management - set active configuration")
    func setActiveAIConfiguration() {
        let mockStorage = MockSettingsStorage()
        let store = AppSettingsStore(storage: mockStorage)
        
        let config1 = AIEnhancementConfiguration(
            name: "Config 1",
            provider: "OpenAI",
            model: "gpt-4.1",
            apiKey: "test-key-1"
        )
        let config2 = AIEnhancementConfiguration(
            name: "Config 2",
            provider: "Gemini",
            model: "gemini-pro",
            apiKey: "test-key-2"
        )
        
        store.addConfiguration(config1)
        store.addConfiguration(config2)
        store.setActiveConfiguration(id: config2.id)
        
        #expect(store.activeAIConfigurationId == config2.id)
        #expect(store.activeAIConfiguration?.name == "Config 2")
    }
    
    @Test("validAIConfigurations filters invalid configs")
    func validAIConfigurationsFilters() {
        let mockStorage = MockSettingsStorage()
        let store = AppSettingsStore(storage: mockStorage)
        
        // Valid config
        let validConfig = AIEnhancementConfiguration(
            name: "Valid",
            provider: "OpenAI",
            model: "gpt-4.1",
            apiKey: "test-key"
        )
        
        // Invalid config (no API key, empty name)
        let invalidConfig = AIEnhancementConfiguration(
            name: "",
            provider: "OpenAI",
            model: "gpt-4.1"
        )
        
        store.addConfiguration(validConfig)
        store.addConfiguration(invalidConfig)
        
        #expect(store.aiEnhancementConfigurations.count == 2)
        #expect(store.validAIConfigurations.count == 1)
        #expect(store.validAIConfigurations.first?.name == "Valid")
    }
    
    @Test("Default selected prompt is Polish")
    func defaultSelectedPromptIsPolish() {
        let mockStorage = MockSettingsStorage()
        let store = AppSettingsStore(storage: mockStorage)
        
        #expect(store.selectedPromptId == PredefinedPrompts.polishPromptId.uuidString)
    }
    
    @Test("Translation language getter and setter")
    func translationLanguageGetterSetter() {
        let mockStorage = MockSettingsStorage()
        let store = AppSettingsStore(storage: mockStorage)
        
        store.translationLanguage = .english
        #expect(store.translationTargetLanguage == TranslationLanguage.english.rawValue)
        #expect(store.translationLanguage == .english)
        
        store.translationLanguage = .simplifiedChinese
        #expect(store.translationLanguage == .simplifiedChinese)
    }
}

// MARK: - UserDefaultsStorage Tests

@Suite("UserDefaultsStorage Tests")
struct UserDefaultsStorageTests {
    
    @Test("Save and load round trip")
    func saveAndLoadRoundTrip() {
        let storage = UserDefaultsStorage()
        
        var state = AppSettingsState()
        state.hasCompletedOnboarding = true
        state.appInterfaceLanguage = "zh-Hans"
        state.recorderType = "notch"
        state.selectedHotkey1 = "option"
        
        storage.save(state)
        
        let loaded = storage.load()
        
        #expect(loaded != nil)
        #expect(loaded?.hasCompletedOnboarding == true)
        #expect(loaded?.appInterfaceLanguage == "zh-Hans")
        #expect(loaded?.recorderType == "notch")
        #expect(loaded?.selectedHotkey1 == "option")
    }
}

// MARK: - Auto Export Settings Tests

@Suite("Auto Export Settings Tests")
@MainActor
struct AutoExportSettingsTests {
    
    @Test("Auto export toggle persists correctly")
    func autoExportTogglePersists() {
        let mockStorage = MockSettingsStorage()
        let store = AppSettingsStore(storage: mockStorage)
        
        // Default should be false
        #expect(store.isAutoExportEnabled == false)
        
        // Enable and verify
        store.isAutoExportEnabled = true
        #expect(store.isAutoExportEnabled == true)
        #expect(mockStorage.savedState?.isAutoExportEnabled == true)
        
        // Disable and verify
        store.isAutoExportEnabled = false
        #expect(store.isAutoExportEnabled == false)
        #expect(mockStorage.savedState?.isAutoExportEnabled == false)
    }
    
    @Test("Auto export state loads from storage")
    func autoExportStateLoadsFromStorage() {
        let mockStorage = MockSettingsStorage()
        var initialState = AppSettingsState()
        initialState.isAutoExportEnabled = true
        mockStorage.savedState = initialState
        
        let store = AppSettingsStore(storage: mockStorage)
        
        #expect(store.isAutoExportEnabled == true)
    }
    
    @Test("Has valid auto export path returns false when no bookmark")
    func hasValidPathReturnsFalseWhenNoBookmark() {
        SecurityScopedBookmarkManager.clearBookmark()
        
        let mockStorage = MockSettingsStorage()
        let store = AppSettingsStore(storage: mockStorage)
        
        #expect(store.hasValidAutoExportPath == false)
    }
}
