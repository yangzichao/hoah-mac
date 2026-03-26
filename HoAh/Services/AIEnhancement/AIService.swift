import Foundation
import Combine

// AIProvider enum contains only AI enhancement providers (for post-processing transcribed text).
// Transcription-only providers (ElevenLabs, Soniox) are managed separately in WhisperState.
enum AIProvider: String, CaseIterable {
    case awsBedrock = "AWS Bedrock"
    case cerebras = "Cerebras"
    case groq = "GROQ"
    case gemini = "Gemini"
    case anthropic = "Anthropic"
    case openAI = "OpenAI"
    case azureOpenAI = "Azure OpenAI"
    case openRouter = "OpenRouter"
    case ociGenerativeAI = "OCI Generative AI"
    // Local provider (Ollama)
    case ollama = "Ollama (Local)"
    // Chinese provider (only shown when interface language is Chinese)
    case doubao = "字节豆包"
    
    
    var baseURL: String {
        switch self {
        case .ociGenerativeAI:
            return Self.ociEndpoint(for: "us-chicago-1")
        case .cerebras:
            return "https://api.cerebras.ai/v1/chat/completions"
        case .groq:
            return "https://api.groq.com/openai/v1/chat/completions"
        case .gemini:
            return "https://generativelanguage.googleapis.com/v1beta/openai/chat/completions"
        case .anthropic:
            return "https://api.anthropic.com/v1/messages"
        case .openAI:
            return "https://api.openai.com/v1/chat/completions"
        case .azureOpenAI:
            return "https://example.openai.azure.com/openai/v1/chat/completions"
        case .openRouter:
            return "https://openrouter.ai/api/v1/chat/completions"
        case .awsBedrock:
            let region = UserDefaults.hoah.string(forKey: "AWSBedrockRegion") ?? "us-east-1"
            return "https://bedrock-runtime.\(region).amazonaws.com"
        case .ollama:
            return "http://localhost:11434/v1/chat/completions"
        case .doubao:
            return "https://ark.cn-beijing.volces.com/api/v3/chat/completions"
        }
    }

