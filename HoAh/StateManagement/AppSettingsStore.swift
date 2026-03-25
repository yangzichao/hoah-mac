import Foundation
import SwiftUI
import OSLog

/// Central store for all application settings
/// This is the single source of truth for user-configurable settings
/// All UI components should read from and write to this store
///
/// State Management Rule: To modify any application setting, update properties in this store.
/// Do not use @AppStorage or direct UserDefaults access elsewhere in the app.
@MainActor
class AppSettingsStore: ObservableObject {
    private static func defaultTranslationTarget(for interfaceLanguageCode: String) -> String {
        switch AppLanguage(code: interfaceLanguageCode) {
        case .simplifiedChinese:
            return "Chinese"
        case .english, .system:
            return "English"
        }
    }
    
    // MARK: - Published Properties
    
    // Application Settings
    
    /// Whether the user has completed the onboarding flow
    @Published var hasCompletedOnboarding: Bool {
        didSet { saveSettings() }
    }
    
    // Storage for Interface Language
    @Published private var _appInterfaceLanguage: String
    
    /// Interface language: "system", "en", or "zh-Hans"
    var appInterfaceLanguage: String {
        get { _appInterfaceLanguage }
        set {
            _appInterfaceLanguage = newValue
            validateLanguage()
            saveSettings()
        }
    }

    /// UI theme: "basic" or "liquidGlass"
    @Published var uiTheme: String {
        didSet {
            validateTheme()
            saveSettings()
        }
    }
    
    /// Whether the app runs in menu bar only mode (hides dock icon)
    @Published var isMenuBarOnly: Bool {
        didSet { saveSettings() }
    }
    
    // Recorder Settings
    
    /// Recorder type: "mini" or "notch"
    @Published var recorderType: String {
        didSet { 
            validateRecorderType()
            saveSettings() 
        }
    }
    
    /// Whether to preserve transcript in clipboard after recording
    @Published var preserveTranscriptInClipboard: Bool {
        didSet {
            // Keep legacy key in sync for runtime clipboard behavior in CursorPaster.
            UserDefaults.hoah.set(preserveTranscriptInClipboard, forKey: "preserveTranscriptInClipboard")
            saveSettings()
        }
    }
    
    /// Maximum recording duration in minutes
    @Published var maxRecordingDurationMinutes: Int {
        didSet { 
            validateMaxRecordingDuration()
            saveSettings() 
        }
    }
    
    // Hotkey Settings
    
    /// Primary hotkey option
    @Published var selectedHotkey1: String {
        didSet { 
            validateHotkeys()
            saveSettings() 
        }
    }
    
    /// Secondary hotkey option
    @Published var selectedHotkey2: String {
        didSet { 
            validateHotkeys()
            saveSettings() 
        }
    }
    
    /// Whether middle-click toggle is enabled
    @Published var isMiddleClickToggleEnabled: Bool {
        didSet { saveSettings() }
    }
    
    /// Middle-click activation delay in milliseconds (0-5000)
    @Published var middleClickActivationDelay: Int {
        didSet { 
            validateDelay()
            saveSettings() 
        }
    }
    
    // Audio Settings
    
    /// Whether sound feedback is enabled
    @Published var isSoundFeedbackEnabled: Bool {
        didSet { saveSettings() }
    }
    
    /// Whether to mute system audio during recording
    @Published var isSystemMuteEnabled: Bool {
        didSet { saveSettings() }
    }
    

    
    // AI Enhancement Settings
    
    // Storage for AI Enhancement
    @Published private var _isAIEnhancementEnabled: Bool
    
    /// Whether AI enhancement is enabled
    var isAIEnhancementEnabled: Bool {
        get { _isAIEnhancementEnabled }
        set {
            _isAIEnhancementEnabled = newValue
            handleAIEnhancementChange()
            saveSettings()
        }
    }

    /// Whether global clipboard AI action shortcuts are enabled
    @Published var isClipboardEnhancementShortcutsEnabled: Bool {
        didSet { saveSettings() }
    }
    
    // Storage for Selected Prompt ID
    @Published private var _selectedPromptId: String?
    
    /// Selected prompt ID (UUID string)
    var selectedPromptId: String? {
        get { _selectedPromptId }
        set {
            _selectedPromptId = newValue
            saveSettings()
        }
    }
    
    /// Whether to use screen capture context in AI enhancement
    @Published var useScreenCaptureContext: Bool {
        didSet { saveSettings() }
    }

    /// User profile context for AI enhancement
    @Published var userProfileContext: String {
        didSet { saveSettings() }
    }
    
    /// Whether prompt triggers are enabled
    @Published var arePromptTriggersEnabled: Bool {
        didSet {
            // Feature deprecated: always force disabled state
            if arePromptTriggersEnabled {
                arePromptTriggersEnabled = false
                return
            }
            saveSettings()
        }
    }

    /// Preferred translation target language (user-entered display name or raw code)
    @Published var translationTargetLanguage: String {
        didSet { saveSettings() }
    }
    
    /// Whether to include the original transcript in Translate mode output
    @Published var showOriginalTextInTranslation: Bool {
        didSet { saveSettings() }
    }
    
