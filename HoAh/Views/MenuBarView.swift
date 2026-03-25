import SwiftUI
import LaunchAtLogin
import AppKit
import OSLog

struct MenuBarView: View {
    @EnvironmentObject var whisperState: WhisperState
    @EnvironmentObject var hotkeyManager: HotkeyManager
    @EnvironmentObject var menuBarManager: MenuBarManager
    @EnvironmentObject var enhancementService: AIEnhancementService
    @EnvironmentObject var aiService: AIService
    @EnvironmentObject var appSettings: AppSettingsStore
    @EnvironmentObject var validationService: ConfigurationValidationService
    @Environment(\.theme) private var theme
    @ObservedObject var audioDeviceManager = AudioDeviceManager.shared
    @State private var launchAtLoginEnabled = LaunchAtLogin.isEnabled
    @State private var isHovered = false
    
    private let menuBarLogger = Logger(subsystem: "com.yangzichao.hoah", category: "MenuBar")
    
    private var runtimeErrorMessage: String? {
        enhancementService.lastRuntimeErrorMessage
    }

    private var runtimeErrorConfigName: String {
        guard let errorConfigId = enhancementService.lastRuntimeErrorConfigId else {
            return appSettings.activeAIConfiguration?.name ?? NSLocalizedString("Unknown", comment: "")
        }
        return appSettings.aiEnhancementConfigurations
            .first(where: { $0.id == errorConfigId })?
            .name ?? NSLocalizedString("Unknown", comment: "")
    }

    private var aiConfigLabelText: String {
        let baseName = appSettings.activeAIConfiguration?.name ?? NSLocalizedString("None", comment: "")
        if runtimeErrorMessage != nil {
            return String(format: NSLocalizedString("AI Config: %@ (Error)", comment: ""), baseName)
        }
        return String(format: NSLocalizedString("AI Config: %@", comment: ""), baseName)
    }
    
