import Foundation
import Security
import os

struct CloudAPIKeyEntry: Identifiable, Codable, Equatable {
    let id: UUID
    var value: String
    var lastUsedAt: Date?
    
    init(id: UUID = UUID(), value: String, lastUsedAt: Date? = nil) {
        self.id = id
        self.value = value
        self.lastUsedAt = lastUsedAt
    }
}

final class CloudAPIKeyManager {
    static let shared = CloudAPIKeyManager()
    
    private let userDefaults = UserDefaults.hoah
    private let logger = Logger(subsystem: "com.yangzichao.hoah", category: "CloudAPIKeyManager")
    private let keysStorageKey = "CloudAPIKeysByProvider"
    private let activeIdsStorageKey = "CloudActiveAPIKeyIdsByProvider"
    private let keychainAccountPrefix = "com.yangzichao.hoah.cloudapikey"
    private let keychainService = "com.yangzichao.hoah"
    private let legacyProviders = [
        "GROQ",
        "ElevenLabs",
        "Gemini",
        "Anthropic",
        "OpenAI",
        "OpenRouter",
        "Cerebras",
        "AWS Bedrock"
    ]
    
    private var keysByProvider: [String: [CloudAPIKeyEntry]]
    private var activeIdByProvider: [String: UUID]
    
    private struct PersistedEntry: Codable {
        let id: UUID
        var lastUsedAt: Date?
    }
    
    private init() {
        keysByProvider = [:]
        activeIdByProvider = [:]
        
        if let stored = userDefaults.dictionary(forKey: activeIdsStorageKey) as? [String: String] {
            var result: [String: UUID] = [:]
            for (providerKey, idString) in stored {
                if let uuid = UUID(uuidString: idString) {
                    result[providerKey] = uuid
                }
            }
            activeIdByProvider = result
        } else {
            activeIdByProvider = [:]
        }
        
        keysByProvider = loadKeysFromStorage()
        migrateLegacySingleKeysIfNeeded()
    }
    
    // MARK: - Public API
    
    func keys(for providerKey: String) -> [CloudAPIKeyEntry] {
        hydratedEntries(for: providerKey)
    }
    
    func hasKeys(for providerKey: String) -> Bool {
        !hydratedEntries(for: providerKey).isEmpty
    }
    
    func activeKey(for providerKey: String) -> CloudAPIKeyEntry? {
        let keys = hydratedEntries(for: providerKey)
        guard !keys.isEmpty else { return nil }
        
        if let activeId = activeIdByProvider[providerKey],
           let entry = keys.first(where: { $0.id == activeId }) {
            return entry
        }
        return keys.first
    }
    
    func activeKeyId(for providerKey: String) -> UUID? {
        activeKey(for: providerKey)?.id
    }
    