    /// Whether to include the original transcript (question) in Q&A output
    @Published var showOriginalTextInQA: Bool {
        didSet { saveSettings() }
    }
    
    // MARK: - Translation Language List
    
    /// Raw comma-separated string of saved translation languages
    @Published var savedTranslationLanguagesRaw: String {
        didSet {
            // Sync to UserDefaults for backward compatibility with @AppStorage
            UserDefaults.hoah.set(savedTranslationLanguagesRaw, forKey: TranslationTargetPresets.savedLanguagesKey)
            saveSettings()
        }
    }
    
    /// Parsed list of saved translation languages
    var savedTranslationLanguages: [String] {
        savedTranslationLanguagesRaw.split(separator: ",").map { String($0).trimmingCharacters(in: .whitespaces) }
    }
    
    /// Moves a language to the front of the list (most recently used)
    func moveTranslationLanguageToFront(_ language: String) {
        var currentList = savedTranslationLanguages
        if let idx = currentList.firstIndex(of: language), idx != 0 {
            currentList.remove(at: idx)
            currentList.insert(language, at: 0)
            savedTranslationLanguagesRaw = currentList.joined(separator: ",")
        }
    }
    
    /// Adds a new language to the front of the list if not already present
    func addTranslationLanguage(_ language: String) {
        let trimmed = language.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        var currentList = savedTranslationLanguages
        if !currentList.contains(trimmed) {
            currentList.insert(trimmed, at: 0)
            savedTranslationLanguagesRaw = currentList.joined(separator: ",")
        }
    }
    
    /// Removes a language from the list
    func removeTranslationLanguage(_ language: String) {
        var currentList = savedTranslationLanguages
        currentList.removeAll { $0 == language }
        savedTranslationLanguagesRaw = currentList.joined(separator: ",")
    }
    
    /// Selects a translation language and moves it to front (adds if not present)
    func selectTranslationLanguage(_ language: String) {
        let trimmed = language.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }

        translationTargetLanguage = trimmed

