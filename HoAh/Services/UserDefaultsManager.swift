import Foundation
import OSLog

enum AppGroup {
    static let identifier = "group.com.yangzichao.hoah"
}

extension UserDefaults {
    /// Returns true when the App Group container is available (i.e., sandbox/provisioned build).
    private static var canAccessAppGroup: Bool {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: AppGroup.identifier) != nil
    }
    
    static let hoah: UserDefaults = {
        if RuntimeEnvironment.isRunningTestsOrPreviews {
            return .standard
        }

        if canAccessAppGroup, let defaults = UserDefaults(suiteName: AppGroup.identifier) {
            return defaults
        }

        // In non-sandbox / developer-id builds the app group container不存在，回落到标准 defaults。
        Logger(subsystem: "com.yangzichao.hoah", category: "AppGroupMigration")
            .warning("App Group \(AppGroup.identifier) unavailable; falling back to UserDefaults.standard")
        return .standard
    }()

    static func migrateToAppGroupIfNeeded() {
        let migrationKey = "AppGroupDefaultsMigrated"
        let logger = Logger(subsystem: "com.yangzichao.hoah", category: "AppGroupMigration")
        let groupDefaults = UserDefaults.hoah

        guard !groupDefaults.bool(forKey: migrationKey) else { return }
        guard let bundleIdentifier = Bundle.main.bundleIdentifier else {
            logger.error("Missing bundle identifier; skipping defaults migration")
            groupDefaults.set(true, forKey: migrationKey)
            return
        }

        let legacyDefaults = UserDefaults.standard
        if let legacyDomain = legacyDefaults.persistentDomain(forName: bundleIdentifier), !legacyDomain.isEmpty {
            for (key, value) in legacyDomain {
                groupDefaults.set(value, forKey: key)
            }
            groupDefaults.synchronize()
            logger.notice("Migrated legacy defaults into App Group")
        }

        groupDefaults.set(true, forKey: migrationKey)
    }

    enum Keys {
        static let aiProviderApiKey = "HoAhAIProviderKey"
        static let legacyAiProviderApiKey = "HoAhAIProviderKey"
        static let audioInputMode = "audioInputMode"
        static let selectedAudioDeviceUID = "selectedAudioDeviceUID"
        static let prioritizedDevices = "prioritizedDevices"
    }
    
    // MARK: - AI Provider API Key
    var aiProviderApiKey: String? {
        get { string(forKey: Keys.aiProviderApiKey) ?? string(forKey: Keys.legacyAiProviderApiKey) }
        set {
            if let newValue {
                setValue(newValue, forKey: Keys.aiProviderApiKey)
            } else {
                removeObject(forKey: Keys.aiProviderApiKey)
            }
            removeObject(forKey: Keys.legacyAiProviderApiKey)
        }
    }

    // MARK: - Audio Input Mode
    var audioInputModeRawValue: String? {
        get { string(forKey: Keys.audioInputMode) }
        set { setValue(newValue, forKey: Keys.audioInputMode) }
    }

    // MARK: - Selected Audio Device UID
    var selectedAudioDeviceUID: String? {
        get { string(forKey: Keys.selectedAudioDeviceUID) }
        set { setValue(newValue, forKey: Keys.selectedAudioDeviceUID) }
    }

    // MARK: - Prioritized Devices
    var prioritizedDevicesData: Data? {
        get { data(forKey: Keys.prioritizedDevices) }
        set { setValue(newValue, forKey: Keys.prioritizedDevices) }
    }
} 
