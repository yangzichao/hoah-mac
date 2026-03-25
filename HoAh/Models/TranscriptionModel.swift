import Foundation
import Security

// Enum to differentiate between model providers
enum ModelProvider: String, Codable, Hashable, CaseIterable {
    case local = "Local"
    case groq = "Groq"
    case elevenLabs = "ElevenLabs"
    case openAI = "OpenAI"
    case amazonTranscribe = "Amazon Transcribe"
    case custom = "Custom"
    case nativeApple = "Native Apple"
    // Future providers can be added here
}

// A unified protocol for any transcription model
protocol TranscriptionModel: Identifiable, Hashable {
    var id: UUID { get }
    var name: String { get }
    var displayName: String { get }
    var description: String { get }
    var provider: ModelProvider { get }
    
    // Language capabilities
    var isMultilingualModel: Bool { get }
    var supportedLanguages: [String: String] { get }
}

extension TranscriptionModel {
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    var language: String {
        isMultilingualModel ? String(localized: "Multilingual") : String(localized: "English-only")
    }

    var usesRealtimeStreaming: Bool {
        switch provider {
        case .openAI, .amazonTranscribe:
            return true
        case .elevenLabs:
            return name == "scribe_v2"
        default:
            return false
        }
    }

    var isCloudBatchModel: Bool {
        switch provider {
        case .groq:
            return true
        case .elevenLabs:
            return name == "scribe_v2_batch"
        default:
            return false
        }
    }
}

// A new struct for Apple's native models
struct NativeAppleModel: TranscriptionModel {
    let id = UUID()
    let name: String
    let displayName: String
    let description: String
    let provider: ModelProvider = .nativeApple
    let isMultilingualModel: Bool
    let supportedLanguages: [String: String]
}

// A new struct for cloud models
struct CloudModel: TranscriptionModel {
    let id: UUID
    let name: String
    let displayName: String
    let description: String
    let provider: ModelProvider
    let speed: Double
    let accuracy: Double
    let isMultilingualModel: Bool
    let supportedLanguages: [String: String]

    init(id: UUID = UUID(), name: String, displayName: String, description: String, provider: ModelProvider, speed: Double, accuracy: Double, isMultilingual: Bool, supportedLanguages: [String: String]) {
        self.id = id
        self.name = name
        self.displayName = displayName
        self.description = description
        self.provider = provider
        self.speed = speed
        self.accuracy = accuracy
        self.isMultilingualModel = isMultilingual
        self.supportedLanguages = supportedLanguages
    }
}

// A new struct for custom cloud models
struct CustomCloudModel: TranscriptionModel, Codable {
    let id: UUID
    let name: String
    let displayName: String
    let description: String
    let apiEndpoint: String
    let modelName: String
    let isMultilingualModel: Bool
    let supportedLanguages: [String: String]
    
    var provider: ModelProvider { .custom }
    var hasApiKey: Bool { getApiKey() != nil }
    
    /// Convenience accessor used by existing call sites.
    var apiKey: String {
        getApiKey() ?? ""
    }
    
    private var keychainKey: String {
        "com.yangzichao.hoah.custommodel.\(id.uuidString)"
    }
    
    private var keychainService: String {
        "com.yangzichao.hoah"
    }

    init(id: UUID = UUID(), name: String, displayName: String, description: String, apiEndpoint: String, apiKey: String, modelName: String, isMultilingual: Bool = true, supportedLanguages: [String: String]? = nil) {
        self.id = id
        self.name = name
        self.displayName = displayName
        self.description = description
        self.apiEndpoint = apiEndpoint
        self.modelName = modelName
        self.isMultilingualModel = isMultilingual
        self.supportedLanguages = supportedLanguages ?? PredefinedModels.getLanguageDictionary(isMultilingual: isMultilingual)
        if !apiKey.isEmpty {
            self.setApiKey(apiKey)
        }
    }
    
    enum CodingKeys: String, CodingKey {
        case id, name, displayName, description, apiEndpoint, modelName, isMultilingualModel, supportedLanguages
        case hasApiKey
        // Legacy plaintext key for migration only.
        case apiKey
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(UUID.self, forKey: .id)
        self.name = try container.decode(String.self, forKey: .name)
        self.displayName = try container.decode(String.self, forKey: .displayName)
        self.description = try container.decode(String.self, forKey: .description)
        self.apiEndpoint = try container.decode(String.self, forKey: .apiEndpoint)
        self.modelName = try container.decode(String.self, forKey: .modelName)
        self.isMultilingualModel = try container.decode(Bool.self, forKey: .isMultilingualModel)
        self.supportedLanguages = try container.decode([String: String].self, forKey: .supportedLanguages)
        // Backward compatibility: old payloads may include hasApiKey.
        _ = try container.decodeIfPresent(Bool.self, forKey: .hasApiKey)
        
