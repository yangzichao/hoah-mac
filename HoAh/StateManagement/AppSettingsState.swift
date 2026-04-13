import Foundation

/// Represents the complete application settings state
/// This struct contains all user-configurable settings that need to be persisted
/// Version is used for future migration support
struct AppSettingsState: Codable {
    // MARK: - Version
    
    /// Version number for migration support
    var version: Int = 1

    static let clipboardEnhancementShortcutSlotCount = 10

    static var defaultClipboardEnhancementShortcutSlotEnabledStates: [Bool] {
        Array(repeating: true, count: clipboardEnhancementShortcutSlotCount)
    }

    static func normalizedClipboardEnhancementShortcutSlotEnabledStates(_ states: [Bool]) -> [Bool] {
        var normalized = Array(states.prefix(clipboardEnhancementShortcutSlotCount))
        if normalized.count < clipboardEnhancementShortcutSlotCount {
            normalized.append(
                contentsOf: repeatElement(
                    true,
                    count: clipboardEnhancementShortcutSlotCount - normalized.count
                )
            )
        }
        return normalized
    }
    
    // MARK: - Application Settings
    
    /// Whether the user has completed the onboarding flow
    var hasCompletedOnboarding: Bool = false
    
    /// Interface language: "system", "en", or "zh-Hans"
    var appInterfaceLanguage: String = "system"

    /// UI theme: "basic" or "liquidGlass" or "vintage" or "cyberpunk"
    var uiTheme: String = "vintage"
    
    /// Whether the app runs in menu bar only mode (hides dock icon)
    var isMenuBarOnly: Bool = false
    
    // MARK: - Recorder Settings
    
    /// Recorder type: "mini" or "notch"
    var recorderType: String = "mini"
    
    /// Whether to preserve transcript in clipboard after recording
    var preserveTranscriptInClipboard: Bool = true
    
    /// Maximum recording duration in minutes (0 = unlimited)
    var maxRecordingDurationMinutes: Int = 60

    /// Selected transcription language ("auto", "en", etc.)
    var selectedLanguage: String = "auto"

    /// Whether the current selected language came from explicit user choice
    var hasManuallySelectedLanguage: Bool = false

    /// Whether transcript text formatting is enabled
    var isTextFormattingEnabled: Bool = true

    /// Whether local Whisper VAD is enabled
    var isVADEnabled: Bool = true

    /// Whether pasted transcript text should append a trailing space
    var appendTrailingSpace: Bool = true
    
    // MARK: - Hotkey Settings
    
    /// Primary hotkey option: "none", "rightOption", "leftOption", etc.
    var selectedHotkey1: String = "rightOption"
    
    /// Secondary hotkey option: "none", "rightOption", "leftOption", etc.
    var selectedHotkey2: String = "none"
    
    /// Whether middle-click toggle is enabled
    var isMiddleClickToggleEnabled: Bool = false

    /// Middle-click activation delay in milliseconds (0-5000)
    var middleClickActivationDelay: Int = 200

    /// Whether double-press hotkey auto-sends (paste + Enter) after transcription
    var multiPressGestureAutoSendEnabled: Bool = false
    
    // MARK: - Audio Settings
    
    /// Whether sound feedback is enabled
    var isSoundFeedbackEnabled: Bool = true
    
    /// Whether to mute system audio during recording
    var isSystemMuteEnabled: Bool = true
    
    // MARK: - AI Enhancement Settings
    
    /// Whether AI enhancement is enabled
    var isAIEnhancementEnabled: Bool = false

    /// Whether global clipboard AI action shortcuts are enabled
    var isClipboardEnhancementShortcutsEnabled: Bool = false

    /// Whether each Selection Action shortcut slot is individually enabled
    var clipboardEnhancementShortcutSlotEnabledStates: [Bool] = Self.defaultClipboardEnhancementShortcutSlotEnabledStates
    
    /// Selected prompt ID (UUID string)
    var selectedPromptId: String? = nil

    /// Whether to use screen capture context in AI enhancement
    var useScreenCaptureContext: Bool = false

    
    /// User profile context for AI enhancement
    var userProfileContext: String = ""
    