    var defaultModel: String {
        switch self {
        case .ociGenerativeAI:
            return "openai.gpt-oss-20b"
        case .cerebras:
            return "llama3.1-8b"
        case .groq:
            return "llama-3.1-8b-instant"
        case .gemini:
            return "gemini-2.5-flash-lite"
        case .anthropic:
            return "claude-haiku-4-5"
        case .openAI:
            return "gpt-5.4-mini"
        case .azureOpenAI:
            // Azure uses deployment names, but many users name the deployment after the model.
            return "gpt-4.1"
        case .openRouter:
            return "openai/gpt-4.1-mini"
        case .awsBedrock:
            let fallback = "us.anthropic.claude-haiku-4-5-20251001-v1:0"
            if let saved = UserDefaults.hoah.string(forKey: "AWSBedrockModelId"),
               !saved.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return saved
            }
            return fallback
        case .ollama:
            return "qwen2.5:1.5b"
        case .doubao:
            return "doubao-seed-1-6-flash-250828"
        }
    }

    var availableModels: [String] {
        switch self {
        case .ociGenerativeAI:
            return [
                "openai.gpt-oss-20b",
                "openai.gpt-oss-120b",
                "meta.llama-4-scout-17b-16e-instruct",
                "google.gemini-2.5-flash-lite"
            ]
        case .cerebras:
            // Keep faster options first for short AI enhancement passes.
            return [
                "llama3.1-8b",
                "gpt-oss-120b",
                "qwen-3-235b-a22b-instruct-2507",
                "zai-glm-4.7"
            ]
        case .groq:
            // Keep low-latency models near the top for AI actions.
            return [
                "llama-3.1-8b-instant",
                "moonshotai/kimi-k2-instruct-0905",
                "llama-3.3-70b-versatile",
                "meta-llama/llama-4-scout-17b-16e-instruct",
                "openai/gpt-oss-20b",
                "qwen/qwen3-32b",
                "openai/gpt-oss-120b"
            ]
        case .gemini:
            // Prefer lower-latency Gemini models first for post-processing text.
            return [
                "gemini-2.5-flash-lite",
                "gemini-2.5-flash",
                "gemini-3.1-flash-lite-preview",
                "gemini-3-flash-preview",
                "gemini-2.5-pro",
                "gemini-3.1-pro-preview"
            ]
        case .anthropic:
            return [
                "claude-haiku-4-5",
                "claude-sonnet-4-5",
                "claude-opus-4-5"
            ]
        case .openAI:
            // Prefer low-latency GPT variants first for AI enhancement tasks.
            return [
                "gpt-5.4-mini",
                "gpt-5.4-nano",
                "gpt-4.1-mini",
                "gpt-5-mini",
                "gpt-5-nano",
                "gpt-5.4",
                "gpt-5.2",
                "gpt-5.1",
                "gpt-4.1"
            ]
        case .azureOpenAI:
            // Azure expects the deployment name here, which is user-defined.
            return []
        case .openRouter:
            // Curated OpenRouter defaults: fast, low-thinking text models first.
            return [
                "openai/gpt-4.1-mini",
                "google/gemini-2.5-flash-lite",
                "anthropic/claude-haiku-4.5",
                "openai/gpt-5.4-mini",
                "meta-llama/llama-3.1-8b-instruct",
                "qwen/qwen3-32b"
            ]
        case .awsBedrock:
            // Cross-region inference profile IDs (Haiku & Sonnet + OpenAI GPT-OSS)
            return [
                // Claude 4.5 (Haiku first as default)
                "us.anthropic.claude-haiku-4-5-20251001-v1:0",
                "us.anthropic.claude-sonnet-4-5-20250929-v1:0",
                // Claude 4
                "us.anthropic.claude-sonnet-4-20250514-v1:0",
                // Claude 3.7
                "us.anthropic.claude-3-7-sonnet-20250219-v1:0",
                // OpenAI GPT-OSS (text-only)
                "openai.gpt-oss-120b-1:0"
            ]
        case .ollama:
            // Recommended small models for AI Actions
            // User can also enter custom model names in the UI
            return [
                "qwen2.5:0.5b",
                "qwen2.5:1.5b",
                "qwen2.5:3b",
                "qwen2.5:7b",
                "llama3.2:1b",
                "llama3.2:3b",
                "gemma2:2b",
                "phi3:mini"
            ]
        case .doubao:
            // Curated candidate model IDs for Ark-compatible endpoint.
            return [
                "doubao-seed-1-6-flash-250828",
                "deepseek-v3-2-251201"
            ]
        }
    }

    var requiresAPIKey: Bool {
        switch self {
        case .ollama:
            return false  // Local provider, no API key needed
        default:
            return true
        }
    }
    
    /// URL to get API key for this provider
    var apiKeyURL: URL? {
        switch self {
        case .ociGenerativeAI:
            return URL(string: "https://cloud.oracle.com/identity/domains/my-profile/api-keys")
        case .awsBedrock:
            return URL(string: "https://console.aws.amazon.com/bedrock/")
        case .cerebras:
            return URL(string: "https://cloud.cerebras.ai/")
        case .groq:
            return URL(string: "https://console.groq.com/keys")
        case .gemini:
            return URL(string: "https://aistudio.google.com/apikey")
        case .anthropic:
            return URL(string: "https://console.anthropic.com/settings/keys")
        case .openAI:
            return URL(string: "https://platform.openai.com/api-keys")
        case .azureOpenAI:
            return URL(string: "https://ai.azure.com/")
        case .openRouter:
            return URL(string: "https://openrouter.ai/keys")
        case .ollama:
            return URL(string: "https://ollama.com/download")
        case .doubao:
            return URL(string: "https://console.volcengine.com/ark")
        }
    }

    /// Whether this provider is only available for Chinese interface
    var isChineseProvider: Bool {
        switch self {
        case .doubao:
            return true
        default:
            return false
        }
    }

    /// Whether this provider runs locally (no internet required)
    var isLocalProvider: Bool {
        switch self {
        case .ollama:
            return true
        default:
            return false
        }
    }

    /// Returns providers available for the given interface language
    static func providers(forLanguage languageCode: String) -> [AIProvider] {
        let language = AppLanguage(code: languageCode)
        switch language {
        case .simplifiedChinese:
            // Chinese users see all providers
            return allCases
        case .english, .system:
            // English/system users only see global providers
            return allCases.filter { !$0.isChineseProvider }
        }
    }

    static var supportedProviderNames: Set<String> {
        Set(allCases.map(\.rawValue))
    }

    var pickerDisplayName: String {
        switch self {
        case .groq:
            return "\(rawValue) (\(NSLocalizedString("Recommended", comment: "Short provider recommendation badge")))"
        default:
            return rawValue
        }
    }

    var requiresCustomEndpoint: Bool {
        switch self {
        case .azureOpenAI, .ociGenerativeAI:
            return true
        default:
            return false
        }
    }

    var usesAPIKeyHeader: Bool {
        switch self {
        case .azureOpenAI:
            return true
        default:
            return false
        }
    }

    func normalizedCustomEndpoint(_ endpoint: String?) -> String? {
        guard let endpoint else { return nil }
        let trimmed = endpoint.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        switch self {
        case .azureOpenAI:
            let chatSuffix = "/chat/completions"
            let openAIV1Suffix = "/openai/v1"
            var normalized = trimmed

            if normalized.hasSuffix("/") {
                normalized.removeLast()
            }
            if normalized.lowercased().hasSuffix(chatSuffix) {
                normalized.removeLast(chatSuffix.count)
            }
            if normalized.lowercased().hasSuffix(openAIV1Suffix) {
                return normalized
            }
            return "\(normalized)/openai/v1"

        case .ociGenerativeAI:
            let completionsSuffix = "/chat/completions"
            let baseSuffix = "/20231130/actions/v1"
            var normalized = trimmed

            if normalized.hasSuffix("/") {
                normalized.removeLast()
            }
            if normalized.lowercased().hasSuffix(completionsSuffix) {
                normalized.removeLast(completionsSuffix.count)
            }
            if normalized.lowercased().hasSuffix(baseSuffix) {
                return normalized
            }
            return "\(normalized)/20231130/actions/v1"

        case .ollama:
            let chatSuffix = "/v1/chat/completions"
            let apiSuffix = "/v1"
            var normalized = trimmed

            if normalized.hasSuffix("/") {
                normalized.removeLast()
            }
            if normalized.lowercased().hasSuffix(chatSuffix) {
                normalized.removeLast(chatSuffix.count)
            } else if normalized.lowercased().hasSuffix(apiSuffix) {
                normalized.removeLast(apiSuffix.count)
            }
            return normalized

        default:
            return trimmed
        }
    }

    func requestURL(customEndpoint: String?) -> String {
        switch self {
        case .azureOpenAI:
            if let endpoint = normalizedCustomEndpoint(customEndpoint) {
                return "\(endpoint)/chat/completions"
            }
            return baseURL
        case .ociGenerativeAI:
            if let endpoint = normalizedCustomEndpoint(customEndpoint) {
                return "\(endpoint)/chat/completions"
            }
            return baseURL
        case .ollama:
            if let endpoint = normalizedCustomEndpoint(customEndpoint) {
                return "\(endpoint)/v1/chat/completions"
            }
            return baseURL
        default:
            return baseURL
        }
    }

    static func ociEndpoint(for region: String) -> String {
        "https://inference.generativeai.\(region).oci.oraclecloud.com/20231130/actions/v1"
    }
}