        if let legacyApiKey = try container.decodeIfPresent(String.self, forKey: .apiKey),
           !legacyApiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            self.setApiKey(legacyApiKey)
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(displayName, forKey: .displayName)
        try container.encode(description, forKey: .description)
        try container.encode(apiEndpoint, forKey: .apiEndpoint)
        try container.encode(modelName, forKey: .modelName)
        try container.encode(isMultilingualModel, forKey: .isMultilingualModel)
        try container.encode(supportedLanguages, forKey: .supportedLanguages)
        try container.encode(hasApiKey, forKey: .hasApiKey)
    }
    
    func getApiKey() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: keychainKey,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess,
              let data = result as? Data,
              let key = String(data: data, encoding: .utf8),
              !key.isEmpty else {
            if status == errSecItemNotFound {
                return migrateLegacyKeychainValueIfNeeded()
            }
            return nil
        }
        
        let trimmedKey = key.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedKey.isEmpty {
            return nil
        }
        if trimmedKey != key {
            setApiKey(trimmedKey)
        }
        return trimmedKey
    }
    
    func setApiKey(_ key: String) {
        let trimmedKey = key.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedKey.isEmpty else {
            deleteApiKey()
            return
        }
        
        guard let data = trimmedKey.data(using: .utf8) else { return }
        let baseQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: keychainKey
        ]
        
        let updateAttrs: [String: Any] = [
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlocked
        ]
        let updateStatus = SecItemUpdate(baseQuery as CFDictionary, updateAttrs as CFDictionary)
        if updateStatus == errSecSuccess {
            return
        }
        if updateStatus != errSecItemNotFound {
            return
        }
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: keychainKey,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlocked
        ]
        
        _ = SecItemAdd(query as CFDictionary, nil)
    }
    
    func deleteApiKey() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: keychainKey
        ]
        SecItemDelete(query as CFDictionary)
        
        let legacyQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: keychainKey
        ]
        SecItemDelete(legacyQuery as CFDictionary)
    }
    
    private func migrateLegacyKeychainValueIfNeeded() -> String? {
        let legacyQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: keychainKey,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(legacyQuery as CFDictionary, &result)
        guard status == errSecSuccess,
              let data = result as? Data,
              let key = String(data: data, encoding: .utf8),
              !key.isEmpty else {
            return nil
        }
        
        setApiKey(key)
        SecItemDelete(legacyQuery as CFDictionary)
        return key
    }
} 

struct LocalModel: TranscriptionModel {
    let id = UUID()
    let name: String
    let displayName: String
    let size: String
    let supportedLanguages: [String: String]
    let description: String
    let speed: Double
    let accuracy: Double
    let ramUsage: Double
    let provider: ModelProvider = .local

    var downloadURL: String {
        "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/\(filename)"
    }

    var downloadURLCandidates: [String] {
        var urls: [String] = [
            downloadURL,
            downloadURL.replacingOccurrences(of: "https://huggingface.co/", with: "https://hf-mirror.com/")
        ]

        // Mainland-friendly fallback for non-turbo official ggml artifacts.
        if name == "ggml-base" || name == "ggml-large-v3" {
            urls.append("https://mirrors.aliyun.com/macports/distfiles/whisper/\(filename)")
        }

        // Fallback where upstream file is named ggml-model.bin; we still store as model.filename.
        if name == "ggml-large-v3-turbo" {
            urls.append("https://www.modelscope.cn/models/ivrit-ai/yi-whisper-large-v3-turbo-ggml/resolve/master/ggml-model.bin")
        }

        // Extra fallback for quantized turbo variant.
        if name == "ggml-large-v3-turbo-q5_0" {
            urls.append("https://hf-mirror.com/NHQTools/whisper-models/resolve/main/ggml-large-v3-turbo-q5_0.bin")
        }

        var seen = Set<String>()
        return urls.filter { seen.insert($0).inserted }
    }

    var filename: String {
        "\(name).bin"
    }

    var isMultilingualModel: Bool {
        supportedLanguages.count > 1
    }
} 