    /// Whether prompt triggers are enabled
    var arePromptTriggersEnabled: Bool = false

    /// Preferred translation target language (user-entered display name; may be a friendly name or raw code)
    var translationTargetLanguage: String? = nil
    
    /// Whether to include the original transcript in Translate mode output
    var showOriginalTextInTranslation: Bool = false
    
    /// Whether to include the original transcript (question) in Q&A output
    var showOriginalTextInQA: Bool = true
    
    /// Saved translation languages (comma-separated)
    var savedTranslationLanguagesRaw: String = TranslationTargetPresets.defaultSavedLanguagesRaw

    // MARK: - Second Translation Mode Settings

    /// Whether the second translation mode is enabled (shows in prompt grid)
    var isSecondTranslationEnabled: Bool = false

    /// Preferred target language for second translation mode
    var translationTargetLanguage2: String? = nil

    /// Whether to include the original transcript in second translation output
    var showOriginalTextInTranslation2: Bool = false

    // MARK: - Polish Mode Enhancement Toggles
    
    /// Whether Formal Writing enhancement is enabled in Polish mode
    var isPolishFormalWritingEnabled: Bool = false
    
    /// Whether Professional (High-EQ) enhancement is enabled in Polish mode
    var isPolishProfessionalEnabled: Bool = false
    
    /// Whether the Polish mode migration has been completed (Writing/Professional → Polish toggles)
    var hasCompletedPolishModeMigration: Bool = false
    
    // MARK: - AI Provider Settings
    
    /// Selected AI provider raw value, e.g. "Gemini" or "OpenAI"
    var selectedAIProvider: String = AIProvider.gemini.rawValue
    
    /// AWS Bedrock region
    var bedrockRegion: String = "us-east-1"
    
    /// AWS Bedrock model ID
    var bedrockModelId: String = "us.anthropic.claude-sonnet-4-5-20250929-v1:0"
    
    /// Selected models per provider (provider name -> model name)
    var selectedModels: [String: String] = [:]
    
    // MARK: - AI Enhancement Configuration Profiles (New)
    
    /// List of saved AI Enhancement configuration profiles
    var aiEnhancementConfigurations: [AIEnhancementConfiguration] = []
    
    /// ID of the currently active AI Enhancement configuration
    var activeAIConfigurationId: UUID? = nil
    
    /// Whether legacy AI provider settings have been migrated to configuration profiles
    var hasCompletedAIConfigMigration: Bool = false
    
    // MARK: - Auto Export Settings
    
    /// Whether automatic daily export is enabled
    var isAutoExportEnabled: Bool = false

    /// Whether transcript history cleanup is enabled
    var isTranscriptionCleanupEnabled: Bool = true

    /// Retention period for transcript cleanup in minutes
    var transcriptionRetentionMinutes: Int = 30 * 24 * 60

    /// Whether automatic audio cleanup is enabled
    var isAudioCleanupEnabled: Bool = false

    /// Retention period for audio cleanup in days
    var audioRetentionPeriod: Int = 7
    
    // MARK: - Init (explicit to retain default init alongside custom decoder)
    init() {}
    
