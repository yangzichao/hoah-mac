import SwiftUI
import Cocoa
import KeyboardShortcuts
import LaunchAtLogin
import AVFoundation

struct SettingsView: View {
    @EnvironmentObject private var menuBarManager: MenuBarManager
    @EnvironmentObject private var hotkeyManager: HotkeyManager
    @EnvironmentObject private var whisperState: WhisperState
    @EnvironmentObject private var enhancementService: AIEnhancementService
    @EnvironmentObject private var appSettings: AppSettingsStore
    @Environment(\.theme) private var theme

    @ObservedObject private var soundManager = SoundManager.shared
    @ObservedObject private var mediaController = MediaController.shared
    @State private var currentShortcut = KeyboardShortcuts.getShortcut(for: .toggleMiniRecorder)
    @State private var isCustomCancelEnabled = false
    @State private var isAppendShortcutEnabled = false
    @State private var isCustomSoundsExpanded = false

    private let durationOptions: [Int] = [30, 60, 90, 0]
    private let visibleUIThemes: [UITheme] = UITheme.allCases.filter { $0 != .liquidGlass }
    
    private func label(for minutes: Int) -> String {
        if minutes == 0 { return NSLocalizedString("No limit", comment: "No recording time limit") }
        if minutes >= 60 {
            let hours = minutes / 60
            let remainingMinutes = minutes % 60
            if remainingMinutes == 0 {
                return String(format: NSLocalizedString("%d hr", comment: "Hours label"), hours)
            }
            return String(
                format: NSLocalizedString("%d hr %d min", comment: "Hours and minutes label"),
                hours,
                remainingMinutes
            )
        }
        return String(format: NSLocalizedString("%d min", comment: "Minutes label"), minutes)
    }
    
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                SettingsSection(
                    icon: "keyboard",
                    title: "Shortcuts",
                    subtitle: "Manage keyboard shortcuts and triggers"
                ) {
                    VStack(alignment: .leading, spacing: 16) {
                        // MARK: - Primary Trigger
                        VStack(alignment: .leading, spacing: 12) {
                            HStack(alignment: .center, spacing: 12) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Trigger HoAh")
                                        .font(theme.typography.headline) // More prominent
                                        .foregroundColor(theme.textPrimary)
                                    Text("Quick tap to start/stop, hold for push-to-talk.")
                                        .font(theme.typography.caption)
                                        .foregroundColor(theme.textSecondary)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                                
                                Spacer()
                                
                                // Large Prominent Dropdown
                                Menu {
                                    ForEach(HotkeyManager.HotkeyOption.allCases, id: \.self) { option in
                                        Button(action: {
                                            hotkeyManager.selectedHotkey1 = option
                                        }) {
                                            HStack {
                                                Text(option.displayName)
                                                if hotkeyManager.selectedHotkey1 == option {
                                                    Spacer()
                                                    Image(systemName: "checkmark")
                                                }
                                            }
                                        }
                                    }
                                } label: {
                                    HStack(spacing: 8) {
                                        Text(hotkeyManager.selectedHotkey1.displayName)
                                            .font(theme.typography.subheadline)
                                            .fontWeight(.medium) // Larger text
                                            .foregroundColor(theme.textPrimary)
                                            .lineLimit(1)
                                        Spacer()
                                        Image(systemName: "chevron.up.chevron.down")
                                            .font(.system(size: 10, weight: .bold))
                                            .foregroundColor(theme.textSecondary)
                                    }
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8) // Taller button
                                    .frame(width: 160) // Wider button
                                    .background(theme.controlBackground)
                                    .cornerRadius(8)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8)
                                            .stroke(theme.accentColor.opacity(0.4), lineWidth: 1.5) // Subtle accent border
                                    )
                                    .shadow(color: theme.shadowColor.opacity(0.05), radius: 2, x: 0, y: 1)
                                }
                                .menuStyle(.borderlessButton)
                                
