import Foundation

/// Lightweight accessor for persisted AppSettingsState from non-injected services.
/// Falls back to legacy keys during the migration window so runtime paths keep working.
enum AppSettingsSnapshot {
    private static let storageKey = "AppSettingsState_v1"

    static func current(userDefaults: UserDefaults = .hoah) -> AppSettingsState {
        if let data = userDefaults.data(forKey: storageKey),
           let state = try? JSONDecoder().decode(AppSettingsState.self, from: data) {
            return state
        }

        var state = AppSettingsState()

        if let selectedLanguage = userDefaults.string(forKey: "SelectedLanguage"), !selectedLanguage.isEmpty {
            state.selectedLanguage = selectedLanguage
        }
        state.hasManuallySelectedLanguage = userDefaults.object(forKey: "HasManuallySelectedLanguage") as? Bool ?? false
        state.isTextFormattingEnabled = userDefaults.object(forKey: "IsTextFormattingEnabled") as? Bool ?? true
        state.isVADEnabled = userDefaults.object(forKey: "IsVADEnabled") as? Bool ?? true
        state.appendTrailingSpace = userDefaults.object(forKey: "AppendTrailingSpace") as? Bool ?? true
        state.isSystemMuteEnabled = userDefaults.object(forKey: "isSystemMuteEnabled") as? Bool ?? true
        state.isTranscriptionCleanupEnabled = userDefaults.object(forKey: "IsTranscriptionCleanupEnabled") as? Bool ?? true

        if userDefaults.object(forKey: "TranscriptionRetentionMinutes") != nil {
            state.transcriptionRetentionMinutes = max(userDefaults.integer(forKey: "TranscriptionRetentionMinutes"), 0)
        }

        state.isAudioCleanupEnabled = userDefaults.object(forKey: "IsAudioCleanupEnabled") as? Bool ?? false

        if let audioRetention = userDefaults.object(forKey: "AudioRetentionPeriod") as? Int, audioRetention > 0 {
            state.audioRetentionPeriod = audioRetention
        }

        return state
    }
}