    /// Memberwise initializer (needed because custom Decoder removes synthesized init)
    init(
        version: Int = 1,
        hasCompletedOnboarding: Bool = false,
        appInterfaceLanguage: String = "system",
        uiTheme: String = "vintage",
        isMenuBarOnly: Bool = false,
        recorderType: String = "mini",
        preserveTranscriptInClipboard: Bool = true,
        maxRecordingDurationMinutes: Int = 60,
        selectedLanguage: String = "auto",
        hasManuallySelectedLanguage: Bool = false,
        isTextFormattingEnabled: Bool = true,
        isVADEnabled: Bool = true,
        appendTrailingSpace: Bool = true,
        selectedHotkey1: String = "rightOption",
        selectedHotkey2: String = "none",
        isMiddleClickToggleEnabled: Bool = false,
        middleClickActivationDelay: Int = 200,
        multiPressGestureAutoSendEnabled: Bool = false,
        isSoundFeedbackEnabled: Bool = true,
        isSystemMuteEnabled: Bool = true,
        // isPauseMediaEnabled removed
        isAIEnhancementEnabled: Bool = false,
        isClipboardEnhancementShortcutsEnabled: Bool = false,
        clipboardEnhancementShortcutSlotEnabledStates: [Bool] = Self.defaultClipboardEnhancementShortcutSlotEnabledStates,
        selectedPromptId: String? = nil,
        useScreenCaptureContext: Bool = false,
        userProfileContext: String = "",
        arePromptTriggersEnabled: Bool = false,
        translationTargetLanguage: String? = nil,
        showOriginalTextInTranslation: Bool = false,
        showOriginalTextInQA: Bool = true,
        savedTranslationLanguagesRaw: String = TranslationTargetPresets.defaultSavedLanguagesRaw,
        isSecondTranslationEnabled: Bool = false,
        translationTargetLanguage2: String? = nil,
        showOriginalTextInTranslation2: Bool = false,
        isPolishFormalWritingEnabled: Bool = false,
        isPolishProfessionalEnabled: Bool = false,
        hasCompletedPolishModeMigration: Bool = false,
        selectedAIProvider: String = AIProvider.gemini.rawValue,
        bedrockRegion: String = "us-east-1",
        bedrockModelId: String = "us.anthropic.claude-sonnet-4-5-20250929-v1:0",
        selectedModels: [String: String] = [:],
        aiEnhancementConfigurations: [AIEnhancementConfiguration] = [],
        activeAIConfigurationId: UUID? = nil,
        hasCompletedAIConfigMigration: Bool = false,
        isAutoExportEnabled: Bool = false,
        isTranscriptionCleanupEnabled: Bool = true,
        transcriptionRetentionMinutes: Int = 30 * 24 * 60,
        isAudioCleanupEnabled: Bool = false,
        audioRetentionPeriod: Int = 7
    ) {
        self.version = version
        self.hasCompletedOnboarding = hasCompletedOnboarding
        self.appInterfaceLanguage = appInterfaceLanguage
        self.uiTheme = uiTheme
        self.isMenuBarOnly = isMenuBarOnly
        self.recorderType = recorderType
        self.preserveTranscriptInClipboard = preserveTranscriptInClipboard
        self.maxRecordingDurationMinutes = maxRecordingDurationMinutes
        self.selectedLanguage = selectedLanguage
        self.hasManuallySelectedLanguage = hasManuallySelectedLanguage
        self.isTextFormattingEnabled = isTextFormattingEnabled
        self.isVADEnabled = isVADEnabled
        self.appendTrailingSpace = appendTrailingSpace
        self.selectedHotkey1 = selectedHotkey1
        self.selectedHotkey2 = selectedHotkey2
        self.isMiddleClickToggleEnabled = isMiddleClickToggleEnabled
        self.middleClickActivationDelay = middleClickActivationDelay
        self.multiPressGestureAutoSendEnabled = multiPressGestureAutoSendEnabled
        self.isSoundFeedbackEnabled = isSoundFeedbackEnabled
        self.isSystemMuteEnabled = isSystemMuteEnabled
        // self.isPauseMediaEnabled = isPauseMediaEnabled removed
        self.isAIEnhancementEnabled = isAIEnhancementEnabled
        self.isClipboardEnhancementShortcutsEnabled = isClipboardEnhancementShortcutsEnabled
        self.clipboardEnhancementShortcutSlotEnabledStates = Self.normalizedClipboardEnhancementShortcutSlotEnabledStates(clipboardEnhancementShortcutSlotEnabledStates)
        self.selectedPromptId = selectedPromptId
        self.useScreenCaptureContext = useScreenCaptureContext
        self.userProfileContext = userProfileContext
        self.arePromptTriggersEnabled = arePromptTriggersEnabled
        self.translationTargetLanguage = translationTargetLanguage
        self.showOriginalTextInTranslation = showOriginalTextInTranslation
        self.showOriginalTextInQA = showOriginalTextInQA
        self.savedTranslationLanguagesRaw = savedTranslationLanguagesRaw
        self.isSecondTranslationEnabled = isSecondTranslationEnabled
        self.translationTargetLanguage2 = translationTargetLanguage2
        self.showOriginalTextInTranslation2 = showOriginalTextInTranslation2
        self.isPolishFormalWritingEnabled = isPolishFormalWritingEnabled
        self.isPolishProfessionalEnabled = isPolishProfessionalEnabled
        self.hasCompletedPolishModeMigration = hasCompletedPolishModeMigration
        self.selectedAIProvider = selectedAIProvider
        self.bedrockRegion = bedrockRegion
        self.bedrockModelId = bedrockModelId
        self.selectedModels = selectedModels
        self.aiEnhancementConfigurations = aiEnhancementConfigurations
        self.activeAIConfigurationId = activeAIConfigurationId
        self.hasCompletedAIConfigMigration = hasCompletedAIConfigMigration
        self.isAutoExportEnabled = isAutoExportEnabled
        self.isTranscriptionCleanupEnabled = isTranscriptionCleanupEnabled
        self.transcriptionRetentionMinutes = transcriptionRetentionMinutes
        self.isAudioCleanupEnabled = isAudioCleanupEnabled
        self.audioRetentionPeriod = audioRetentionPeriod
    }
    