enum DoubaoModelGroup: String, CaseIterable {
    case seedFlash
    case deepseekV3_2
    
    var displayName: String {
        switch self {
        case .seedFlash: return NSLocalizedString("Doubao Seed Flash (Auto)", comment: "Doubao model display name")
        case .deepseekV3_2: return NSLocalizedString("DeepSeek V3.2 (Auto)（更快，推荐）", comment: "Doubao model display name")
        }
    }
    
    var candidateModelIds: [String] {
        switch self {
        case .seedFlash:
            return [
                "doubao-seed-1-6-flash-250828"
            ]
        case .deepseekV3_2:
            return [
                "deepseek-v3-2-251201"
            ]
        }
    }
    
    static func infer(from modelId: String) -> DoubaoModelGroup {
        let lower = modelId.lowercased()
        if lower.contains("deepseek-v3-2") { return .deepseekV3_2 }
        return .seedFlash
    }
}

// AI Provider settings are managed by AppSettingsStore.
// Runtime state (apiKey, isAPIKeyValid) remains here.
// Note: request execution has already been split into provider-specific modules under
// Services/AIEnhancement/Providers, but provider metadata and configuration bridging
// still live here so the UI and migration paths share a single catalog during rollout.
@MainActor
class AIService: ObservableObject {
    @Published private(set) var apiKey: String = ""
    @Published var isAPIKeyValid: Bool = false
    
    // Reference to centralized settings store
    private weak var appSettings: AppSettingsStore?
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Active Configuration Support
    
    /// The currently active AI Enhancement configuration from AppSettingsStore
    var activeConfiguration: AIEnhancementConfiguration? {
        appSettings?.activeAIConfiguration
    }
    
    /// Whether to use the new configuration profile system
    /// Returns true if there's an active configuration, false to use legacy settings
    var useConfigurationProfiles: Bool {
        activeConfiguration != nil
    }
    
    // AWS Bedrock credentials/config - runtime state
    @Published var bedrockApiKey: String = ""
    
    /// AWS Bedrock region - reads from AppSettingsStore
    var bedrockRegion: String {
        get {
            if let config = activeConfiguration {
                return config.region ?? "us-east-1"
            }
            return appSettings?.bedrockRegion ?? "us-east-1"
        }
        set {
            guard activeConfiguration == nil else { return }
            objectWillChange.send()
            appSettings?.bedrockRegion = newValue
            
            // Legacy settings: keep model prefix aligned with region (cross-region inference profiles).
            if let currentModel = appSettings?.bedrockModelId {
                let normalized = AIService.bedrockNormalizedModelId(
                    currentModel,
                    region: newValue,
                    enableCrossRegion: true
                )
                if normalized != currentModel {
                    appSettings?.bedrockModelId = normalized
                }
            }
        }
    }
    
    /// AWS Bedrock model ID - reads from AppSettingsStore
    var bedrockModelId: String {
        get {
            if let config = activeConfiguration {
                return config.model
            }
            return appSettings?.bedrockModelId ?? "us.anthropic.claude-sonnet-4-5-20250929-v1:0"
        }
        set {
            guard activeConfiguration == nil else { return }
            objectWillChange.send()
            appSettings?.bedrockModelId = newValue
        }
    }