    @discardableResult
    func addKey(_ value: String, for providerKey: String) -> CloudAPIKeyEntry? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            logger.error("Rejected empty API key for provider: \(providerKey, privacy: .public)")
            return nil
        }
        
        var keys = hydratedEntries(for: providerKey)
        
        if let existing = keys.first(where: { $0.value == trimmed }) {
            guard setKeychainValue(trimmed, for: providerKey, id: existing.id) else {
                logger.error("Failed to persist existing API key for provider: \(providerKey, privacy: .public)")
                return nil
            }
            activeIdByProvider[providerKey] = existing.id
            persist(for: providerKey)
            return existing
        }
        
        let entry = CloudAPIKeyEntry(value: trimmed)
        guard setKeychainValue(trimmed, for: providerKey, id: entry.id) else {
            logger.error("Failed to persist new API key for provider: \(providerKey, privacy: .public)")
            return nil
        }
        keys.append(entry)
        keysByProvider[providerKey] = keys
        activeIdByProvider[providerKey] = entry.id
        
        persist(for: providerKey)
        NotificationCenter.default.post(name: .aiProviderKeyChanged, object: nil)
        return entry
    }
    
    func selectKey(id: UUID, for providerKey: String) {
        let keys = hydratedEntries(for: providerKey)
        guard !keys.isEmpty,
              keys.contains(where: { $0.id == id }) else { return }
        activeIdByProvider[providerKey] = id
        persist(for: providerKey)
        NotificationCenter.default.post(name: .aiProviderKeyChanged, object: nil)
    }
    
    @discardableResult
    func rotateKey(for providerKey: String) -> Bool {
        let keys = hydratedEntries(for: providerKey)
        guard !keys.isEmpty else { return false }
        
        if keys.count == 1 {
            // Only one key, nothing to rotate but treat as success so caller does not fail prematurely
            if let current = activeKey(for: providerKey) {
                activeIdByProvider[providerKey] = current.id
                persist(for: providerKey)
                NotificationCenter.default.post(name: .aiProviderKeyChanged, object: nil)
                return true
            }
            return false
        }
        
        let currentId = activeIdByProvider[providerKey]
        let currentIndex = keys.firstIndex(where: { $0.id == currentId }) ?? 0
        let nextIndex = (currentIndex + 1) % keys.count
        let next = keys[nextIndex]
        activeIdByProvider[providerKey] = next.id
        persist(for: providerKey)
        NotificationCenter.default.post(name: .aiProviderKeyChanged, object: nil)
        return true
    }
    
    func markCurrentKeyUsed(for providerKey: String) {
        var keys = hydratedEntries(for: providerKey)
        guard !keys.isEmpty else { return }
        
        let now = Date()
        if let activeId = activeIdByProvider[providerKey],
           let index = keys.firstIndex(where: { $0.id == activeId }) {
            keys[index].lastUsedAt = now
            keysByProvider[providerKey] = keys
        } else {
            keys[0].lastUsedAt = now
            keysByProvider[providerKey] = keys
            activeIdByProvider[providerKey] = keys[0].id
        }
        persist(for: providerKey)
        NotificationCenter.default.post(name: .aiProviderKeyChanged, object: nil)
    }
    
    func removeKey(id: UUID, for providerKey: String) {
        var keys = hydratedEntries(for: providerKey)
        guard !keys.isEmpty else { return }
        keys.removeAll { $0.id == id }
        keysByProvider[providerKey] = keys
        deleteKeychainValue(for: providerKey, id: id)
        
        if keys.isEmpty {
            activeIdByProvider[providerKey] = nil
        } else if activeIdByProvider[providerKey] == id {
            activeIdByProvider[providerKey] = keys[0].id
        }
        
        persist(for: providerKey)
        NotificationCenter.default.post(name: .aiProviderKeyChanged, object: nil)
    }
    
    func removeAllKeys(for providerKey: String) {
        for entry in keysByProvider[providerKey] ?? [] {
            deleteKeychainValue(for: providerKey, id: entry.id)
        }
        keysByProvider[providerKey] = []
        activeIdByProvider[providerKey] = nil
        persist(for: providerKey)
        NotificationCenter.default.post(name: .aiProviderKeyChanged, object: nil)
    }
    
    // MARK: - Persistence and migration
    
    private func persist(for providerKey: String) {
        _ = providerKey // intentionally unused, preserved for call-site clarity
        let persisted = buildPersistedEntries(from: keysByProvider)
        if let data = try? JSONEncoder().encode(persisted) {
            userDefaults.set(data, forKey: keysStorageKey)
        }
        
        var storedIds: [String: String] = [:]
        for (provider, id) in activeIdByProvider {
            storedIds[provider] = id.uuidString
        }
        userDefaults.set(storedIds, forKey: activeIdsStorageKey)
    }
    
    private func loadKeysFromStorage() -> [String: [CloudAPIKeyEntry]] {
        guard let data = userDefaults.data(forKey: keysStorageKey) else {
            return [:]
        }
        
        if let legacy = try? JSONDecoder().decode([String: [CloudAPIKeyEntry]].self, from: data) {
            var migrated: [String: [CloudAPIKeyEntry]] = [:]
            for (providerKey, entries) in legacy {
                var restored: [CloudAPIKeyEntry] = []
                for entry in entries {
                    let trimmed = entry.value.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !trimmed.isEmpty else { continue }
                    guard setKeychainValue(trimmed, for: providerKey, id: entry.id) else {
                        logger.error("Failed to migrate legacy API key entry for provider: \(providerKey, privacy: .public)")
                        continue
                    }
                    restored.append(CloudAPIKeyEntry(id: entry.id, value: trimmed, lastUsedAt: entry.lastUsedAt))
                }
                if !restored.isEmpty {
                    migrated[providerKey] = restored
                }
            }
            let persisted = buildPersistedEntries(from: migrated)
            if let encoded = try? JSONEncoder().encode(persisted) {
                userDefaults.set(encoded, forKey: keysStorageKey)
            }
            return migrated
        }
        
        guard let persisted = try? JSONDecoder().decode([String: [PersistedEntry]].self, from: data) else {
            return [:]
        }
        
        var restored: [String: [CloudAPIKeyEntry]] = [:]
        for (providerKey, entries) in persisted {
            var hydrated: [CloudAPIKeyEntry] = []
            for entry in entries {
                guard let value = getKeychainValue(for: providerKey, id: entry.id) else { continue }
                hydrated.append(CloudAPIKeyEntry(id: entry.id, value: value, lastUsedAt: entry.lastUsedAt))
            }
            if !hydrated.isEmpty {
                restored[providerKey] = hydrated
            }
        }
        return restored
    }
    
    private func buildPersistedEntries(from source: [String: [CloudAPIKeyEntry]]) -> [String: [PersistedEntry]] {
        var persisted: [String: [PersistedEntry]] = [:]
        for (providerKey, entries) in source {
            let mapped = entries.map { PersistedEntry(id: $0.id, lastUsedAt: $0.lastUsedAt) }
            if !mapped.isEmpty {
                persisted[providerKey] = mapped
            }
        }
        return persisted
    }
    
    private func migrateLegacySingleKeysIfNeeded() {
        var didMigrate = false
        
        for providerKey in legacyProviders {
            let legacyKeyName = "\(providerKey)APIKey"
            
            if let entries = keysByProvider[providerKey], !entries.isEmpty {
                var changed = false
                for idx in entries.indices {
                    let trimmed = entries[idx].value.trimmingCharacters(in: .whitespacesAndNewlines)
                    if trimmed.isEmpty { continue }
                    if getKeychainValue(for: providerKey, id: entries[idx].id) != trimmed {
                        if setKeychainValue(trimmed, for: providerKey, id: entries[idx].id) {
                            changed = true
                        } else {
                            logger.error("Failed to backfill keychain during migration for provider: \(providerKey, privacy: .public)")
                        }
                    }
                }
                if changed {
                    keysByProvider[providerKey] = entries
                    didMigrate = true
                }
                userDefaults.removeObject(forKey: legacyKeyName)
                continue
            }
            
            if let legacy = userDefaults.string(forKey: legacyKeyName),
               !legacy.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                let entry = CloudAPIKeyEntry(value: legacy)
                if setKeychainValue(entry.value, for: providerKey, id: entry.id) {
                    keysByProvider[providerKey] = [entry]
                    activeIdByProvider[providerKey] = entry.id
                    didMigrate = true
                } else {
                    logger.error("Failed to migrate legacy API key for provider: \(providerKey, privacy: .public)")
                }
                userDefaults.removeObject(forKey: legacyKeyName)
            }
        }
        
        if didMigrate {
            persistAll()
        }
    }
    
    private func keychainAccount(for providerKey: String, id: UUID) -> String {
        "\(keychainAccountPrefix).\(providerKey).\(id.uuidString)"
    }
    
    private func getKeychainValue(for providerKey: String, id: UUID) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: keychainAccount(for: providerKey, id: id),
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess,
              let data = result as? Data,
              let value = String(data: data, encoding: .utf8),
              !value.isEmpty else {
            if status == errSecItemNotFound {
                return migrateLegacyKeychainValueIfNeeded(for: providerKey, id: id)
            }
            if status != errSecItemNotFound {
                logger.error("Keychain read failed for provider \(providerKey, privacy: .public), status=\(status)")
            }
            return nil
        }
        return value
    }
    
    @discardableResult
    private func setKeychainValue(_ value: String, for providerKey: String, id: UUID) -> Bool {
        guard let data = value.data(using: .utf8) else { return false }
        let baseQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: keychainAccount(for: providerKey, id: id)
        ]
        
        let updateAttrs: [String: Any] = [
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlocked
        ]
        let updateStatus = SecItemUpdate(baseQuery as CFDictionary, updateAttrs as CFDictionary)
        if updateStatus == errSecSuccess {
            return true
        }
        if updateStatus != errSecItemNotFound {
            logger.error("Keychain update failed for provider \(providerKey, privacy: .public), status=\(updateStatus)")
            return false
        }
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: keychainAccount(for: providerKey, id: id),
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlocked
        ]
        
        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            logger.error("Keychain write failed for provider \(providerKey, privacy: .public), status=\(status)")
            return false
        }
        return true
    }
    
    private func deleteKeychainValue(for providerKey: String, id: UUID) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: keychainAccount(for: providerKey, id: id)
        ]
        SecItemDelete(query as CFDictionary)
        
        let legacyQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: keychainAccount(for: providerKey, id: id)
        ]
        SecItemDelete(legacyQuery as CFDictionary)
    }

    private func hydratedEntries(for providerKey: String) -> [CloudAPIKeyEntry] {
        let existing = keysByProvider[providerKey] ?? []
        guard !existing.isEmpty else { return [] }
        
        var hydrated: [CloudAPIKeyEntry] = []
        hydrated.reserveCapacity(existing.count)
        
        for entry in existing {
            guard let value = getKeychainValue(for: providerKey, id: entry.id) else { continue }
            hydrated.append(CloudAPIKeyEntry(id: entry.id, value: value, lastUsedAt: entry.lastUsedAt))
        }
        
        if hydrated != existing {
            keysByProvider[providerKey] = hydrated
            if let activeId = activeIdByProvider[providerKey],
               !hydrated.contains(where: { $0.id == activeId }) {
                activeIdByProvider[providerKey] = hydrated.first?.id
            } else if hydrated.isEmpty {
                activeIdByProvider[providerKey] = nil
            }
            persist(for: providerKey)
        }
        
        return hydrated
    }

    private func migrateLegacyKeychainValueIfNeeded(for providerKey: String, id: UUID) -> String? {
        let legacyQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: keychainAccount(for: providerKey, id: id),
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var result: AnyObject?
        let legacyStatus = SecItemCopyMatching(legacyQuery as CFDictionary, &result)
        guard legacyStatus == errSecSuccess,
              let data = result as? Data,
              let value = String(data: data, encoding: .utf8),
              !value.isEmpty else {
            return nil
        }
        
        if setKeychainValue(value, for: providerKey, id: id) {
            SecItemDelete(legacyQuery as CFDictionary)
        } else {
            logger.error("Failed to migrate legacy keychain item for provider: \(providerKey, privacy: .public)")
        }
        return value
    }
    
    private func persistAll() {
        let persisted = buildPersistedEntries(from: keysByProvider)
        if let data = try? JSONEncoder().encode(persisted) {
            userDefaults.set(data, forKey: keysStorageKey)
        }
        
        var storedIds: [String: String] = [:]
        for (provider, id) in activeIdByProvider {
            storedIds[provider] = id.uuidString
        }
        userDefaults.set(storedIds, forKey: activeIdsStorageKey)
    }
}
