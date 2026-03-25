import SwiftUI
import SwiftData
import AppKit
import OSLog
import AppIntents
import KeyboardShortcuts
import LaunchAtLogin

// State Management: All user settings are managed by AppSettingsStore.
// To modify settings, update AppSettingsStore properties.
// Do not use @AppStorage or direct UserDefaults access elsewhere in the app.

@main
struct HoAhApp: App {
    private static let appSupportIdentifier = "com.yangzichao.hoah"
    private static let swiftDataStoreName = "default.store"
    private static let swiftDataMigrationKey = "SwiftDataStoreMigratedToAppGroup"
    
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    let container: ModelContainer
    let containerInitializationFailed: Bool
    
    // Centralized State Management
    @StateObject private var appSettings: AppSettingsStore
    @StateObject private var settingsCoordinator: SettingsCoordinator
    
    @StateObject private var whisperState: WhisperState
    @StateObject private var hotkeyManager: HotkeyManager
    @StateObject private var menuBarManager: MenuBarManager
    @StateObject private var aiService = AIService()
    @StateObject private var enhancementService: AIEnhancementService
    @StateObject private var configValidationService = ConfigurationValidationService()
    @StateObject private var localizationManager = LocalizationManager()
    @State private var showMenuBarIcon = true
    
    // Audio cleanup manager for automatic deletion of old audio files
    private let audioCleanupManager = AudioCleanupManager.shared
    
    // Transcription auto-cleanup service for zero data retention
    private let transcriptionAutoCleanupService = TranscriptionAutoCleanupService.shared
    
    init() {
        UserDefaults.migrateToAppGroupIfNeeded()

        // Configure KeyboardShortcuts localization
        // Note: KeyboardShortcuts.Localization may not be available in all versions
        // KeyboardShortcuts.Localization.recordShortcut = NSLocalizedString("Record Shortcut", comment: "")
        // KeyboardShortcuts.Localization.pressShortcut = NSLocalizedString("Press Shortcut", comment: "")

        let logger = Logger(subsystem: "com.yangzichao.hoah", category: "Initialization")
        
        // Initialize centralized state management
        let appSettings = AppSettingsStore()
        _appSettings = StateObject(wrappedValue: appSettings)

        UIStyleConsistencyChecker.recordAndCompare(theme: ThemePalette.theme(for: appSettings.uiTheme))
        
        let settingsCoordinator = SettingsCoordinator(store: appSettings)
        _settingsCoordinator = StateObject(wrappedValue: settingsCoordinator)
        
        let schema = Schema([Transcription.self])
        var initializationFailed = false
        
        // Attempt 1: Try persistent storage
        if let persistentContainer = Self.createPersistentContainer(schema: schema, logger: logger) {
            container = persistentContainer
            
            #if DEBUG
            // Print SwiftData storage location in debug builds only
            if let url = persistentContainer.mainContext.container.configurations.first?.url {
                print("💾 SwiftData storage location: \(url.path)")
            }
            #endif
        }
        // Attempt 2: Try in-memory storage
        else if let memoryContainer = Self.createInMemoryContainer(schema: schema, logger: logger) {
            container = memoryContainer
            
            logger.warning("Using in-memory storage as fallback. Data will not persist between sessions.")
            
            // Show alert to user about storage issue
            DispatchQueue.main.async {
                let alert = NSAlert()
                alert.messageText = "Storage Warning"
                alert.informativeText = "HoAh couldn't access its storage location. Your transcriptions will not be saved between sessions."
                alert.alertStyle = .warning
                alert.addButton(withTitle: "OK")
                alert.runModal()
            }
        }
        // Attempt 3: Try ultra-minimal default container
        else if let minimalContainer = Self.createMinimalContainer(schema: schema, logger: logger) {
            container = minimalContainer
            logger.warning("Using minimal emergency container")
        }
        // All attempts failed: Create disabled container and mark for termination
        else {
            logger.critical("All ModelContainer initialization attempts failed")
            initializationFailed = true
            
            // Create a dummy container to satisfy Swift's initialization requirements
            // App will show error and terminate in onAppear
            container = Self.createDummyContainer(schema: schema)
        }
        
        containerInitializationFailed = initializationFailed
        
        // Initialize services with proper sharing of instances
        let aiService = AIService()
        _aiService = StateObject(wrappedValue: aiService)
        
        let enhancementService = AIEnhancementService(aiService: aiService, modelContext: container.mainContext)
        _enhancementService = StateObject(wrappedValue: enhancementService)
        
        let whisperState = WhisperState(modelContext: container.mainContext, enhancementService: enhancementService)
        whisperState.appSettings = appSettings
        _whisperState = StateObject(wrappedValue: whisperState)
        
        let hotkeyManager = HotkeyManager(whisperState: whisperState, appSettings: appSettings)
        _hotkeyManager = StateObject(wrappedValue: hotkeyManager)
        
        let menuBarManager = MenuBarManager()
        _menuBarManager = StateObject(wrappedValue: menuBarManager)
        appDelegate.menuBarManager = menuBarManager
        appDelegate.appSettings = appSettings
        
        // Ensure no lingering recording state from previous runs
        Task {
            await whisperState.resetOnLaunch()
        }
        
        
        AppShortcuts.updateAppShortcutParameters()

        // Enable Launch at Login by default on first install
        if !UserDefaults.hoah.bool(forKey: "HasConfiguredLaunchAtLogin") {
            LaunchAtLogin.isEnabled = true
            UserDefaults.hoah.set(true, forKey: "HasConfiguredLaunchAtLogin")
        }
        
        #if DEBUG
        // DEVELOPMENT: Force onboarding to show for testing
        // Uncomment the line below to reset onboarding state on every launch
        // appSettings.hasCompletedOnboarding = false // DEBUG: Force onboarding
        #endif
    }
    