        // Add to list if not present, then move to front
        if !savedTranslationLanguages.contains(trimmed) {
            addTranslationLanguage(trimmed)
        } else {
            moveTranslationLanguageToFront(trimmed)
        }
    }

    // MARK: - Second Translation Mode Settings

    /// Whether the second translation mode is enabled (shows in prompt grid)
    @Published var isSecondTranslationEnabled: Bool {
        didSet { saveSettings() }
    }

    /// Preferred target language for second translation mode
    @Published var translationTargetLanguage2: String {
        didSet { saveSettings() }
    }

    /// Whether to include the original transcript in second translation output
    @Published var showOriginalTextInTranslation2: Bool {
        didSet { saveSettings() }
    }

    /// Selects a translation language for the second translation mode (adds if not present)
    func selectTranslationLanguage2(_ language: String) {
        let trimmed = language.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }

        translationTargetLanguage2 = trimmed

        // Add to shared list if not present
        if !savedTranslationLanguages.contains(trimmed) {
            addTranslationLanguage(trimmed)
        }
    }

    // MARK: - Polish Mode Enhancement Toggles
    
    /// Whether Formal Writing enhancement is enabled in Polish mode
    @Published var isPolishFormalWritingEnabled: Bool {
        didSet { saveSettings() }
    }
    
    /// Whether Professional (High-EQ) enhancement is enabled in Polish mode
    @Published var isPolishProfessionalEnabled: Bool {
        didSet { saveSettings() }
    }
    
    /// Whether the Polish mode migration has been completed
    @Published var hasCompletedPolishModeMigration: Bool {
        didSet { saveSettings() }
    }

    /// Helper to read/write the preferred translation language as a typed enum.
    var translationLanguage: TranslationLanguage {
        get { TranslationLanguage.from(translationTargetLanguage) }
        set { translationTargetLanguage = newValue.rawValue }
    }
    
    // AI Provider Settings
    
    // Storage for Selected AI Provider
    @Published private var _selectedAIProvider: String
    
    /// Selected AI provider
    var selectedAIProvider: String {
        get { _selectedAIProvider }
        set {
            _selectedAIProvider = newValue
            validateProvider()
            saveSettings()
        }
    }
    
    /// AWS Bedrock region
    @Published var bedrockRegion: String {
        didSet { saveSettings() }
    }
    
    /// AWS Bedrock model ID
    @Published var bedrockModelId: String {
        didSet { saveSettings() }
    }
    
    // Storage for Selected Models
    @Published private var _selectedModels: [String: String]
    
    /// Selected models per provider (provider name -> model name)
    var selectedModels: [String: String] {
        get { _selectedModels }
        set {
            _selectedModels = newValue
            saveSettings()
        }
    }
    
    // MARK: - Computed Properties
    
    /// Whether the recorder is properly configured with at least one hotkey
    var isRecorderConfigured: Bool {
        return selectedHotkey1 != "none" || selectedHotkey2 != "none"
    }

    // Publishers for settings properties (use backing storage publishers)
    var appInterfaceLanguagePublisher: Published<String>.Publisher { $_appInterfaceLanguage }
    var isAIEnhancementEnabledPublisher: Published<Bool>.Publisher { $_isAIEnhancementEnabled }
    var selectedPromptIdPublisher: Published<String?>.Publisher { $_selectedPromptId }
    var selectedAIProviderPublisher: Published<String>.Publisher { $_selectedAIProvider }
    var selectedModelsPublisher: Published<[String: String]>.Publisher { $_selectedModels }
    
    // MARK: - AI Enhancement Configuration Profiles
    
    /// List of saved AI Enhancement configuration profiles
    @Published var aiEnhancementConfigurations: [AIEnhancementConfiguration] = [] {
        didSet { saveSettings() }
    }
    
    /// ID of the currently active AI Enhancement configuration
    @Published var activeAIConfigurationId: UUID? = nil {
        didSet { saveSettings() }
    }
    
    /// Whether legacy AI provider settings have been migrated
    @Published var hasCompletedAIConfigMigration: Bool = false {
        didSet { saveSettings() }
    }
    
    /// Currently active AI Enhancement configuration (computed)
    var activeAIConfiguration: AIEnhancementConfiguration? {
        guard let activeId = activeAIConfigurationId else { return nil }
        return aiEnhancementConfigurations.first { $0.id == activeId }
    }
    
    /// Valid configurations only (for quick-switch UI)
    var validAIConfigurations: [AIEnhancementConfiguration] {
        aiEnhancementConfigurations.filter { $0.isValid }
    }
    
    /// Publishers for configuration changes
    var aiEnhancementConfigurationsPublisher: Published<[AIEnhancementConfiguration]>.Publisher { $aiEnhancementConfigurations }
    var activeAIConfigurationIdPublisher: Published<UUID?>.Publisher { $activeAIConfigurationId }
    
    // MARK: - Auto Export Settings
    
    /// Whether automatic daily export is enabled
    @Published var isAutoExportEnabled: Bool = false {
        didSet {
            // Sync with UserDefaults for AutoExportService to read
            UserDefaults.hoah.set(isAutoExportEnabled, forKey: "isAutoExportEnabled")
            saveSettings()
        }
    }
    
    /// Display path for the configured export folder (computed from bookmark)
    var autoExportDisplayPath: String? {
        AutoExportService.shared.displayPath()
    }
    
    /// Whether a valid export path is configured
    var hasValidAutoExportPath: Bool {
        SecurityScopedBookmarkManager.hasValidBookmark()
    }
    
    // MARK: - Storage
    
    private let storage: SettingsStorage
    private let logger = Logger(subsystem: "com.yangzichao.hoah", category: "AppSettingsStore")
    
    // MARK: - Initialization
    
    /// Initializes the settings store with the specified storage backend
    /// - Parameter storage: Storage implementation (defaults to UserDefaultsStorage)
    init(storage: SettingsStorage = UserDefaultsStorage()) {
        self.storage = storage
        
        // Load settings from storage or use defaults
        let state = storage.load() ?? AppSettingsState()
        
        // Initialize all @Published properties
        self.hasCompletedOnboarding = state.hasCompletedOnboarding
        self._appInterfaceLanguage = state.appInterfaceLanguage // Initialize storage
        self.uiTheme = state.uiTheme
        self.isMenuBarOnly = state.isMenuBarOnly
        self.recorderType = state.recorderType
        self.preserveTranscriptInClipboard = state.preserveTranscriptInClipboard
        // Sync with legacy key consumed at runtime by CursorPaster.
        UserDefaults.hoah.set(state.preserveTranscriptInClipboard, forKey: "preserveTranscriptInClipboard")
        self.maxRecordingDurationMinutes = state.maxRecordingDurationMinutes
        self.selectedHotkey1 = state.selectedHotkey1
        self.selectedHotkey2 = state.selectedHotkey2
        self.isMiddleClickToggleEnabled = state.isMiddleClickToggleEnabled
        self.middleClickActivationDelay = state.middleClickActivationDelay
        self.isSoundFeedbackEnabled = state.isSoundFeedbackEnabled
        self.isSystemMuteEnabled = state.isSystemMuteEnabled
        self._isAIEnhancementEnabled = state.isAIEnhancementEnabled // Initialize storage
        self.isClipboardEnhancementShortcutsEnabled = state.isClipboardEnhancementShortcutsEnabled
        self._selectedPromptId = state.selectedPromptId // Initialize storage
        self.useScreenCaptureContext = state.useScreenCaptureContext
        self.userProfileContext = state.userProfileContext
        self.arePromptTriggersEnabled = false
        if let storedTarget = state.translationTargetLanguage?.trimmingCharacters(in: .whitespacesAndNewlines),
           !storedTarget.isEmpty {
            self.translationTargetLanguage = storedTarget
        } else {
            self.translationTargetLanguage = Self.defaultTranslationTarget(for: state.appInterfaceLanguage)
        }
        self.showOriginalTextInTranslation = state.showOriginalTextInTranslation
        self.showOriginalTextInQA = state.showOriginalTextInQA
        // Load saved translation languages from state, with migration from UserDefaults
        let legacyValue = UserDefaults.hoah.string(forKey: TranslationTargetPresets.savedLanguagesKey)
        if let legacy = legacyValue,
           state.savedTranslationLanguagesRaw == TranslationTargetPresets.defaultSavedLanguagesRaw,
           legacy != TranslationTargetPresets.defaultSavedLanguagesRaw {
            // Migrate from legacy @AppStorage
            self.savedTranslationLanguagesRaw = legacy
        } else {
            self.savedTranslationLanguagesRaw = state.savedTranslationLanguagesRaw
        }
        // Second translation mode settings
        self.isSecondTranslationEnabled = state.isSecondTranslationEnabled
        if let storedTarget2 = state.translationTargetLanguage2?.trimmingCharacters(in: .whitespacesAndNewlines),
           !storedTarget2.isEmpty {
            self.translationTargetLanguage2 = storedTarget2
        } else {
            self.translationTargetLanguage2 = Self.defaultTranslationTarget(for: state.appInterfaceLanguage)
        }
        self.showOriginalTextInTranslation2 = state.showOriginalTextInTranslation2
        self.isPolishFormalWritingEnabled = state.isPolishFormalWritingEnabled
        self.isPolishProfessionalEnabled = state.isPolishProfessionalEnabled
        self.hasCompletedPolishModeMigration = state.hasCompletedPolishModeMigration
        self._selectedAIProvider = state.selectedAIProvider // Initialize storage
        self.bedrockRegion = state.bedrockRegion
        self.bedrockModelId = state.bedrockModelId
        self._selectedModels = state.selectedModels // Initialize storage
        self.aiEnhancementConfigurations = state.aiEnhancementConfigurations
        self.activeAIConfigurationId = state.activeAIConfigurationId
        self.hasCompletedAIConfigMigration = state.hasCompletedAIConfigMigration
        self.isAutoExportEnabled = state.isAutoExportEnabled
        // Sync auto export state to UserDefaults for AutoExportService
        UserDefaults.hoah.set(state.isAutoExportEnabled, forKey: "isAutoExportEnabled")
        
        // Default selected prompt to Polish if none set (prevents unintended translation defaults)
        if _selectedPromptId == nil {
            _selectedPromptId = PredefinedPrompts.polishPromptId.uuidString
        }
        
        // Validate AI configurations on load
        validateAIConfigurations()
        validateMaxRecordingDuration()
        
        logger.info("AppSettingsStore initialized")
    }
    
    // MARK: - Validation Methods
    
    /// Validates language setting and corrects if invalid
    private func validateLanguage() {
        let validLanguages = ["system", "en", "zh-Hans"]
        if !validLanguages.contains(appInterfaceLanguage) {
            logger.warning("Invalid language '\(self.appInterfaceLanguage)', resetting to 'system'")
            appInterfaceLanguage = "system"
        }
    }

    /// Validates UI theme and corrects if invalid
    private func validateTheme() {
        let validThemes = ["basic", "liquidGlass", "cyberpunk", "vintage"]
        if !validThemes.contains(uiTheme) {
            logger.warning("Invalid theme '\(self.uiTheme)', resetting to 'basic'")
            uiTheme = "basic"
        }
    }
    
    /// Validates recorder type and corrects if invalid
    private func validateRecorderType() {
        if recorderType != "mini" && recorderType != "notch" {
            logger.warning("Invalid recorder type '\(self.recorderType)', resetting to 'mini'")
            recorderType = "mini"
        }
    }
    
    /// Validates hotkey settings and resolves conflicts
    /// Ensures hotkey1 and hotkey2 are not the same (except "none")
    private func validateHotkeys() {
        // Check for conflicts between hotkey1 and hotkey2
        if selectedHotkey1 != "none" && 
           selectedHotkey2 != "none" && 
           selectedHotkey1 == selectedHotkey2 {
            logger.warning("Hotkey conflict detected, disabling hotkey2")
            selectedHotkey2 = "none"
        }
    }
    
    /// Validates and clamps the maximum recording duration (0-180 minutes, 0 = unlimited)
    private func validateMaxRecordingDuration() {
        if maxRecordingDurationMinutes < 0 {
            logger.warning("Max recording duration too low, setting to no limit (0)")
            maxRecordingDurationMinutes = 0
        } else if maxRecordingDurationMinutes > 180 {
            logger.warning("Max recording duration too high, setting to 180 minutes")
            maxRecordingDurationMinutes = 180
        }
    }
    
    /// Validates AI Enhancement configurations on load
    /// Ensures active configuration is valid, selects fallback if needed
    private func validateAIConfigurations() {
        // Log validation status for each configuration
        for config in aiEnhancementConfigurations {
            if !config.isValid {
                logger.warning("Invalid AI configuration '\(config.name)': \(config.validationErrors.joined(separator: ", "))")
            }
        }
        
        // Check if active configuration exists and is valid
        if let activeId = activeAIConfigurationId {
            if let activeConfig = aiEnhancementConfigurations.first(where: { $0.id == activeId }) {
                if !activeConfig.isValid {
                    logger.warning("Active AI configuration '\(activeConfig.name)' is invalid, selecting fallback")
                    selectFallbackConfiguration()
                }
            } else {
                logger.warning("Active AI configuration ID not found, selecting fallback")
                selectFallbackConfiguration()
            }
        }
    }
    
    /// Selects a fallback configuration when the active one is invalid or missing
    private func selectFallbackConfiguration() {
        if let firstValid = validAIConfigurations.first {
            activeAIConfigurationId = firstValid.id
            logger.info("Selected fallback AI configuration: \(firstValid.name)")
        } else {
            activeAIConfigurationId = nil
            logger.info("No valid AI configurations available")
        }
    }
    
    /// Validates delay and corrects if out of range (0-5000ms)
    private func validateDelay() {
        if middleClickActivationDelay < 0 {
            logger.warning("Negative delay detected, setting to 0")
            middleClickActivationDelay = 0
        } else if middleClickActivationDelay > 5000 {
            logger.warning("Delay too large, setting to 5000")
            middleClickActivationDelay = 5000
        }
    }
    
    /// Validates AI provider and corrects if invalid
    /// Note: Custom and ElevenLabs have been removed from AIProvider enum
    private func validateProvider() {
        let validProviders = ["AWS Bedrock", "OCI Generative AI", "Cerebras", "GROQ", "Gemini", "Anthropic",
                             "OpenAI", "Azure OpenAI", "OpenRouter"]
        if !validProviders.contains(selectedAIProvider) {
            // Migrate legacy providers to Gemini
            if selectedAIProvider == "Custom" || selectedAIProvider == "ElevenLabs" {
                logger.warning("Legacy provider '\(self.selectedAIProvider)' no longer supported, migrating to 'Gemini'")
            } else {
                logger.warning("Invalid provider '\(self.selectedAIProvider)', resetting to 'Gemini'")
            }
            selectedAIProvider = "Gemini"
        }
    }
    
    /// Handles AI enhancement state change
    /// Ensures consistent state (e.g., disables triggers when AI is disabled)
    private func handleAIEnhancementChange() {
        // Cannot enable AI Enhancement without a valid configuration
        if _isAIEnhancementEnabled && validAIConfigurations.isEmpty {
            logger.warning("Cannot enable AI Enhancement: no valid configurations available")
            _isAIEnhancementEnabled = false
            return
        }
        
        // If enabling AI but no active configuration, select the first valid one
        if _isAIEnhancementEnabled && activeAIConfigurationId == nil {
            if let firstValid = validAIConfigurations.first {
                activeAIConfigurationId = firstValid.id
                logger.info("Auto-selected AI configuration: \(firstValid.name)")
            }
        }
        
        // If enabling AI but no prompt selected, log warning
        // Coordinator will handle selecting default prompt
        if _isAIEnhancementEnabled && selectedPromptId == nil {
            logger.info("AI enabled without prompt, coordinator will select default")
        }
        
        // If disabling AI, also disable prompt triggers
        if !_isAIEnhancementEnabled && arePromptTriggersEnabled {
            logger.info("Disabling prompt triggers with AI enhancement")
            arePromptTriggersEnabled = false
        }
    }

    // MARK: - Batch Update Methods
    
    /// Attempts to enable AI enhancement
    /// - Returns: true if successful, false if no valid configuration exists
    func tryEnableAIEnhancement() -> Bool {
        if validAIConfigurations.isEmpty {
            logger.warning("Cannot enable AI Enhancement: no valid configurations available")
            return false
        }
        isAIEnhancementEnabled = true
        return true
    }
    
    /// Updates AI settings atomically to avoid intermediate invalid states
    /// - Parameters:
    ///   - enabled: Whether to enable AI enhancement
    ///   - promptId: The prompt ID to use (optional)
    func updateAISettings(enabled: Bool, promptId: String?) {
        var finalPromptId = promptId
        
        // Validate: if enabling, should have a prompt
        if enabled && finalPromptId == nil {
            logger.warning("Enabling AI without prompt, coordinator should provide default")
        }
        
        // Atomic update (no intermediate state)
        isAIEnhancementEnabled = enabled
        selectedPromptId = finalPromptId
        
        logger.info("AI settings updated: enabled=\(enabled), promptId=\(finalPromptId ?? "nil")")
    }
    
    /// Updates hotkey settings with automatic conflict resolution
    /// - Parameters:
    ///   - hotkey1: Primary hotkey
    ///   - hotkey2: Secondary hotkey
    func updateHotkeySettings(hotkey1: String, hotkey2: String) {
        var finalHotkey2 = hotkey2
        
        // Resolve conflicts: hotkey1 and hotkey2 cannot be the same
        if hotkey1 != "none" && hotkey2 != "none" && hotkey1 == hotkey2 {
            logger.warning("Hotkey conflict, setting hotkey2 to none")
            finalHotkey2 = "none"
        }
        
        // Atomic update
        selectedHotkey1 = hotkey1
        selectedHotkey2 = finalHotkey2
        
        logger.info("Hotkey settings updated: hotkey1=\(hotkey1), hotkey2=\(finalHotkey2)")
    }
    
    /// Resets all system settings to defaults while preserving AI configurations
    /// - Note: Preserves API keys, models, providers, prompts, user profile, AND shortcuts.
    func resetSystemSettings() {
        // 1. Create a fresh state with default values
        var newState = AppSettingsState()
        
        // 2. RESTORE settings that should NOT be reset
        
        // A. Identity & Keys (Preserve Provider & Model selections from STORAGE)
        newState.selectedAIProvider = self._selectedAIProvider 
        newState.selectedModels = self._selectedModels
        newState.bedrockRegion = self.bedrockRegion
        newState.bedrockModelId = self.bedrockModelId
        newState.aiEnhancementConfigurations = self.aiEnhancementConfigurations
        newState.activeAIConfigurationId = self.activeAIConfigurationId
        newState.hasCompletedAIConfigMigration = self.hasCompletedAIConfigMigration
        
        // B. AI State: reset to default prompt (Polish), keep AI disabled by default
        newState.selectedPromptId = PredefinedPrompts.polishPromptId.uuidString
        
        // C. User Content (Preserve User Profile Context)
        newState.userProfileContext = self.userProfileContext
        
        // D. Shortcuts & Triggers (PRESERVE User's Control Scheme)
        newState.selectedHotkey1 = self.selectedHotkey1
        newState.selectedHotkey2 = self.selectedHotkey2
        newState.isMiddleClickToggleEnabled = self.isMiddleClickToggleEnabled
        newState.middleClickActivationDelay = self.middleClickActivationDelay
        newState.isClipboardEnhancementShortcutsEnabled = self.isClipboardEnhancementShortcutsEnabled
        
        // E. App State (Preserve Onboarding status)
        newState.hasCompletedOnboarding = self.hasCompletedOnboarding
        
        // 3. Apply the new state
        // This effectively resets ONLY:
        // - Language
        // - Interface Style (Dock icon, Recorder type)
        // - Audio/Recording Behaviors (Sound feedback, Mute, Clipboard preservation)
        // - Context Awareness Toggles (Clipboard/Screen/Selection usage defaults to OFF)
        
        applyState(newState)
        saveSettings()
        
        logger.info("System settings reset to defaults. Preserved: AI Config, User Profile, Shortcuts.")

        // 4. Post notification for UI updates
        NotificationCenter.default.post(name: .languageDidChange, object: nil)

        // 5. Reset NavigationSplitView/NSSplitView column widths
        // SwiftUI stores these in UserDefaults.standard, not the app group
        // validate-defaults: allow-standard
        let standardDefaults = UserDefaults.standard
        for key in standardDefaults.dictionaryRepresentation().keys {
            if key.contains("NSSplitView") {
                standardDefaults.removeObject(forKey: key)
            }
        }
    }
    
    // MARK: - AI Configuration Management
    
    /// Adds a new AI Enhancement configuration
    func addConfiguration(_ config: AIEnhancementConfiguration) {
        aiEnhancementConfigurations.append(config)
        logger.info("Added AI configuration: \(config.name)")
    }
    
    /// Updates an existing AI Enhancement configuration
    func updateConfiguration(_ config: AIEnhancementConfiguration) {
        if let index = aiEnhancementConfigurations.firstIndex(where: { $0.id == config.id }) {
            aiEnhancementConfigurations[index] = config
            logger.info("Updated AI configuration: \(config.name)")
            
            // If updated config is the active one, notify services to rebuild runtime state
            if config.id == activeAIConfigurationId {
                NotificationCenter.default.post(name: .activeAIConfigurationChanged, object: nil)
            }
        }
    }
    
    /// Deletes an AI Enhancement configuration
    func deleteConfiguration(id: UUID) {
        let wasActiveConfig = (activeAIConfigurationId == id)
        
        aiEnhancementConfigurations.removeAll { $0.id == id }
        
        // If deleted config was active, select another valid one
        if wasActiveConfig {
            activeAIConfigurationId = validAIConfigurations.first?.id
            logger.info("Active config deleted, selected fallback: \(self.activeAIConfigurationId?.uuidString ?? "none")")
            
            // Notify services to rebuild runtime state with new active configuration
            NotificationCenter.default.post(name: .activeAIConfigurationChanged, object: nil)
        }
        
        // If no configurations left, force disable AI Enhancement
        if aiEnhancementConfigurations.isEmpty {
            logger.info("All AI configurations deleted, disabling AI Enhancement")
            _isAIEnhancementEnabled = false
            arePromptTriggersEnabled = false
            
            // Notify services to clear runtime state
            NotificationCenter.default.post(name: .activeAIConfigurationChanged, object: nil)
        }
        
        logger.info("Deleted AI configuration: \(id)")
    }
    
    /// Sets the active AI Enhancement configuration
    func setActiveConfiguration(id: UUID) {
        guard aiEnhancementConfigurations.contains(where: { $0.id == id }) else {
            logger.warning("Cannot set active config: ID not found")
            return
        }
        activeAIConfigurationId = id
        logger.info("Set active AI configuration: \(id)")
    }
    
    // MARK: - Polish Mode Migration
    
    /// Migrates users from legacy Writing/Professional mode selections to Polish mode with toggles
    /// This should be called on app launch after loading settings
    func performPolishModeMigration() {
        guard !hasCompletedPolishModeMigration else { return }
        
        guard let selectedId = _selectedPromptId else {
            hasCompletedPolishModeMigration = true
            return
        }
        
        let formalPromptIdString = PredefinedPrompts.formalPromptId.uuidString
        let professionalPromptIdString = PredefinedPrompts.professionalPromptId.uuidString
        let polishPromptIdString = PredefinedPrompts.polishPromptId.uuidString
        
        if selectedId == formalPromptIdString {
            // User had Writing mode selected → migrate to Polish with Formal Writing enabled
            _selectedPromptId = polishPromptIdString
            isPolishFormalWritingEnabled = true
            logger.info("Migrated from Writing mode to Polish mode with Formal Writing enabled")
        } else if selectedId == professionalPromptIdString {
            // User had Professional mode selected → migrate to Polish with Professional enabled
            _selectedPromptId = polishPromptIdString
            isPolishProfessionalEnabled = true
            logger.info("Migrated from Professional mode to Polish mode with Professional enabled")
        }
        
        hasCompletedPolishModeMigration = true
        saveSettings()
    }
    
    // MARK: - Private Methods
    
    /// Loads settings from state, applying validation and safe defaults if needed
    /// - Parameter state: The state to load
    private func loadFromState(_ state: AppSettingsState) {
        // Validate before loading
        let validation = state.validate()
        if !validation.isValid {
            logger.warning("Invalid settings detected: \(validation.errors.joined(separator: ", "))")
            let safeState = state.withSafeDefaults()
            applyState(safeState)
        } else {
            applyState(state)
        }
    }
    
    /// Applies state to all published properties
    /// Note: This updates storage properties directly to avoid triggering saveSettings() multiple times via setters
    /// - Parameter state: The state to apply
    private func applyState(_ state: AppSettingsState) {
        hasCompletedOnboarding = state.hasCompletedOnboarding
        _appInterfaceLanguage = state.appInterfaceLanguage // Storage
        uiTheme = state.uiTheme
        isMenuBarOnly = state.isMenuBarOnly
        recorderType = state.recorderType
        preserveTranscriptInClipboard = state.preserveTranscriptInClipboard
        maxRecordingDurationMinutes = state.maxRecordingDurationMinutes
        selectedHotkey1 = state.selectedHotkey1
        selectedHotkey2 = state.selectedHotkey2
        isMiddleClickToggleEnabled = state.isMiddleClickToggleEnabled
        middleClickActivationDelay = state.middleClickActivationDelay
        isSoundFeedbackEnabled = state.isSoundFeedbackEnabled
        isSystemMuteEnabled = state.isSystemMuteEnabled
        _isAIEnhancementEnabled = state.isAIEnhancementEnabled // Storage
        isClipboardEnhancementShortcutsEnabled = state.isClipboardEnhancementShortcutsEnabled
        _selectedPromptId = state.selectedPromptId // Storage
        useScreenCaptureContext = state.useScreenCaptureContext
        userProfileContext = state.userProfileContext
        arePromptTriggersEnabled = false
        if let storedTarget = state.translationTargetLanguage?.trimmingCharacters(in: .whitespacesAndNewlines),
           !storedTarget.isEmpty {
            translationTargetLanguage = storedTarget
        } else {
            translationTargetLanguage = Self.defaultTranslationTarget(for: state.appInterfaceLanguage)
        }
        showOriginalTextInTranslation = state.showOriginalTextInTranslation
        showOriginalTextInQA = state.showOriginalTextInQA
        savedTranslationLanguagesRaw = state.savedTranslationLanguagesRaw
        UserDefaults.hoah.set(savedTranslationLanguagesRaw, forKey: TranslationTargetPresets.savedLanguagesKey)
        // Second translation mode settings
        isSecondTranslationEnabled = state.isSecondTranslationEnabled
        if let storedTarget2 = state.translationTargetLanguage2?.trimmingCharacters(in: .whitespacesAndNewlines),
           !storedTarget2.isEmpty {
            translationTargetLanguage2 = storedTarget2
        } else {
            translationTargetLanguage2 = Self.defaultTranslationTarget(for: state.appInterfaceLanguage)
        }
        showOriginalTextInTranslation2 = state.showOriginalTextInTranslation2
        isPolishFormalWritingEnabled = state.isPolishFormalWritingEnabled
        isPolishProfessionalEnabled = state.isPolishProfessionalEnabled
        hasCompletedPolishModeMigration = state.hasCompletedPolishModeMigration
        _selectedAIProvider = state.selectedAIProvider // Storage
        bedrockRegion = state.bedrockRegion
        bedrockModelId = state.bedrockModelId
        _selectedModels = state.selectedModels // Storage
        aiEnhancementConfigurations = state.aiEnhancementConfigurations
        activeAIConfigurationId = state.activeAIConfigurationId
        hasCompletedAIConfigMigration = state.hasCompletedAIConfigMigration
    }
    
    // MARK: - Persistence
    
    /// Saves current settings to storage
    private func saveSettings() {
        let state = currentState()
        storage.save(state)
        syncLegacyUserDefaults(from: state)
    }

    /// Keeps legacy UserDefaults keys synchronized for runtime paths that still read them directly.
    /// This avoids behavior drift while we migrate all callers to AppSettingsStore.
    private func syncLegacyUserDefaults(from state: AppSettingsState) {
        UserDefaults.hoah.set(state.hasCompletedOnboarding, forKey: "HasCompletedOnboarding")
        UserDefaults.hoah.set(state.appInterfaceLanguage, forKey: "AppInterfaceLanguage")
        UserDefaults.hoah.set(state.isMenuBarOnly, forKey: "IsMenuBarOnly")
        UserDefaults.hoah.set(state.recorderType, forKey: "RecorderType")
        UserDefaults.hoah.set(state.preserveTranscriptInClipboard, forKey: "preserveTranscriptInClipboard")
        UserDefaults.hoah.set(state.selectedHotkey1, forKey: "selectedHotkey1")
        UserDefaults.hoah.set(state.selectedHotkey2, forKey: "selectedHotkey2")
        UserDefaults.hoah.set(state.isMiddleClickToggleEnabled, forKey: "isMiddleClickToggleEnabled")
        UserDefaults.hoah.set(state.middleClickActivationDelay, forKey: "middleClickActivationDelay")
        UserDefaults.hoah.set(state.isSoundFeedbackEnabled, forKey: "isSoundFeedbackEnabled")
        UserDefaults.hoah.set(state.isSystemMuteEnabled, forKey: "isSystemMuteEnabled")
        UserDefaults.hoah.set(state.isAIEnhancementEnabled, forKey: "isAIEnhancementEnabled")
        UserDefaults.hoah.set(state.isClipboardEnhancementShortcutsEnabled, forKey: "isClipboardEnhancementShortcutsEnabled")
        if let promptId = state.selectedPromptId {
            UserDefaults.hoah.set(promptId, forKey: "selectedPromptId")
        } else {
            UserDefaults.hoah.removeObject(forKey: "selectedPromptId")
        }
        UserDefaults.hoah.set(state.useScreenCaptureContext, forKey: "useScreenCaptureContext")
        UserDefaults.hoah.set(state.userProfileContext, forKey: "userProfileContext")
        UserDefaults.hoah.set(state.selectedAIProvider, forKey: "selectedAIProvider")
        UserDefaults.hoah.set(state.bedrockRegion, forKey: "AWSBedrockRegion")
        UserDefaults.hoah.set(state.bedrockModelId, forKey: "AWSBedrockModelId")
        UserDefaults.hoah.set(state.isAutoExportEnabled, forKey: "isAutoExportEnabled")
        UserDefaults.hoah.set(state.savedTranslationLanguagesRaw, forKey: TranslationTargetPresets.savedLanguagesKey)

        for (provider, model) in state.selectedModels {
            UserDefaults.hoah.set(model, forKey: "\(provider)SelectedModel")
        }
    }
    
    /// Creates an AppSettingsState from current property values
    /// - Returns: Current state snapshot using underlying STORAGE values
    private func currentState() -> AppSettingsState {
        return AppSettingsState(
            hasCompletedOnboarding: hasCompletedOnboarding,
            appInterfaceLanguage: _appInterfaceLanguage,
            uiTheme: uiTheme,
            isMenuBarOnly: isMenuBarOnly,
            recorderType: recorderType,
            preserveTranscriptInClipboard: preserveTranscriptInClipboard,
            maxRecordingDurationMinutes: maxRecordingDurationMinutes,
            selectedHotkey1: selectedHotkey1,
            selectedHotkey2: selectedHotkey2,
            isMiddleClickToggleEnabled: isMiddleClickToggleEnabled,
            middleClickActivationDelay: middleClickActivationDelay,
            isSoundFeedbackEnabled: isSoundFeedbackEnabled,
            isSystemMuteEnabled: isSystemMuteEnabled,
            // isPauseMediaEnabled removed
            isAIEnhancementEnabled: _isAIEnhancementEnabled,
            isClipboardEnhancementShortcutsEnabled: isClipboardEnhancementShortcutsEnabled,
            selectedPromptId: _selectedPromptId,
            useScreenCaptureContext: useScreenCaptureContext,
            userProfileContext: userProfileContext,
            arePromptTriggersEnabled: arePromptTriggersEnabled,
            translationTargetLanguage: translationTargetLanguage,
            showOriginalTextInTranslation: showOriginalTextInTranslation,
            showOriginalTextInQA: showOriginalTextInQA,
            savedTranslationLanguagesRaw: savedTranslationLanguagesRaw,
            isSecondTranslationEnabled: isSecondTranslationEnabled,
            translationTargetLanguage2: translationTargetLanguage2,
            showOriginalTextInTranslation2: showOriginalTextInTranslation2,
            isPolishFormalWritingEnabled: isPolishFormalWritingEnabled,
            isPolishProfessionalEnabled: isPolishProfessionalEnabled,
            hasCompletedPolishModeMigration: hasCompletedPolishModeMigration,
            selectedAIProvider: _selectedAIProvider,
            bedrockRegion: bedrockRegion,
            bedrockModelId: bedrockModelId,
            selectedModels: _selectedModels,
            aiEnhancementConfigurations: aiEnhancementConfigurations,
            activeAIConfigurationId: activeAIConfigurationId,
            hasCompletedAIConfigMigration: hasCompletedAIConfigMigration,
            isAutoExportEnabled: isAutoExportEnabled
        )
    }
}