    // MARK: - Bedrock Model Helpers

    private static let bedrockCrossRegionPrefixes: Set<String> = ["us", "eu", "apac", "au", "jp", "global"]
    private static let bedrockAuRegions: Set<String> = ["ap-southeast-2", "ap-southeast-4"]
    private static let bedrockJpRegions: Set<String> = ["ap-northeast-1", "ap-northeast-3"]

    static func bedrockCrossRegionPrefix(for region: String, modelId: String) -> String {
        let lowercased = region.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if lowercased.hasPrefix("eu-") {
            return "eu"
        }
        if lowercased.hasPrefix("ap-") {
            if modelId.contains("-4-5-") || modelId.contains("claude-4-5") {
                if bedrockAuRegions.contains(lowercased) {
                    return "au"
                }
                if bedrockJpRegions.contains(lowercased) {
                    return "jp"
                }
                return "global"
            }
            return "apac"
        }
        return "us"
    }

    static func bedrockNormalizedModelId(_ modelId: String, region: String, enableCrossRegion: Bool) -> String {
        let trimmed = modelId.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return trimmed }

        // Only normalize Anthropic profile IDs to avoid breaking non-Anthropic model naming.
        let withoutPrefix = stripBedrockAnthropicPrefix(from: trimmed)

        if enableCrossRegion {
            if withoutPrefix.hasPrefix("anthropic.") {
                let prefix = bedrockCrossRegionPrefix(for: region, modelId: withoutPrefix)
                return "\(prefix).\(withoutPrefix)"
            }
            return trimmed
        }