    // MARK: - Container Creation Helpers
    
    private static func createPersistentContainer(schema: Schema, logger: Logger) -> ModelContainer? {
        do {
            if let appGroupSupportURL = Self.appGroupSupportDirectory(logger: logger) {
                let storeURL = appGroupSupportURL.appendingPathComponent(swiftDataStoreName)
                Self.migrateSwiftDataStoreIfNeeded(targetStoreURL: storeURL, logger: logger)
                let modelConfiguration = ModelConfiguration(schema: schema, url: storeURL)
                return try ModelContainer(for: schema, configurations: [modelConfiguration])
            }

            // Create app-specific Application Support directory URL
            let baseSupportDirectory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            let appSupportURL = Self.prepareAppSupportDirectory(baseDirectory: baseSupportDirectory, logger: logger)
            
            // Configure SwiftData to use the conventional location
            let storeURL = appSupportURL.appendingPathComponent(swiftDataStoreName)
            let modelConfiguration = ModelConfiguration(schema: schema, url: storeURL)
            
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            logger.error("Failed to create persistent ModelContainer: \(error.localizedDescription)")
            return nil
        }
    }
    
    private static func createInMemoryContainer(schema: Schema, logger: Logger) -> ModelContainer? {
        do {
            let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
            return try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            logger.error("Failed to create in-memory ModelContainer: \(error.localizedDescription)")
            return nil
        }
    }
    
    private static func createMinimalContainer(schema: Schema, logger: Logger) -> ModelContainer? {
        do {
            // Try default initializer without custom configuration
            return try ModelContainer(for: schema)
        } catch {
            logger.error("Failed to create minimal ModelContainer: \(error.localizedDescription)")
            return nil
        }
    }
    
    private static func prepareAppSupportDirectory(baseDirectory: URL, logger: Logger) -> URL {
        let fileManager = FileManager.default
        let appSupportURL = baseDirectory.appendingPathComponent(appSupportIdentifier, isDirectory: true)
        
        if !fileManager.fileExists(atPath: appSupportURL.path) {
            do {
                try fileManager.createDirectory(at: appSupportURL, withIntermediateDirectories: true)
                logger.notice("Created HoAh app support directory: \(appSupportURL.path)")
            } catch {
                logger.error("Failed to create HoAh app support directory: \(error.localizedDescription)")
            }
        }
        
        return appSupportURL
    }

    private static func appGroupSupportDirectory(logger: Logger) -> URL? {
        guard let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: AppGroup.identifier) else {
            logger.error("Missing App Group container URL for \(AppGroup.identifier)")
            return nil
        }

        let supportURL = containerURL
            .appendingPathComponent("Application Support", isDirectory: true)
            .appendingPathComponent(appSupportIdentifier, isDirectory: true)
        let fileManager = FileManager.default

        if !fileManager.fileExists(atPath: supportURL.path) {
            do {
                try fileManager.createDirectory(at: supportURL, withIntermediateDirectories: true)
                logger.notice("Created App Group support directory: \(supportURL.path)")
            } catch {
                logger.error("Failed to create App Group support directory: \(error.localizedDescription)")
            }
        }