    var body: some View {
        VStack {
            Button(LocalizedStringKey("open_hoah_dashboard")) {
                menuBarManager.openMainWindowAndNavigate(to: "HoAh")
            }
            .font(theme.typography.headline)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 6)
            
            Divider()
            
            Menu {
                ForEach(whisperState.usableModels, id: \.id) { model in
                    Button {
                        Task {
                            await whisperState.setDefaultTranscriptionModel(model)
                        }
                    } label: {
                        HStack {
                            Text(model.displayName)
                            if whisperState.currentTranscriptionModel?.id == model.id {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
                
                Divider()
                
                Button(NSLocalizedString("Manage Models", comment: "")) {
                    menuBarManager.openMainWindowAndNavigate(to: "Dictation Models")
                }
            } label: {
                HStack {
                    Text(String(format: NSLocalizedString("Dictation Model: %@", comment: ""), whisperState.currentTranscriptionModel?.displayName ?? NSLocalizedString("None", comment: "")))
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.system(size: 10))
                }
            }

            Menu {
                ForEach(HotkeyManager.HotkeyOption.allCases.filter { $0 != .custom }, id: \.self) { option in
                    Button {
                        hotkeyManager.selectedHotkey1 = option
                    } label: {
                        HStack {
                            Text(option.displayName)
                            if hotkeyManager.selectedHotkey1 == option {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
                
                Divider()

                Button(NSLocalizedString("Custom…", comment: "")) {
                    menuBarManager.openMainWindowAndNavigate(to: "Settings")
                }
                
                Divider()
                
                Button(NSLocalizedString("Configure Shortcuts", comment: "")) {
                    menuBarManager.openMainWindowAndNavigate(to: "Settings")
                }
            } label: {
                HStack {
                    Text(String(format: NSLocalizedString("Hotkey: %@", comment: ""), hotkeyManager.primaryHotkeyDisplayName))
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.system(size: 10))
                }
            }
            
            Divider()
            
            Toggle(appSettings.isAIEnhancementEnabled ?
                   NSLocalizedString("AI Enhancement: On", comment: "") :
                   NSLocalizedString("AI Enhancement: Off", comment: ""),
                   isOn: Binding(
                       get: { appSettings.isAIEnhancementEnabled },
                       set: { newValue in
                           if newValue {
                               // Try to enable AI enhancement
                               if !appSettings.tryEnableAIEnhancement() {
                                   // Show notification to guide user to set up AI
                                   NotificationManager.shared.showNotification(
                                       title: NSLocalizedString("Please configure AI in Settings → Enhancement", comment: ""),
                                       type: .warning
                                   )
                               }
                           } else {
                               appSettings.isAIEnhancementEnabled = false
                           }
                       }
                   ))
            
            Menu {
                ForEach(enhancementService.activePrompts) { prompt in
                    Button {
                        if appSettings.isAIEnhancementEnabled {
                            enhancementService.setActivePrompt(prompt)
                        } else {
                            if appSettings.tryEnableAIEnhancement() {
                                enhancementService.setActivePrompt(prompt)
                            } else {
                                NotificationManager.shared.showNotification(
                                    title: NSLocalizedString("Please configure AI in Settings → Enhancement", comment: ""),
                                    type: .warning
                                )
                            }
                        }
                    } label: {
                        HStack {
                            Image(systemName: prompt.icon)
                                .foregroundColor(theme.accentColor)
                            Text(prompt.title)
                            if enhancementService.selectedPromptId == prompt.id {
                                Spacer()
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                    .disabled(appSettings.validAIConfigurations.isEmpty)
                }
            } label: {
                HStack {
                    Text(String(format: NSLocalizedString("Prompt: %@", comment: ""), enhancementService.activePrompt?.title ?? NSLocalizedString("None", comment: "")))
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.system(size: 10))
                }
            }
            
            // AI Configuration Quick Switch (with validation)
            Menu {
                ForEach(appSettings.validAIConfigurations) { config in
                    Button {
                        handleConfigSelection(config)
                    } label: {
                        HStack {
                            Image(systemName: config.providerIcon)
                            Text(config.name)
                            if validationService.validatingConfigId == config.id {
                                Spacer()
                                ProgressView()
                                    .scaleEffect(0.6)
                            } else if appSettings.activeAIConfigurationId == config.id {
                                Spacer()
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                    .disabled(validationService.validatingConfigId != nil)
                }
                
                if appSettings.validAIConfigurations.isEmpty {
                    Text(NSLocalizedString("No configurations available", comment: ""))
                        .foregroundColor(theme.textSecondary)
                }
                
                // Show validation error if any
                if let error = validationService.validationError {
                    let errorConfigName = appSettings.aiEnhancementConfigurations
                        .first(where: { $0.id == validationService.validationErrorConfigId })?
                        .name
                    Divider()
                    Text(String(
                        format: NSLocalizedString("Validation failed (%@): %@", comment: ""),
                        errorConfigName ?? NSLocalizedString("Unknown", comment: ""),
                        error.errorDescription ?? NSLocalizedString("Validation failed", comment: "")
                    ))
                        .foregroundColor(theme.statusError)
                        .font(theme.typography.caption)
                }

                if let runtimeErrorMessage {
                    Divider()
                    Text(String(
                        format: NSLocalizedString("Runtime failed (%@): %@", comment: ""),
                        runtimeErrorConfigName,
                        runtimeErrorMessage
                    ))
                        .foregroundColor(theme.statusError)
                        .font(theme.typography.caption)
                }
                
                Divider()
                
                Button(NSLocalizedString("Manage Configurations...", comment: "")) {
                    menuBarManager.openMainWindowAndNavigate(to: "Enhancement")
                }
            } label: {
                HStack {
                    if runtimeErrorMessage != nil {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(theme.statusError)
                    }
                    if validationService.validatingConfigId != nil {
                        ProgressView()
                            .scaleEffect(0.6)
                    }
                    Text(aiConfigLabelText)
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.system(size: 10))
                }
            }
            
            LanguageSelectionView(whisperState: whisperState, displayMode: .menuItem, whisperPrompt: whisperState.whisperPrompt)

            Menu {
                ForEach(audioDeviceManager.availableDevices, id: \.id) { device in
                    Button {
                        audioDeviceManager.selectDeviceAndSwitchToCustomMode(id: device.id)
                    } label: {
                        HStack {
                            Text(device.name)
                            if audioDeviceManager.getCurrentDevice() == device.id {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }

                if audioDeviceManager.availableDevices.isEmpty {
                    Text(NSLocalizedString("No devices available", comment: ""))
                        .foregroundColor(theme.textSecondary)
                }
            } label: {
                HStack {
                    Text(LocalizedStringKey("Audio Input"))
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.system(size: 10))
                }
            }

            Divider()

            Button(NSLocalizedString("Copy Last Transcription", comment: "")) {
                LastTranscriptionService.copyLastTranscription(from: whisperState.modelContext)
            }
            .keyboardShortcut("c", modifiers: [.command, .shift])
            
            Button(NSLocalizedString("History", comment: "")) {
                menuBarManager.openMainWindowAndNavigate(to: "History")
            }
            .keyboardShortcut("h", modifiers: [.command, .shift])
            
            Button(appSettings.isMenuBarOnly ? NSLocalizedString("Show Dock Icon", comment: "") : NSLocalizedString("Hide Dock Icon", comment: "")) {
                appSettings.isMenuBarOnly.toggle()
            }
            .keyboardShortcut("d", modifiers: [.command, .shift])
            
            Toggle(LocalizedStringKey("Launch at Login"), isOn: $launchAtLoginEnabled)
                .onChange(of: launchAtLoginEnabled) { oldValue, newValue in
                    LaunchAtLogin.isEnabled = newValue
                }
            
            #if ENABLE_SPARKLE
            Button(NSLocalizedString("menu_check_for_updates", comment: "")) {
                let handled = NSApp.sendAction(#selector(AppDelegate.checkForUpdates(_:)), to: nil, from: nil)
                if !handled {
                    menuBarLogger.warning("Check for updates action not handled by responder chain")
                }
            }
            #endif
            
            Button(NSLocalizedString("Settings", comment: "")) {
                menuBarManager.openMainWindowAndNavigate(to: "Settings")
            }
            .keyboardShortcut(",", modifiers: .command)
            
            Button(NSLocalizedString("Quit HoAh", comment: "")) {
                NSApplication.shared.terminate(nil)
            }
        }
    }
    
    private func handleConfigSelection(_ config: AIEnhancementConfiguration) {
        if appSettings.isAIEnhancementEnabled {
            validationService.switchToConfiguration(id: config.id)
            return
        }
        
        let alert = NSAlert()
        alert.messageText = NSLocalizedString("Enable AI Enhancement?", comment: "")
        alert.informativeText = NSLocalizedString("AI Enhancement is off. Turn it on and use this configuration?", comment: "")
        alert.alertStyle = .warning
        alert.addButton(withTitle: NSLocalizedString("Enable", comment: ""))
        alert.addButton(withTitle: NSLocalizedString("Cancel", comment: ""))
        
        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            appSettings.isAIEnhancementEnabled = true
            validationService.switchToConfiguration(id: config.id)
        }
    }
}