    // MARK: - Codable (custom to tolerate missing/new fields)
    
    private enum CodingKeys: String, CodingKey {
        case version
        case hasCompletedOnboarding
        case appInterfaceLanguage
        case uiTheme
        case isMenuBarOnly
        case recorderType
        case preserveTranscriptInClipboard
        case maxRecordingDurationMinutes
        case selectedLanguage
        case hasManuallySelectedLanguage
        case isTextFormattingEnabled
        case isVADEnabled
        case appendTrailingSpace
        case selectedHotkey1
        case selectedHotkey2
        case isMiddleClickToggleEnabled
        case middleClickActivationDelay
        case multiPressGestureAutoSendEnabled
        case isSoundFeedbackEnabled
        case isSystemMuteEnabled
        // case isPauseMediaEnabled removed
        case isAIEnhancementEnabled
        case isClipboardEnhancementShortcutsEnabled
        case clipboardEnhancementShortcutSlotEnabledStates
        case selectedPromptId
        case useScreenCaptureContext
        case userProfileContext
        case arePromptTriggersEnabled
        case translationTargetLanguage
        case showOriginalTextInTranslation
        case showOriginalTextInQA
        case savedTranslationLanguagesRaw
        case isSecondTranslationEnabled
        case translationTargetLanguage2
        case showOriginalTextInTranslation2
        case isPolishFormalWritingEnabled
        case isPolishProfessionalEnabled
        case hasCompletedPolishModeMigration
        case selectedAIProvider
        case bedrockRegion
        case bedrockModelId
        case selectedModels
        case aiEnhancementConfigurations
        case activeAIConfigurationId
        case hasCompletedAIConfigMigration
        case isAutoExportEnabled
        case isTranscriptionCleanupEnabled
        case transcriptionRetentionMinutes
        case isAudioCleanupEnabled
        case audioRetentionPeriod
    }
    
    private enum LegacyCodingKeys: String, CodingKey {
        case multiPressGestureMergeEnabled
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let legacyContainer = try decoder.container(keyedBy: LegacyCodingKeys.self)
        