        return supportURL
    }

    private static func migrateSwiftDataStoreIfNeeded(targetStoreURL: URL, logger: Logger) {
        // Migration disabled to avoid touching legacy container paths that can trigger
        // AppData prompts on non-sandbox builds. Keep target store usage only.
        return
        
        let defaults = UserDefaults.hoah
        if defaults.bool(forKey: swiftDataMigrationKey) {
            return
        }

        let fileManager = FileManager.default
        if fileManager.fileExists(atPath: targetStoreURL.path) {
            defaults.set(true, forKey: swiftDataMigrationKey)
            return
        }

        let legacyStoreURLs = legacyStoreCandidates().filter { $0.path != targetStoreURL.path }
        var migrated = false

        for legacyStoreURL in legacyStoreURLs {
            if !fileManager.fileExists(atPath: legacyStoreURL.path) {
                continue
            }

            do {
                try fileManager.createDirectory(at: targetStoreURL.deletingLastPathComponent(), withIntermediateDirectories: true)
                try copyStoreFiles(from: legacyStoreURL, to: targetStoreURL)
                logger.notice("Migrated SwiftData store from \(legacyStoreURL.path) to \(targetStoreURL.path)")
                migrated = true
                break
            } catch {
                logger.error("Failed to migrate SwiftData store from \(legacyStoreURL.path): \(error.localizedDescription)")
            }
        }

        if !migrated {
            logger.notice("No legacy SwiftData store found for migration")
        }

        defaults.set(true, forKey: swiftDataMigrationKey)
    }

    private static func legacyStoreCandidates() -> [URL] {
        let baseSupportDirectory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let legacySupportURL = baseSupportDirectory.appendingPathComponent(appSupportIdentifier, isDirectory: true)
        let legacyStore = legacySupportURL.appendingPathComponent(swiftDataStoreName)

        let sandboxSupportURL = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Containers/\(appSupportIdentifier)/Data/Library/Application Support", isDirectory: true)
            .appendingPathComponent(appSupportIdentifier, isDirectory: true)
        let sandboxStore = sandboxSupportURL.appendingPathComponent(swiftDataStoreName)

        if legacyStore.path == sandboxStore.path {
            return [legacyStore]
        }

        return [legacyStore, sandboxStore]
    }

    private static func copyStoreFiles(from sourceStoreURL: URL, to targetStoreURL: URL) throws {
        let fileManager = FileManager.default
        let suffixes = ["", "-wal", "-shm"]

        for suffix in suffixes {
            let source = URL(fileURLWithPath: sourceStoreURL.path + suffix)
            let destination = URL(fileURLWithPath: targetStoreURL.path + suffix)
            if fileManager.fileExists(atPath: source.path) {
                if fileManager.fileExists(atPath: destination.path) {
                    try fileManager.removeItem(at: destination)
                }
                try fileManager.copyItem(at: source, to: destination)
            }
        }
    }
    
    private static func createDummyContainer(schema: Schema) -> ModelContainer {
        // Create an absolute minimal container for initialization
        // This uses in-memory storage and will never actually be used
        // as the app will show an error and terminate in onAppear
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        
        // Note: In-memory containers should always succeed unless SwiftData itself is unavailable
        // (which would indicate a serious system-level issue). We use preconditionFailure here
        // rather than fatalError because:
        // 1. This code is only reached after 3 prior initialization attempts have failed
        // 2. An in-memory container failing indicates SwiftData is completely unavailable
        // 3. Swift requires non-optional container property to be initialized
        // 4. The app will immediately terminate in onAppear when containerInitializationFailed is checked
        do {
            return try ModelContainer(for: schema, configurations: [config])
        } catch {
            // This indicates a system-level SwiftData failure - app cannot function
            preconditionFailure("Unable to create even a dummy ModelContainer. SwiftData is unavailable: \(error)")
        }
    }
    
    var body: some Scene {
        WindowGroup {
            ZStack {
                ContentView()
                
                if !appSettings.hasCompletedOnboarding {
                    OnboardingView(hasCompletedOnboarding: $appSettings.hasCompletedOnboarding)
                        .transition(.opacity)
                        .background(
                            OnboardingWindowLevelModifier()
                        )
                }
            }
            .environmentObject(appSettings)
            .environmentObject(settingsCoordinator)
            .environmentObject(whisperState)
            .environmentObject(hotkeyManager)
            .environmentObject(menuBarManager)
            .environmentObject(aiService)
            .environmentObject(enhancementService)
            .environmentObject(configValidationService)
            .environmentObject(localizationManager)
            .environment(\.locale, localizationManager.locale)
            .environment(\.theme, ThemePalette.theme(for: appSettings.uiTheme))
            .accentColor(ThemePalette.theme(for: appSettings.uiTheme).accentColor)
            .tint(ThemePalette.theme(for: appSettings.uiTheme).accentColor)
            .toggleStyle(ThemedSwitchToggleStyle(theme: ThemePalette.theme(for: appSettings.uiTheme)))
            .preferredColorScheme(appSettings.uiTheme == "cyberpunk" ? .dark : (appSettings.uiTheme == "liquidGlass" || appSettings.uiTheme == "vintage") ? .light : nil)
            .modelContainer(container)
            .onAppear {
                // Configure audio services with centralized settings
                SoundManager.shared.configure(with: appSettings)
                MediaController.shared.configure(with: appSettings)
                
                // Configure AI services with centralized settings
                aiService.configure(with: appSettings)
                enhancementService.configure(with: appSettings)
                configValidationService.configure(with: appSettings, aiService: aiService, enhancementService: enhancementService)
                
                // Perform Polish mode migration (Writing/Professional → Polish toggles)
                appSettings.performPolishModeMigration()
                
                // Configure coordinator with service references
                settingsCoordinator.configure(
                    menuBarManager: menuBarManager,
                    hotkeyManager: hotkeyManager,
                    whisperState: whisperState,
                    soundManager: SoundManager.shared,
                    mediaController: MediaController.shared,
                    aiEnhancementService: enhancementService,
                    aiService: aiService,
                    localizationManager: localizationManager
                )
                
                localizationManager.apply(languageCode: appSettings.appInterfaceLanguage)

                // Check if container initialization failed
                if containerInitializationFailed {
                    let alert = NSAlert()
                    alert.messageText = "Critical Storage Error"
                    alert.informativeText = "HoAh cannot initialize its storage system. The app cannot continue.\n\nPlease try reinstalling the app or contact support if the issue persists."
                    alert.alertStyle = .critical
                    alert.addButton(withTitle: "Quit")
                    alert.runModal()
                    
                    NSApplication.shared.terminate(nil)
                    return
                }
                // Start the transcription auto-cleanup service (handles immediate and scheduled transcript deletion)
                transcriptionAutoCleanupService.startMonitoring(modelContext: container.mainContext)
                
                // Start the automatic audio cleanup process only if transcript cleanup is not enabled
                if !UserDefaults.hoah.bool(forKey: "IsTranscriptionCleanupEnabled") {
                    audioCleanupManager.startAutomaticCleanup(modelContext: container.mainContext)
                }
                
            }
            .background(WindowAccessor { window in
                WindowManager.shared.configureWindow(window)
            })
            .onDisappear {
                whisperState.unloadModel()
                
                // Stop the transcription auto-cleanup service
                transcriptionAutoCleanupService.stopMonitoring()
                
                // Stop the automatic audio cleanup process
                audioCleanupManager.stopAutomaticCleanup()
            }
            .onChange(of: appSettings.appInterfaceLanguage) { _, newValue in
                localizationManager.apply(languageCode: newValue)
                NotificationCenter.default.post(name: .languageDidChange, object: nil)
            }
        }
        .windowStyle(.hiddenTitleBar)
        .commands {
            CommandGroup(replacing: .newItem) { }
            
            #if ENABLE_SPARKLE
            CommandGroup(after: .appInfo) {
                Button {
                    appDelegate.checkForUpdates(nil)
                } label: {
                    Text(LocalizedStringKey("menu_check_for_updates"))
                }
            }
            #endif
        }
        
        MenuBarExtra(isInserted: $showMenuBarIcon) {
            MenuBarView()
                .environmentObject(appSettings)
                .environmentObject(whisperState)
                .environmentObject(hotkeyManager)
                .environmentObject(menuBarManager)
                .environmentObject(aiService)
                .environmentObject(enhancementService)
                .environmentObject(configValidationService)
                .environment(\.locale, localizationManager.locale)
        } label: {
            let image: NSImage = {
                let ratio = $0.size.height / $0.size.width
                $0.size.height = 22
                $0.size.width = 22 / ratio
                return $0
            }(NSImage(named: "menuBarIcon")!)

            Image(nsImage: image)
        }
        .menuBarExtraStyle(.menu)
        
        #if DEBUG
        WindowGroup("Debug") {
            Button("Toggle Menu Bar Only") {
                appSettings.isMenuBarOnly.toggle()
            }
        }
        #endif
    }
}

struct WindowAccessor: NSViewRepresentable {
    let callback: (NSWindow) -> Void
    
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            if let window = view.window {
                callback(window)
            }
        }
        return view
    }
    
    func updateNSView(_ nsView: NSView, context: Context) {}
}

/// Sets window level on appear, restores to normal on disappear
struct OnboardingWindowLevelModifier: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            view.window?.level = .normal
        }
        return view
    }
    
    func updateNSView(_ nsView: NSView, context: Context) {}
    
    static func dismantleNSView(_ nsView: NSView, coordinator: ()) {
        nsView.window?.level = .normal
    }
}