        return withoutPrefix
    }

    static func bedrockNormalizedModels(_ models: [String], region: String, enableCrossRegion: Bool) -> [String] {
        var seen = Set<String>()
        var normalized: [String] = []
        normalized.reserveCapacity(models.count)
        for model in models {
            let value = bedrockNormalizedModelId(model, region: region, enableCrossRegion: enableCrossRegion)
            if !seen.contains(value) {
                normalized.append(value)
                seen.insert(value)
            }
        }
        return normalized
    }

    private static func stripBedrockAnthropicPrefix(from modelId: String) -> String {
        for prefix in bedrockCrossRegionPrefixes {
            let fullPrefix = "\(prefix).anthropic."
            if modelId.hasPrefix(fullPrefix) {
                return "anthropic." + modelId.dropFirst(fullPrefix.count)
            }
        }
        return modelId
    }
    
    /// Selected AI provider - reads from AppSettingsStore
    var selectedProvider: AIProvider {
        get {
            // Prefer active configuration's provider if present
            if let config = activeConfiguration, let provider = AIProvider(rawValue: config.provider) {
                return provider
            }
            
            if let appSettings = appSettings {
                return AIProvider(rawValue: appSettings.selectedAIProvider) ?? .gemini
            }
            return .gemini
        }
        set {
            guard activeConfiguration == nil else { return }
            objectWillChange.send()
            appSettings?.selectedAIProvider = newValue.rawValue
            refreshAPIKeyState()
            NotificationCenter.default.post(name: .AppSettingsDidChange, object: nil)
        }
    }
    
    /// Selected models per provider - reads from AppSettingsStore
    private var selectedModels: [AIProvider: String] {
        get {
            if let appSettings = appSettings {
                var result: [AIProvider: String] = [:]
                for (key, value) in appSettings.selectedModels {
                    if let provider = AIProvider(rawValue: key) {
                        result[provider] = value
                    }
                }
                return result
            }
            return [:]
        }
        set {
            objectWillChange.send()
            if let appSettings = appSettings {
                var stringDict: [String: String] = [:]
                for (provider, model) in newValue {
                    stringDict[provider.rawValue] = model
                }
                appSettings.selectedModels = stringDict
            }
        }
    }
    
    private let userDefaults = UserDefaults.hoah
    private let keyManager = CloudAPIKeyManager.shared
    private let awsProfileService = AWSProfileService()
    
    @Published private var openRouterModels: [String] = []
    @Published private var cerebrasModels: [String] = []
    
    var connectedProviders: [AIProvider] {
        AIProvider.allCases.filter { provider in
            if provider.requiresAPIKey {
                if provider == .awsBedrock {
                    let hasKey = keyManager.activeKey(for: AIProvider.awsBedrock.rawValue) != nil
                    return hasKey && !bedrockRegion.isEmpty && !bedrockModelId.isEmpty
                }
                return keyManager.hasKeys(for: provider.rawValue)
            }
            return false
        }
    }
    
    var currentModel: String {
        if let config = activeConfiguration {
            return config.model
        }
        
        if selectedProvider == .awsBedrock {
            return bedrockModelId
        }
        if let selectedModel = selectedModels[selectedProvider],
           !selectedModel.isEmpty,
           availableModels.contains(selectedModel) {
            return selectedModel
        }
        return selectedProvider.defaultModel
    }
    
    var availableModels: [String] {
        availableModels(for: selectedProvider)
    }

    func availableModels(for provider: AIProvider) -> [String] {
        if provider == .openRouter {
            let source = openRouterModels.isEmpty ? provider.availableModels : openRouterModels
            return rankOpenRouterModels(source)
        }
        if provider == .cerebras {
            let source = cerebrasModels.isEmpty ? provider.availableModels : cerebrasModels
            return rankCerebrasModels(source)
        }
        return provider.availableModels
    }
    
    init() {
        // Migration: Check for misplaced transcription provider API keys
        migrateTranscriptionProviderKeys()
        
        // Debug assertion: Ensure all AIProvider cases are enhancement providers
        #if DEBUG
        for provider in AIProvider.allCases {
            assert(isValidEnhancementProvider(provider.rawValue),
                   "AIProvider enum contains invalid provider: \(provider.rawValue)")
        }
        #endif
        
        refreshAPIKeyState()
        loadSavedOpenRouterModels()
        loadSavedCerebrasModels()
        
        // Listen for external API key changes (e.g. from APIKeyManagementView)
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAPIKeyChanged),
            name: .aiProviderKeyChanged,
            object: nil
        )
        
        // Listen for active configuration changes (e.g. from delete/update)
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleActiveConfigurationChanged),
            name: .activeAIConfigurationChanged,
            object: nil
        )
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    @objc private func handleAPIKeyChanged() {
        Task { @MainActor in
            self.refreshAPIKeyState()
            self.objectWillChange.send()
        }
    }
    
    @objc private func handleActiveConfigurationChanged() {
        Task { @MainActor in
            self.hydrateActiveConfiguration()
            self.objectWillChange.send()
        }
    }
    
    /// Migrates any misplaced transcription provider API keys from AIService storage
    /// This handles backward compatibility for users who may have configured
    /// ElevenLabs or Soniox through the old AIService interface
    private func migrateTranscriptionProviderKeys() {
        let transcriptionProviders = ["ElevenLabs"]
        
        for providerName in transcriptionProviders {
            // Check for legacy API keys in UserDefaults
            if let legacyKey = userDefaults.string(forKey: "\(providerName)APIKey"), !legacyKey.isEmpty {
                print("⚠️ Migration: Found \(providerName) API key in AIService storage.")
                print("   \(providerName) is a transcription provider and should be configured in the AI Models tab.")
                print("   The key has been left in place but will not be used by AIService.")
                // Note: We don't remove the key here to avoid data loss
                // The transcription service can pick it up if needed
            }
            
            // Check for keys in CloudAPIKeyManager
            let keys = keyManager.keys(for: providerName)
            if !keys.isEmpty {
                print("⚠️ Migration: Found \(keys.count) \(providerName) API key(s) in CloudAPIKeyManager.")
                print("   \(providerName) is a transcription provider and should be configured in the AI Models tab.")
                // Note: We don't remove the keys here to avoid data loss
            }
        }
        
        // If the selected provider was a transcription provider, reset to default
        if let savedProvider = userDefaults.string(forKey: "selectedAIProvider"),
           transcriptionProviders.contains(savedProvider) {
            print("⚠️ Migration: Selected provider was \(savedProvider), resetting to Gemini.")
            userDefaults.set(AIProvider.gemini.rawValue, forKey: "selectedAIProvider")
        }
    }
    
    /// Configure with AppSettingsStore for centralized state management
    func configure(with appSettings: AppSettingsStore) {
        self.appSettings = appSettings
        
        // Legacy Bedrock normalization: ensure saved modelId matches current region prefix.
        if activeConfiguration == nil {
            let normalized = AIService.bedrockNormalizedModelId(
                appSettings.bedrockModelId,
                region: appSettings.bedrockRegion,
                enableCrossRegion: true
            )
            if normalized != appSettings.bedrockModelId {
                appSettings.bedrockModelId = normalized
            }
        }
        
        // Subscribe to settings changes
        appSettings.selectedAIProviderPublisher
            .sink { [weak self] _ in
                self?.objectWillChange.send()
                self?.refreshAPIKeyState()
            }
            .store(in: &cancellables)
        
        appSettings.$bedrockRegion
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)
        
        appSettings.$bedrockModelId
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)
        
        appSettings.selectedModelsPublisher
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)
        
        // Subscribe to configuration profile changes
        appSettings.aiEnhancementConfigurationsPublisher
            .sink { [weak self] _ in
                self?.objectWillChange.send()
                self?.refreshAPIKeyState()
            }
            .store(in: &cancellables)
        
        appSettings.activeAIConfigurationIdPublisher
            .sink { [weak self] _ in
                self?.objectWillChange.send()
                self?.refreshAPIKeyState()
            }
            .store(in: &cancellables)
        
        // Refresh API key state with new settings
        refreshAPIKeyState()
    }
    
    private func loadSavedOpenRouterModels() {
        if let savedModels = userDefaults.array(forKey: "openRouterModels") as? [String] {
            openRouterModels = savedModels
        }
    }

    private func loadSavedCerebrasModels() {
        if let savedModels = userDefaults.array(forKey: "cerebrasModels") as? [String] {
            cerebrasModels = savedModels
        }
    }
    
    private func refreshAPIKeyState() {
        // If using configuration profiles, check the active configuration
        if let config = activeConfiguration {
            refreshAPIKeyStateFromConfiguration(config)
            return
        }
        
        // Legacy behavior: use selectedProvider
        if selectedProvider.requiresAPIKey {
            if let active = keyManager.activeKey(for: selectedProvider.rawValue) {
                self.apiKey = active.value
                if selectedProvider == .awsBedrock {
                    self.isAPIKeyValid = !bedrockRegion.isEmpty && !bedrockModelId.isEmpty
                } else {
                    self.isAPIKeyValid = true
                }
            } else {
                self.apiKey = ""
                self.isAPIKeyValid = false
            }
        } else {
            self.apiKey = ""
            self.isAPIKeyValid = true
        }
    }
    
    /// Flag to prevent recursive refresh calls
    private var isRefreshingFromConfiguration = false
    
    /// Refreshes API key state from a configuration profile
    /// Also syncs provider, model, region, and other settings from the configuration
    /// Uses equality checks to prevent unnecessary updates and potential infinite loops
    private func refreshAPIKeyStateFromConfiguration(_ config: AIEnhancementConfiguration) {
        // Prevent recursive calls
        guard !isRefreshingFromConfiguration else { return }
        isRefreshingFromConfiguration = true
        defer { isRefreshingFromConfiguration = false }
        
        // Basic validity check (skip heavy validation for profiles)
        let isAWSProfileConfig = (config.awsProfileName?.isEmpty == false) && config.provider == AIProvider.awsBedrock.rawValue
        if !isAWSProfileConfig {
            guard config.isValid else {
                self.apiKey = ""
                self.isAPIKeyValid = false
                return
            }
        }
        
        // Handle authentication
        if let profileName = config.awsProfileName, !profileName.isEmpty {
            // Profile-based Bedrock configs should be treated as configured immediately;
            // we'll still resolve credentials to pick up region overrides, but avoid
            // transient "not configured" states while the async resolve runs.
            self.apiKey = ""
            self.isAPIKeyValid = true
            let regionToUse = config.region ?? appSettings?.bedrockRegion ?? "us-east-1"
            Task { [weak self] in
                await self?.validateAWSProfileConfiguration(profileName: profileName, region: regionToUse)
            }
            return
        }

        // Access Key authentication for Bedrock (SigV4)
        if let accessKeyId = config.awsAccessKeyId, !accessKeyId.isEmpty,
           let _ = config.getAwsSecretAccessKey() {
            self.apiKey = ""
            self.isAPIKeyValid = true
            return
        }
        
        // API Key authentication - read from Keychain (use hasActualApiKey for reliability)
        if let key = config.getApiKey(), !key.isEmpty {
            self.apiKey = key
            self.isAPIKeyValid = true
        } else {
            self.apiKey = ""
            self.isAPIKeyValid = false
        }
    }

    /// Public helper to rehydrate runtime auth state from the active configuration or legacy provider selection.
    /// Useful as a last-resort when downstream logic sees a transient "not configured" state.
    @MainActor
    func hydrateActiveConfiguration() {
        if let config = activeConfiguration {
            refreshAPIKeyStateFromConfiguration(config)
        } else {
            refreshAPIKeyState()
        }
    }
    
    /// Resolves AWS profile credentials on selection to allow profile-based switching
    private func validateAWSProfileConfiguration(profileName: String, region: String?) async {
        do {
            let credentials = try await awsProfileService.resolveFreshCredentials(for: profileName)
            // Note: We intentionally do NOT update the global appSettings.bedrockRegion here.
            // When using a profile, the region is derived from the profile/config at runtime.
            await MainActor.run {
                self.apiKey = ""
                self.isAPIKeyValid = true
            }
        } catch {
            await MainActor.run {
                self.apiKey = ""
                self.isAPIKeyValid = false
                print("⚠️ AWS profile validation failed: \(error.localizedDescription)")
            }
        }
    }
    
    private func saveOpenRouterModels() {
        userDefaults.set(openRouterModels, forKey: "openRouterModels")
    }

    private func saveCerebrasModels() {
        userDefaults.set(cerebrasModels, forKey: "cerebrasModels")
    }

    private func rankPreferredModels(_ models: [String], preferred: [String]) -> [String] {
        var ranked: [String] = []
        var seen = Set<String>()

        for model in preferred where models.contains(model) {
            ranked.append(model)
            seen.insert(model)
        }

        for model in models.sorted() where !seen.contains(model) {
            ranked.append(model)
            seen.insert(model)
        }

        return ranked
    }

    private func rankOpenRouterModels(_ models: [String]) -> [String] {
        rankPreferredModels(models, preferred: AIProvider.openRouter.availableModels)
    }

    private func rankCerebrasModels(_ models: [String]) -> [String] {
        rankPreferredModels(models, preferred: AIProvider.cerebras.availableModels)
    }
    
    func selectModel(_ model: String) {
        guard !model.isEmpty else { return }
        
        if let appSettings = appSettings {
            // Update through AppSettingsStore
            var models = appSettings.selectedModels
            models[selectedProvider.rawValue] = model
            appSettings.selectedModels = models
        }
        
        objectWillChange.send()
        NotificationCenter.default.post(name: .AppSettingsDidChange, object: nil)
    }
    
    /// Validates that the provider is an enhancement provider (not a transcription provider)
    /// - Parameter providerName: The raw value of the provider to validate
    /// - Returns: True if the provider is valid for AI enhancement, false otherwise
    func isValidEnhancementProvider(_ providerName: String) -> Bool {
        // Check if the provider exists in the AIProvider enum
        guard AIProvider(rawValue: providerName) != nil else {
            return false
        }
        // All providers in AIProvider enum are enhancement providers
        // (transcription-only providers have been removed)
        return true
    }
    
    func saveAPIKey(_ key: String, completion: @escaping (Bool, String?) -> Void) {
        let trimmedKey = key.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard selectedProvider.requiresAPIKey else {
            completion(true, nil)
            return
        }
        
        // Validate that this is an enhancement provider
        guard isValidEnhancementProvider(selectedProvider.rawValue) else {
            completion(false, "Invalid provider: This provider is not available for AI Action.")
            return
        }
        
        if selectedProvider == .awsBedrock {
            saveBedrockConfig(
                apiKey: bedrockApiKey,
                region: bedrockRegion,
                modelId: bedrockModelId
            )
            completion(isAPIKeyValid, nil)
            return
        }
        
        verifyAPIKey(trimmedKey) { [weak self] isValid, errorMessage in
            guard let self = self else { return }
            DispatchQueue.main.async {
                if isValid {
                    if let entry = self.keyManager.addKey(trimmedKey, for: self.selectedProvider.rawValue) {
                        self.apiKey = entry.value
                        self.isAPIKeyValid = true
                        self.keyManager.selectKey(id: entry.id, for: self.selectedProvider.rawValue)
                        NotificationCenter.default.post(name: .aiProviderKeyChanged, object: nil)
                    } else {
                        self.apiKey = ""
                        self.isAPIKeyValid = false
                        completion(false, "Failed to securely save API key to Keychain.")
                        return
                    }
                } else {
                    self.isAPIKeyValid = false
                }
                completion(isValid, errorMessage)
            }
        }
    }
    
    func verifyAPIKey(_ key: String, completion: @escaping (Bool, String?) -> Void) {
        let trimmedKey = key.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard selectedProvider.requiresAPIKey else {
            completion(true, nil)
            return
        }
        
        if selectedProvider == .awsBedrock {
            verifyBedrockConnection(apiKey: trimmedKey, region: bedrockRegion, modelId: bedrockModelId, completion: completion)
            return
        }
        
        guard !trimmedKey.isEmpty else {
            completion(false, "API key is required")
            return
        }
        
        switch selectedProvider {
        case .anthropic:
            verifyAnthropicAPIKey(trimmedKey, completion: completion)
        case .doubao:
            Task {
                let result = await AIConfigurationValidator.verifyDoubaoKey(
                    apiKey: trimmedKey,
                    modelGroup: DoubaoModelGroup.infer(from: currentModel)
                )
                await MainActor.run {
                    completion(result.success, result.errorMessage)
                }
            }
        default:
            verifyOpenAICompatibleAPIKey(trimmedKey, completion: completion)
        }
    }
    
    func saveBedrockConfig(apiKey: String, region: String, modelId: String) {
        let trimmedKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedRegion = region.trimmingCharacters(in: .whitespacesAndNewlines)
        bedrockRegion = trimmedRegion
        bedrockModelId = AIService.bedrockNormalizedModelId(
            modelId,
            region: trimmedRegion,
            enableCrossRegion: true
        )
        
        if !trimmedKey.isEmpty {
            if let entry = keyManager.addKey(trimmedKey, for: AIProvider.awsBedrock.rawValue) {
                keyManager.selectKey(id: entry.id, for: AIProvider.awsBedrock.rawValue)
                self.apiKey = entry.value
            } else {
                self.apiKey = ""
            }
        }
        
        isAPIKeyValid = keyManager.activeKey(for: AIProvider.awsBedrock.rawValue) != nil && !bedrockRegion.isEmpty && !bedrockModelId.isEmpty
        NotificationCenter.default.post(name: .aiProviderKeyChanged, object: nil)
    }
    
    func clearAPIKey() {
        keyManager.removeAllKeys(for: selectedProvider.rawValue)
        apiKey = ""
        isAPIKeyValid = false
        NotificationCenter.default.post(name: .aiProviderKeyChanged, object: nil)
    }
    
    func rotateAPIKey() -> Bool {
        let didRotate = keyManager.rotateKey(for: selectedProvider.rawValue)
        refreshAPIKeyState()
        return didRotate
    }
    
    func selectAPIKey(id: UUID) {
        keyManager.selectKey(id: id, for: selectedProvider.rawValue)
        refreshAPIKeyState()
    }
    
    func currentKeyEntries() -> [CloudAPIKeyEntry] {
        keyManager.keys(for: selectedProvider.rawValue)
    }
    
    private func verifyOpenAICompatibleAPIKey(_ key: String, completion: @escaping (Bool, String?) -> Void) {
        let endpoint: String?
        if let customEndpoint = activeConfiguration?.customEndpoint {
            endpoint = customEndpoint
        } else {
            switch selectedProvider {
            case .azureOpenAI:
                endpoint = selectedProvider.normalizedCustomEndpoint(selectedProvider.baseURL)
            case .ociGenerativeAI:
                endpoint = selectedProvider.normalizedCustomEndpoint(AIProvider.ociEndpoint(for: "us-chicago-1"))
            case .ollama:
                endpoint = selectedProvider.normalizedCustomEndpoint("http://localhost:11434")
            default:
                endpoint = nil
            }
        }

        Task {
            let result = await AIConfigurationValidator.verifyOpenAICompatibleKey(
                apiKey: key,
                provider: selectedProvider,
                model: currentModel,
                endpoint: endpoint
            )
            await MainActor.run {
                completion(result.success, result.errorMessage)
            }
        }
    }
    
    private func verifyAnthropicAPIKey(_ key: String, completion: @escaping (Bool, String?) -> Void) {
        Task {
            let result = await AIConfigurationValidator.verifyAnthropicKey(
                apiKey: key,
                model: currentModel
            )
            await MainActor.run {
                completion(result.success, result.errorMessage)
            }
        }
    }
    
    func verifyBedrockConnection(apiKey: String, region: String, modelId: String, completion: @escaping (Bool, String?) -> Void) {
        Task {
            let result = await AIConfigurationValidator.verifyBedrockBearerToken(
                apiKey: apiKey,
                region: region,
                modelId: modelId
            )
            await MainActor.run {
                completion(result.success, result.errorMessage)
            }
        }
    }

    func fetchOpenRouterModels() async {
        let url = URL(string: "https://openrouter.ai/api/v1/models")!
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                await MainActor.run { 
                    self.openRouterModels = []
                    self.saveOpenRouterModels()
                    self.objectWillChange.send()
                }
                return
            }
            
            guard let jsonResponse = try? JSONSerialization.jsonObject(with: data) as? [String: Any], 
                  let dataArray = jsonResponse["data"] as? [[String: Any]] else {
                await MainActor.run { 
                    self.openRouterModels = []
                    self.saveOpenRouterModels()
                    self.objectWillChange.send()
                }
                return
            }
            
            let models = dataArray.compactMap { $0["id"] as? String }
            let rankedModels = rankOpenRouterModels(models)
            await MainActor.run { 
                self.openRouterModels = rankedModels
                self.saveOpenRouterModels() // Save to UserDefaults
                if self.selectedProvider == .openRouter && self.currentModel == self.selectedProvider.defaultModel && !rankedModels.isEmpty {
                    self.selectModel(rankedModels.first!)
                }
                self.objectWillChange.send()
            }
            
        } catch {
            await MainActor.run { 
                self.openRouterModels = []
                self.saveOpenRouterModels()
                self.objectWillChange.send()
            }
        }

    }

    func fetchCerebrasModels(apiKey: String) async {
        let trimmedKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedKey.isEmpty else {
            await MainActor.run {
                self.cerebrasModels = []
                self.saveCerebrasModels()
                self.objectWillChange.send()
            }
            return
        }

        let url = URL(string: "https://api.cerebras.ai/v1/models")!
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("Bearer \(trimmedKey)", forHTTPHeaderField: "Authorization")

        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                await MainActor.run {
                    self.cerebrasModels = []
                    self.saveCerebrasModels()
                    self.objectWillChange.send()
                }
                return
            }

            guard let jsonResponse = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let dataArray = jsonResponse["data"] as? [[String: Any]] else {
                await MainActor.run {
                    self.cerebrasModels = []
                    self.saveCerebrasModels()
                    self.objectWillChange.send()
                }
                return
            }

            let models = dataArray.compactMap { $0["id"] as? String }
            let rankedModels = rankCerebrasModels(models)
            await MainActor.run {
                self.cerebrasModels = rankedModels
                self.saveCerebrasModels()
                if self.selectedProvider == .cerebras && self.currentModel == self.selectedProvider.defaultModel && !rankedModels.isEmpty {
                    self.selectModel(rankedModels.first!)
                }
                self.objectWillChange.send()
            }
        } catch {
            await MainActor.run {
                self.cerebrasModels = []
                self.saveCerebrasModels()
                self.objectWillChange.send()
            }
        }
    }
}