        version = (try? container.decode(Int.self, forKey: .version)) ?? 1
        hasCompletedOnboarding = (try? container.decode(Bool.self, forKey: .hasCompletedOnboarding)) ?? false
        appInterfaceLanguage = (try? container.decode(String.self, forKey: .appInterfaceLanguage)) ?? "system"
        uiTheme = (try? container.decode(String.self, forKey: .uiTheme)) ?? "vintage"
        isMenuBarOnly = (try? container.decode(Bool.self, forKey: .isMenuBarOnly)) ?? false
        recorderType = (try? container.decode(String.self, forKey: .recorderType)) ?? "mini"
        preserveTranscriptInClipboard = (try? container.decode(Bool.self, forKey: .preserveTranscriptInClipboard)) ?? true
        maxRecordingDurationMinutes = (try? container.decode(Int.self, forKey: .maxRecordingDurationMinutes)) ?? 60
        selectedLanguage = (try? container.decode(String.self, forKey: .selectedLanguage)) ?? "auto"
        hasManuallySelectedLanguage = (try? container.decode(Bool.self, forKey: .hasManuallySelectedLanguage)) ?? false
        isTextFormattingEnabled = (try? container.decode(Bool.self, forKey: .isTextFormattingEnabled)) ?? true
        isVADEnabled = (try? container.decode(Bool.self, forKey: .isVADEnabled)) ?? true
        appendTrailingSpace = (try? container.decode(Bool.self, forKey: .appendTrailingSpace)) ?? true
        selectedHotkey1 = (try? container.decode(String.self, forKey: .selectedHotkey1)) ?? "rightOption"
        selectedHotkey2 = (try? container.decode(String.self, forKey: .selectedHotkey2)) ?? "none"
        isMiddleClickToggleEnabled = (try? container.decode(Bool.self, forKey: .isMiddleClickToggleEnabled)) ?? false
        middleClickActivationDelay = (try? container.decode(Int.self, forKey: .middleClickActivationDelay)) ?? 200
        let legacyMergeEnabled = (try? legacyContainer.decode(Bool.self, forKey: .multiPressGestureMergeEnabled)) ?? false
        multiPressGestureAutoSendEnabled = (try? container.decode(Bool.self, forKey: .multiPressGestureAutoSendEnabled)) ?? legacyMergeEnabled
        isSoundFeedbackEnabled = (try? container.decode(Bool.self, forKey: .isSoundFeedbackEnabled)) ?? true
        isSystemMuteEnabled = (try? container.decode(Bool.self, forKey: .isSystemMuteEnabled)) ?? true
        // isPauseMediaEnabled removed
        isAIEnhancementEnabled = (try? container.decode(Bool.self, forKey: .isAIEnhancementEnabled)) ?? false
        isClipboardEnhancementShortcutsEnabled = (try? container.decode(Bool.self, forKey: .isClipboardEnhancementShortcutsEnabled)) ?? false
        clipboardEnhancementShortcutSlotEnabledStates = Self.normalizedClipboardEnhancementShortcutSlotEnabledStates(
            (try? container.decode([Bool].self, forKey: .clipboardEnhancementShortcutSlotEnabledStates))
                ?? Self.defaultClipboardEnhancementShortcutSlotEnabledStates
        )
        selectedPromptId = (try? container.decodeIfPresent(String.self, forKey: .selectedPromptId)) ?? nil
        useScreenCaptureContext = (try? container.decode(Bool.self, forKey: .useScreenCaptureContext)) ?? false
        userProfileContext = (try? container.decode(String.self, forKey: .userProfileContext)) ?? ""
        arePromptTriggersEnabled = (try? container.decode(Bool.self, forKey: .arePromptTriggersEnabled)) ?? false
        translationTargetLanguage = (try? container.decodeIfPresent(String.self, forKey: .translationTargetLanguage)) ?? nil
        showOriginalTextInTranslation = (try? container.decode(Bool.self, forKey: .showOriginalTextInTranslation)) ?? false
        showOriginalTextInQA = (try? container.decode(Bool.self, forKey: .showOriginalTextInQA)) ?? true
        savedTranslationLanguagesRaw = (try? container.decode(String.self, forKey: .savedTranslationLanguagesRaw)) ?? TranslationTargetPresets.defaultSavedLanguagesRaw
        isSecondTranslationEnabled = (try? container.decode(Bool.self, forKey: .isSecondTranslationEnabled)) ?? false
        translationTargetLanguage2 = (try? container.decodeIfPresent(String.self, forKey: .translationTargetLanguage2)) ?? nil
        showOriginalTextInTranslation2 = (try? container.decode(Bool.self, forKey: .showOriginalTextInTranslation2)) ?? false
        isPolishFormalWritingEnabled = (try? container.decode(Bool.self, forKey: .isPolishFormalWritingEnabled)) ?? false
        isPolishProfessionalEnabled = (try? container.decode(Bool.self, forKey: .isPolishProfessionalEnabled)) ?? false
        hasCompletedPolishModeMigration = (try? container.decode(Bool.self, forKey: .hasCompletedPolishModeMigration)) ?? false
        selectedAIProvider = (try? container.decode(String.self, forKey: .selectedAIProvider)) ?? AIProvider.gemini.rawValue
        bedrockRegion = (try? container.decode(String.self, forKey: .bedrockRegion)) ?? "us-east-1"
        bedrockModelId = (try? container.decode(String.self, forKey: .bedrockModelId)) ?? "us.anthropic.claude-sonnet-4-5-20250929-v1:0"
        selectedModels = (try? container.decode([String: String].self, forKey: .selectedModels)) ?? [:]
        aiEnhancementConfigurations = (try? container.decode([AIEnhancementConfiguration].self, forKey: .aiEnhancementConfigurations)) ?? []
        activeAIConfigurationId = (try? container.decodeIfPresent(UUID.self, forKey: .activeAIConfigurationId)) ?? nil
        hasCompletedAIConfigMigration = (try? container.decode(Bool.self, forKey: .hasCompletedAIConfigMigration)) ?? false
        isAutoExportEnabled = (try? container.decode(Bool.self, forKey: .isAutoExportEnabled)) ?? false
        isTranscriptionCleanupEnabled = (try? container.decode(Bool.self, forKey: .isTranscriptionCleanupEnabled)) ?? true
        transcriptionRetentionMinutes = (try? container.decode(Int.self, forKey: .transcriptionRetentionMinutes)) ?? 30 * 24 * 60
        isAudioCleanupEnabled = (try? container.decode(Bool.self, forKey: .isAudioCleanupEnabled)) ?? false
        audioRetentionPeriod = (try? container.decode(Int.self, forKey: .audioRetentionPeriod)) ?? 7
    }
    