                                if hotkeyManager.selectedHotkey1 == .custom {
                                    KeyboardShortcuts.Recorder(for: .toggleMiniRecorder) { _ in
                                        hotkeyManager.updateShortcutStatus()
                                    }
                                        .controlSize(.regular) // Regular size for prominence
                                }
                            }
                        }
                        .padding(12)
                        .background(theme.accentColor.opacity(0.05)) // Subtle highlight background for the whole trigger section
                        .cornerRadius(8)

                        Divider()

                        // MARK: - Advanced Triggers
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Advanced Triggers")
                                .font(theme.typography.caption)
                                .fontWeight(.semibold)
                                .foregroundColor(theme.textSecondary)

                            // Custom Cancel
                            VStack(spacing: 8) {
                                SettingsToggleRow(
                                    "Custom Cancel Shortcut",
                                    isOn: $isCustomCancelEnabled.animation()
                                )
                                .onChange(of: isCustomCancelEnabled) { _, newValue in
                                    if !newValue {
                                        KeyboardShortcuts.setShortcut(nil, for: .cancelRecorder)
                                    }
                                }
                                
                                Text("Shortcut for cancelling the current recording session. Default: double-tap Escape.")
                                    .font(theme.typography.caption)
                                    .foregroundColor(theme.textSecondary)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                
                                if isCustomCancelEnabled {
                                    HStack {
                                        Spacer()
                                        KeyboardShortcuts.Recorder(for: .cancelRecorder)
                                            .controlSize(.small)
                                    }
                                }
                            }

                            // Multi-Press Gestures
                            SettingsToggleRow(
                                "Double-Press Right Option to Auto-Send",
                                subtitle: "Double-press the right Option key to auto-paste and send (Enter) after transcription, even if you change the main recording shortcut.",
                                isOn: $appSettings.multiPressGestureAutoSendEnabled.animation()
                            )

                            VStack(spacing: 8) {
                                SettingsToggleRow(
                                    "Append Shortcut",
                                    subtitle: "Use a separate shortcut to start append recording. Press the same shortcut again to stop and append the result to the previous transcription. No default shortcut is assigned.",
                                    isOn: $isAppendShortcutEnabled.animation()
                                )
                                .onChange(of: isAppendShortcutEnabled) { _, newValue in
                                    if !newValue {
                                        KeyboardShortcuts.setShortcut(nil, for: .toggleMiniRecorderAppend)
                                    }
                                }

                                if isAppendShortcutEnabled {
                                    HStack {
                                        Spacer()
                                        KeyboardShortcuts.Recorder(for: .toggleMiniRecorderAppend) { _ in
                                            hotkeyManager.updateShortcutStatus()
                                        }
                                        .controlSize(.small)
                                    }
                                }
                            }
                        }
                    }
                }

                SettingsSection(
                    icon: "mic.circle",
                    title: "Recording Settings",
                    subtitle: "Customize recorder behavior and feedback"
                ) {
                    VStack(alignment: .leading, spacing: 12) {
                        // Recorder Style
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Select how you want the recorder to appear on your screen.")
                                .font(theme.typography.subheadline)
                                .foregroundColor(theme.textSecondary)
                                .fixedSize(horizontal: false, vertical: true)
                            
                            Picker("Recorder Style", selection: $appSettings.recorderType) {
                                Text("Notch Recorder").tag("notch")
                                Text("Mini Recorder").tag("mini")
                            }
                            .pickerStyle(.radioGroup)
                            .padding(.vertical, 4)
                        }

                        Divider()

                        SettingsToggleRow(
                            "Sound feedback",
                            isOn: $appSettings.isSoundFeedbackEnabled
                        )

                        SettingsToggleRow(
                            "Mute system audio during recording",
                            isOn: $appSettings.isSystemMuteEnabled,
                            help: "Automatically mute system audio when recording starts and restore when recording stops"
                        )
                        
                        SettingsToggleRow(
                            "Preserve transcript in clipboard",
                            isOn: $appSettings.preserveTranscriptInClipboard,
                            help: "Keep the transcribed text in clipboard instead of restoring the original clipboard content"
                        )
                        
                        Divider()
                        
                        VStack(alignment: .leading, spacing: 6) {
                            Picker(LocalizedStringKey("Maximum recording duration"), selection: $appSettings.maxRecordingDurationMinutes) {
                                ForEach(durationOptions, id: \.self) { minutes in
                                    Text(label(for: minutes)).tag(minutes)
                                }
                            }
                            .pickerStyle(.segmented)
                            
                            Text(LocalizedStringKey("Recording stops automatically when this limit is reached to avoid unintended long sessions."))
                                .font(theme.typography.subheadline)
                                .foregroundColor(theme.textSecondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }

                    }
                }





                SettingsSection(
                    icon: "gear",
                    title: "General",
                    subtitle: "Appearance, startup, and updates"
                ) {
                    VStack(alignment: .leading, spacing: 16) {
                        
                        #if ENABLE_SPARKLE
                        // Updates (GitHub / non-MAS builds)
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(LocalizedStringKey("help_check_updates"))
                                    .font(theme.typography.body)
                                if let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String {
                                    Text("\(NSLocalizedString("help_current_version", comment: "")) \(version)")
                                        .font(theme.typography.caption)
                                        .foregroundColor(theme.textSecondary)
                                        .monospacedDigit()
                                }
                                Text(LocalizedStringKey("help_update_schedule"))
                                    .font(theme.typography.caption)
                                    .foregroundColor(theme.textSecondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            Spacer()
                            Button(LocalizedStringKey("help_check_now")) {
                                NSApp.sendAction(#selector(AppDelegate.checkForUpdates(_:)), to: nil, from: nil)
                            }
                        }
                        #endif
                        
                        Divider()

                        SettingsToggleRow("Hide Dock Icon (Menu Bar Only)", isOn: $appSettings.isMenuBarOnly)
                        
                        SettingsToggleRow(
                            "Launch at Login",
                            isOn: Binding(
                                get: { LaunchAtLogin.isEnabled },
                                set: { LaunchAtLogin.isEnabled = $0 }
                            )
                        )


                        VStack(alignment: .leading, spacing: 6) {
                            Text("Interface Language")
                                .font(theme.typography.headline)
                            Picker("", selection: $appSettings.appInterfaceLanguage) {
                                Text("Follow System").tag("system")
                                Text("English").tag("en")
                                Text("简体中文").tag("zh-Hans")
                            }
                            .pickerStyle(SegmentedPickerStyle())
                            .onChange(of: appSettings.appInterfaceLanguage) { _, _ in
                                NotificationCenter.default.post(name: .AppSettingsDidChange, object: nil)
                                NotificationCenter.default.post(name: .languageDidChange, object: nil)
                            }
                            Text("Switch HoAh's interface language. Changes take effect immediately on supported screens; untranslated items will fall back to English.")
                                .font(theme.typography.caption)
                                .foregroundColor(theme.textSecondary)
                        }

                        Divider()

                        VStack(alignment: .leading, spacing: 6) {
                            Text(LocalizedStringKey("ui_theme_title"))
                                .font(theme.typography.headline)
                            Picker("", selection: $appSettings.uiTheme) {
                                ForEach(visibleUIThemes, id: \.self) { theme in
                                    Text(theme.displayNameKey).tag(theme.rawValue)
                                }
                            }
                            .pickerStyle(SegmentedPickerStyle())
                            Text(LocalizedStringKey("ui_theme_desc"))
                                .font(theme.typography.caption)
                                .foregroundColor(theme.textSecondary)
                        }
                    }
                }
                
                SettingsSection(
                    icon: "lock.shield",
                    title: "Data & Privacy",
                    subtitle: "Control transcript history and storage"
                ) {
                    AudioCleanupSettingsView()
                }
                
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 6)
        }
        .background(theme.controlBackground)
        .onAppear {
            isCustomCancelEnabled = KeyboardShortcuts.getShortcut(for: .cancelRecorder) != nil
            isAppendShortcutEnabled = KeyboardShortcuts.getShortcut(for: .toggleMiniRecorderAppend) != nil
            if appSettings.uiTheme == UITheme.liquidGlass.rawValue {
                appSettings.uiTheme = UITheme.vintage.rawValue
            }
        }
    }
}

