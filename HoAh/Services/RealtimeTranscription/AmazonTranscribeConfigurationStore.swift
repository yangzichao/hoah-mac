import Foundation
import Security

struct AmazonTranscribeLanguageOption: Identifiable, Hashable {
    let code: String
    let name: String

    var id: String { code }
}

struct AmazonTranscribeConfiguration: Codable, Equatable {
    enum AuthMethod: String, Codable, CaseIterable {
        case profile
        case accessKey
    }

    var region: String
    var authMethod: AuthMethod
    var profileName: String
    var accessKeyId: String
    var sessionToken: String
    var preferredLanguageCodes: [String]

    static let `default` = AmazonTranscribeConfiguration(
        region: "us-west-2",
        authMethod: .profile,
        profileName: "",
        accessKeyId: "",
        sessionToken: "",
        preferredLanguageCodes: AmazonTranscribeConfigurationStore.defaultPreferredLanguageCodes
    )

    init(
        region: String,
        authMethod: AuthMethod,
        profileName: String,
        accessKeyId: String,
        sessionToken: String,
        preferredLanguageCodes: [String]
    ) {
        self.region = region
        self.authMethod = authMethod
        self.profileName = profileName
        self.accessKeyId = accessKeyId
        self.sessionToken = sessionToken
        self.preferredLanguageCodes = AmazonTranscribeConfigurationStore.normalizedPreferredLanguageCodes(preferredLanguageCodes)
    }

    enum CodingKeys: String, CodingKey {
        case region
        case authMethod
        case profileName
        case accessKeyId
        case sessionToken
        case preferredLanguageCodes
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        region = try container.decodeIfPresent(String.self, forKey: .region) ?? Self.default.region
        authMethod = try container.decodeIfPresent(AuthMethod.self, forKey: .authMethod) ?? Self.default.authMethod
        profileName = try container.decodeIfPresent(String.self, forKey: .profileName) ?? Self.default.profileName
        accessKeyId = try container.decodeIfPresent(String.self, forKey: .accessKeyId) ?? Self.default.accessKeyId
        sessionToken = try container.decodeIfPresent(String.self, forKey: .sessionToken) ?? Self.default.sessionToken
        preferredLanguageCodes = AmazonTranscribeConfigurationStore.normalizedPreferredLanguageCodes(
            try container.decodeIfPresent([String].self, forKey: .preferredLanguageCodes)
                ?? Self.default.preferredLanguageCodes
        )
    }
}

enum AmazonTranscribeConfigurationError: LocalizedError {
    case missingRegion
    case missingProfile
    case missingAccessKeyID
    case missingSecretAccessKey
    case credentialResolutionFailed(String)

    var errorDescription: String? {
        switch self {
        case .missingRegion:
            return "AWS region is required for Amazon Transcribe."
        case .missingProfile:
            return "AWS profile name is required for Amazon Transcribe."
        case .missingAccessKeyID:
            return "AWS access key ID is required for Amazon Transcribe."
        case .missingSecretAccessKey:
            return "AWS secret access key is required for Amazon Transcribe."
        case .credentialResolutionFailed(let message):
            return message
        }
    }
}