    // MARK: - Validation
    
    /// Validates the settings state and returns validation result
    /// - Returns: ValidationResult indicating whether the state is valid and any errors found
    func validate() -> ValidationResult {
        var errors: [String] = []
        
        // Validate recorder type
        if recorderType != "mini" && recorderType != "notch" {
            errors.append("Invalid recorderType: \(recorderType). Must be 'mini' or 'notch'.")
        }
        
        // Validate language
        let validLanguages = ["system", "en", "zh-Hans"]
        if !validLanguages.contains(appInterfaceLanguage) {
            errors.append("Invalid appInterfaceLanguage: \(appInterfaceLanguage). Must be one of: \(validLanguages.joined(separator: ", ")).")
        }

        // Validate UI theme
        let validThemes = ["basic", "liquidGlass", "cyberpunk", "vintage"]
        if !validThemes.contains(uiTheme) {
            errors.append("Invalid uiTheme: \(uiTheme). Must be one of: \(validThemes.joined(separator: ", ")).")
        }
        
        // Validate hotkey options
        let validHotkeys = ["none", "rightOption", "leftOption", "leftControl", 
                           "rightControl", "fn", "rightCommand", "rightShift", "custom"]
        if !validHotkeys.contains(selectedHotkey1) {
            errors.append("Invalid selectedHotkey1: \(selectedHotkey1). Must be one of: \(validHotkeys.joined(separator: ", ")).")
        }
        if !validHotkeys.contains(selectedHotkey2) {
            errors.append("Invalid selectedHotkey2: \(selectedHotkey2). Must be one of: \(validHotkeys.joined(separator: ", ")).")
        }
        
        // Validate hotkey conflict
        if selectedHotkey1 != "none" && selectedHotkey2 != "none" && selectedHotkey1 == selectedHotkey2 {
            errors.append("Hotkey conflict: selectedHotkey1 and selectedHotkey2 cannot be the same.")
        }
        
        // Validate max recording duration (0 for unlimited, otherwise 1-180 minutes)
        if maxRecordingDurationMinutes < 0 || maxRecordingDurationMinutes > 180 {
            errors.append("Invalid maxRecordingDurationMinutes: \(maxRecordingDurationMinutes). Must be 0 (no limit) or between 1 and 180.")
        }
        
        // Validate delay range
        if middleClickActivationDelay < 0 || middleClickActivationDelay > 5000 {
            errors.append("Invalid middleClickActivationDelay: \(middleClickActivationDelay). Must be between 0 and 5000.")
        }

        if transcriptionRetentionMinutes < 0 {
            errors.append("Invalid transcriptionRetentionMinutes: \(transcriptionRetentionMinutes). Must be 0 or greater.")
        }

        if audioRetentionPeriod < 1 {
            errors.append("Invalid audioRetentionPeriod: \(audioRetentionPeriod). Must be at least 1.")
        }

        if clipboardEnhancementShortcutSlotEnabledStates.count != Self.clipboardEnhancementShortcutSlotCount {
            errors.append(
                "Invalid clipboardEnhancementShortcutSlotEnabledStates count: \(clipboardEnhancementShortcutSlotEnabledStates.count). Must be \(Self.clipboardEnhancementShortcutSlotCount)."
            )
        }

        if let target = translationTargetLanguage,
           target.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            errors.append("Invalid translationTargetLanguage: value is empty.")
        }
        