// MARK: - Helper Views

struct SettingsToggleRow: View {
    let title: LocalizedStringKey
    let subtitle: LocalizedStringKey?
    @Binding var isOn: Bool
    var helpText: String? = nil
    @Environment(\.theme) private var theme
    
    init(_ title: LocalizedStringKey, subtitle: LocalizedStringKey? = nil, isOn: Binding<Bool>, help: String? = nil) {
        self.title = title
        self.subtitle = subtitle
        self._isOn = isOn
        self.helpText = help
    }
    
    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(theme.typography.body)
                    .foregroundColor(theme.textPrimary)
                
                if let subtitle = subtitle {
                    Text(subtitle)
                        .font(theme.typography.caption)
                        .foregroundColor(theme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            
            Spacer()
            
            Toggle("", isOn: $isOn)
                .toggleStyle(ThemedSwitchToggleStyle(theme: theme))
                .labelsHidden()
        }
        .if(helpText != nil) { view in
            view.help(helpText!)
        }
    }
}

extension View {
    @ViewBuilder func `if`<Content: View>(_ condition: Bool, transform: (Self) -> Content) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }
}

struct SettingsSection<Content: View>: View {
    let icon: String
    let title: String
    let subtitle: String
    let content: Content
    var showWarning: Bool = false
    @Environment(\.theme) private var theme
    
    init(icon: String, title: String, subtitle: String, showWarning: Bool = false, @ViewBuilder content: () -> Content) {
        self.icon = icon
        self.title = title
        self.subtitle = subtitle
        self.showWarning = showWarning
        self.content = content()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 20))
                    .foregroundColor(showWarning ? theme.statusError : theme.accentColor)
                    .frame(width: 24, height: 24)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(LocalizedStringKey(title))
                        .font(theme.typography.headline)
                    Text(LocalizedStringKey(subtitle))
                        .font(theme.typography.subheadline)
                        .foregroundColor(showWarning ? theme.statusError : theme.textSecondary)
                }
                
                if showWarning {
                    Spacer()
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(theme.statusError)
                        .help("Permission required for HoAh to function properly")
                }
            }
            
            Divider()
                .padding(.vertical, 4)
            
            content
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(CardBackground(isSelected: showWarning, useAccentGradientWhenSelected: true))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(showWarning ? theme.statusError.opacity(0.5) : Color.clear, lineWidth: 1)
        )
    }
}