final class AmazonTranscribeConfigurationStore {
    static let shared = AmazonTranscribeConfigurationStore()
    static let maxPreferredLanguageCount = 5
    static let supportedRegions = [
        "us-east-1",
        "us-east-2",
        "us-west-2",
        "ca-central-1",
        "eu-west-1",
        "eu-west-2",
        "eu-central-1",
        "ap-northeast-1",
        "ap-northeast-2",
        "ap-southeast-1",
        "ap-southeast-2",
        "ap-south-1",
        "sa-east-1"
    ]
    static let supportedLanguageOptions: [AmazonTranscribeLanguageOption] = [
        .init(code: "en-US", name: "English (United States)"),
        .init(code: "en-GB", name: "English (United Kingdom)"),
        .init(code: "es-US", name: "Spanish (United States)"),
        .init(code: "fr-CA", name: "French (Canada)"),
        .init(code: "fr-FR", name: "French (France)"),
        .init(code: "en-AU", name: "English (Australia)"),
        .init(code: "it-IT", name: "Italian"),
        .init(code: "de-DE", name: "German"),
        .init(code: "pt-BR", name: "Portuguese (Brazil)"),
        .init(code: "ja-JP", name: "Japanese"),
        .init(code: "ko-KR", name: "Korean"),
        .init(code: "zh-CN", name: "Chinese (Simplified)"),
        .init(code: "th-TH", name: "Thai"),
        .init(code: "es-ES", name: "Spanish (Spain)"),
        .init(code: "ar-SA", name: "Arabic (Saudi Arabia)"),
        .init(code: "pt-PT", name: "Portuguese (Portugal)"),
        .init(code: "ca-ES", name: "Catalan"),
        .init(code: "ar-AE", name: "Arabic (UAE)"),
        .init(code: "hi-IN", name: "Hindi"),
        .init(code: "zh-HK", name: "Chinese (Hong Kong)"),
        .init(code: "nl-NL", name: "Dutch"),
        .init(code: "no-NO", name: "Norwegian"),
        .init(code: "sv-SE", name: "Swedish"),
        .init(code: "pl-PL", name: "Polish"),
        .init(code: "fi-FI", name: "Finnish"),
        .init(code: "zh-TW", name: "Chinese (Traditional)"),
        .init(code: "en-IN", name: "English (India)"),
        .init(code: "en-IE", name: "English (Ireland)"),
        .init(code: "en-NZ", name: "English (New Zealand)"),
        .init(code: "en-AB", name: "English (Scotland)"),
        .init(code: "en-ZA", name: "English (South Africa)"),
        .init(code: "en-WL", name: "English (Wales)"),
        .init(code: "de-CH", name: "German (Switzerland)"),
        .init(code: "af-ZA", name: "Afrikaans"),
        .init(code: "eu-ES", name: "Basque"),
        .init(code: "hr-HR", name: "Croatian"),
        .init(code: "cs-CZ", name: "Czech"),
        .init(code: "da-DK", name: "Danish"),
        .init(code: "fa-IR", name: "Persian"),
        .init(code: "gl-ES", name: "Galician"),
        .init(code: "el-GR", name: "Greek"),
        .init(code: "he-IL", name: "Hebrew"),
        .init(code: "id-ID", name: "Indonesian"),
        .init(code: "lv-LV", name: "Latvian"),
        .init(code: "ms-MY", name: "Malay"),
        .init(code: "ro-RO", name: "Romanian"),
        .init(code: "ru-RU", name: "Russian"),
        .init(code: "sr-RS", name: "Serbian"),
        .init(code: "sk-SK", name: "Slovak"),
        .init(code: "so-SO", name: "Somali"),
        .init(code: "tl-PH", name: "Filipino"),
        .init(code: "uk-UA", name: "Ukrainian"),
        .init(code: "vi-VN", name: "Vietnamese"),
        .init(code: "zu-ZA", name: "Zulu")
    ]
    static let defaultPreferredLanguageCodes = [
        "en-US",
        "zh-CN",
        "ja-JP",
        "ko-KR",
        "fr-FR"
    ]

    static func normalizedPreferredLanguageCodes(_ codes: [String]) -> [String] {
        let allowedCodes = Set(supportedLanguageOptions.map(\.code))
        var normalized: [String] = []

        for code in codes {
            guard allowedCodes.contains(code), !normalized.contains(code) else { continue }
            normalized.append(code)
            if normalized.count == maxPreferredLanguageCount {
                break
            }
        }

        return normalized
    }

    static func displayName(for languageCode: String) -> String {
        supportedLanguageOptions.first(where: { $0.code == languageCode })?.name ?? languageCode
    }

    private let userDefaults = UserDefaults.hoah
    private let storageKey = "AmazonTranscribeConfiguration"
    private let keychainService = "com.yangzichao.hoah"
    private let secretAccount = "com.yangzichao.hoah.amazontranscribe.secret"
    private let awsProfileService = AWSProfileService()

    private init() {}

    func load() -> AmazonTranscribeConfiguration {
        guard let data = userDefaults.data(forKey: storageKey),
              let config = try? JSONDecoder().decode(AmazonTranscribeConfiguration.self, from: data) else {
            return .default
        }
        return config
    }

    func save(_ configuration: AmazonTranscribeConfiguration, secretAccessKey: String?) {
        var normalized = configuration
        normalized.preferredLanguageCodes = Self.normalizedPreferredLanguageCodes(configuration.preferredLanguageCodes)

        if let data = try? JSONEncoder().encode(normalized) {
            userDefaults.set(data, forKey: storageKey)
        }

        if normalized.authMethod == .accessKey {
            setSecretAccessKey(secretAccessKey ?? "")
        } else {
            deleteSecretAccessKey()
        }
    }