        return ValidationResult(isValid: errors.isEmpty, errors: errors)
    }
    
    /// Returns a copy of this state with safe default values for any invalid settings
    /// This is used when loading corrupted or invalid settings from storage
    /// - Returns: A new AppSettingsState with safe defaults applied
    func withSafeDefaults() -> AppSettingsState {
        var safe = self
        
        // Fix recorder type
        if recorderType != "mini" && recorderType != "notch" {
            safe.recorderType = "mini"
        }

        // Fix UI theme
        let validThemes = ["basic", "liquidGlass", "cyberpunk", "vintage"]
        if !validThemes.contains(uiTheme) {
            safe.uiTheme = "vintage"
        }
        
        // Fix language
        let validLanguages = ["system", "en", "zh-Hans"]
        if !validLanguages.contains(appInterfaceLanguage) {
            safe.appInterfaceLanguage = "system"
        }
        
        // Fix hotkeys
        let validHotkeys = ["none", "rightOption", "leftOption", "leftControl", 
                           "rightControl", "fn", "rightCommand", "rightShift", "custom"]
        if !validHotkeys.contains(selectedHotkey1) {
            safe.selectedHotkey1 = "rightOption"
        }
        if !validHotkeys.contains(selectedHotkey2) {
            safe.selectedHotkey2 = "none"
        }
        
        // Fix hotkey conflict
        if safe.selectedHotkey1 != "none" && safe.selectedHotkey2 != "none" && safe.selectedHotkey1 == safe.selectedHotkey2 {
            safe.selectedHotkey2 = "none"
        }
        
        // Fix max recording duration
        if safe.maxRecordingDurationMinutes < 0 {
            safe.maxRecordingDurationMinutes = 0
        } else if safe.maxRecordingDurationMinutes > 180 {
            safe.maxRecordingDurationMinutes = 180
        }
        
        // Fix delay
        if middleClickActivationDelay < 0 {
            safe.middleClickActivationDelay = 0
        } else if middleClickActivationDelay > 5000 {
            safe.middleClickActivationDelay = 5000
        }

        if transcriptionRetentionMinutes < 0 {
            safe.transcriptionRetentionMinutes = 0
        }

        if audioRetentionPeriod < 1 {
            safe.audioRetentionPeriod = 7
        }

        safe.clipboardEnhancementShortcutSlotEnabledStates = Self.normalizedClipboardEnhancementShortcutSlotEnabledStates(
            clipboardEnhancementShortcutSlotEnabledStates
        )

        let trimmedTarget = translationTargetLanguage?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if trimmedTarget.isEmpty {
            let defaultLanguage = AppLanguage(code: appInterfaceLanguage) == .simplifiedChinese
                ? TranslationLanguage.simplifiedChinese.gptName
                : TranslationLanguage.english.gptName
            safe.translationTargetLanguage = defaultLanguage
        } else {
            safe.translationTargetLanguage = trimmedTarget
        }
        
        return safe
    }
}

/// Result of settings validation
struct ValidationResult {
    /// Whether the settings are valid
    let isValid: Bool
    
    /// List of validation errors (empty if valid)
    let errors: [String]
}