    func clear() {
        userDefaults.removeObject(forKey: storageKey)
        deleteSecretAccessKey()
    }

    func secretAccessKey() -> String {
        guard let data = readKeychainValue(),
              let value = String(data: data, encoding: .utf8) else {
            return ""
        }
        return value
    }

    func isConfigured() -> Bool {
        let configuration = load()
        let region = configuration.region.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !region.isEmpty else { return false }

        switch configuration.authMethod {
        case .profile:
            return effectiveProfileName(for: configuration) != nil
        case .accessKey:
            return !configuration.accessKeyId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
                !secretAccessKey().trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
    }

    func availableProfiles() -> [String] {
        awsProfileService.listProfiles()
    }

    func preferredProfileName() -> String? {
        let profiles = availableProfiles()
        guard !profiles.isEmpty else { return nil }

        if profiles.contains("default") {
            return "default"
        }

        return profiles.first
    }

    func effectiveProfileName(for configuration: AmazonTranscribeConfiguration? = nil) -> String? {
        let resolvedConfiguration = configuration ?? load()
        let configuredProfile = resolvedConfiguration.profileName.trimmingCharacters(in: .whitespacesAndNewlines)
        if !configuredProfile.isEmpty {
            return configuredProfile
        }

        return preferredProfileName()
    }

    func effectivePreferredLanguageCodes(for configuration: AmazonTranscribeConfiguration? = nil) -> [String] {
        let resolved = configuration ?? load()
        let normalized = Self.normalizedPreferredLanguageCodes(resolved.preferredLanguageCodes)
        return normalized.isEmpty ? Self.defaultPreferredLanguageCodes : normalized
    }

    func resolveCredentials() async throws -> (credentials: AWSCredentials, region: String) {
        let configuration = load()
        let region = configuration.region.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !region.isEmpty else {
            throw AmazonTranscribeConfigurationError.missingRegion
        }

        switch configuration.authMethod {
        case .profile:
            guard let profile = effectiveProfileName(for: configuration) else {
                throw AmazonTranscribeConfigurationError.missingProfile
            }

            do {
                let credentials = try await awsProfileService.resolveFreshCredentials(for: profile)
                let resolvedRegion = credentials.region?.trimmingCharacters(in: .whitespacesAndNewlines)
                return (credentials, resolvedRegion?.isEmpty == false ? resolvedRegion! : region)
            } catch {
                throw AmazonTranscribeConfigurationError.credentialResolutionFailed(
                    (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
                )
            }

        case .accessKey:
            let accessKeyID = configuration.accessKeyId.trimmingCharacters(in: .whitespacesAndNewlines)
            let secret = secretAccessKey().trimmingCharacters(in: .whitespacesAndNewlines)
            let sessionToken = configuration.sessionToken.trimmingCharacters(in: .whitespacesAndNewlines)

            guard !accessKeyID.isEmpty else {
                throw AmazonTranscribeConfigurationError.missingAccessKeyID
            }
            guard !secret.isEmpty else {
                throw AmazonTranscribeConfigurationError.missingSecretAccessKey
            }

            return (
                AWSCredentials(
                    accessKeyId: accessKeyID,
                    secretAccessKey: secret,
                    sessionToken: sessionToken.isEmpty ? nil : sessionToken,
                    region: region,
                    expiration: nil,
                    profileName: nil
                ),
                region
            )
        }
    }

    private func setSecretAccessKey(_ value: String) {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmed.isEmpty, let data = trimmed.data(using: .utf8) else {
            deleteSecretAccessKey()
            return
        }

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: secretAccount
        ]

        let attributes: [String: Any] = [
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlocked
        ]

        let updateStatus = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        if updateStatus == errSecSuccess {
            return
        }

        if updateStatus == errSecItemNotFound {
            var insert = query
            insert[kSecValueData as String] = data
            insert[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlocked
            SecItemAdd(insert as CFDictionary, nil)
        }
    }

    private func deleteSecretAccessKey() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: secretAccount
        ]
        SecItemDelete(query as CFDictionary)
    }

    private func readKeychainValue() -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: secretAccount,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess else { return nil }
        return result as? Data
    }
}
