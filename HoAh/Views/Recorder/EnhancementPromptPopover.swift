import SwiftUI

// Enhancement Prompt Popover for recorder views
struct EnhancementPromptPopover: View {
    @EnvironmentObject var enhancementService: AIEnhancementService
    @EnvironmentObject var appSettings: AppSettingsStore
    @Environment(\.theme) private var theme
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Enhancement Toggle at the top
            HStack(spacing: 8) {
                Toggle("Enhancement Prompt", isOn: Binding(
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
                    .toggleStyle(ThemedSwitchToggleStyle(theme: theme))
                    .foregroundColor(theme.textPrimary.opacity(0.9))
                    .font(theme.typography.headline)
                    .lineLimit(1)
                
                Spacer()
            }
            .padding(.horizontal)
            .padding(.top, 8)
            
            Divider()
                .background(theme.panelBorder)
            
            ScrollView {
                VStack(alignment: .leading, spacing: 4) {
                    // Available Enhancement Prompts (filter out second translation when disabled)
                    ForEach(enhancementService.activePrompts.filter { prompt in
                        appSettings.isSecondTranslationEnabled || prompt.id != PredefinedPrompts.translatePrompt2Id
                    }) { prompt in
                        EnhancementPromptRow(
                            prompt: prompt,
                            isSelected: enhancementService.selectedPromptId == prompt.id,
                            isDisabled: !appSettings.isAIEnhancementEnabled,
                            action: {
                                // If enhancement is disabled, try to enable it first
                                if !appSettings.isAIEnhancementEnabled {
                                    if appSettings.tryEnableAIEnhancement() {
                                        enhancementService.setActivePrompt(prompt)
                                    } else {
                                        // Show notification to guide user to set up AI
                                        NotificationManager.shared.showNotification(
                                            title: NSLocalizedString("Please configure AI in Settings → Enhancement", comment: ""),
                                            type: .warning
                                        )
                                    }
                                } else {
                                    enhancementService.setActivePrompt(prompt)
                                }
                            }
                        )
                    }
                }
                .padding(.horizontal)
            }
        }
        .frame(width: 200)
        .frame(maxHeight: 340)
        .padding(.vertical, 8)
        .background(theme.backgroundBase)
        .environment(\.colorScheme, .dark)
    }
}

// Row view for each enhancement prompt in the popover
struct EnhancementPromptRow: View {
    let prompt: CustomPrompt
    let isSelected: Bool
    let isDisabled: Bool
    let action: () -> Void
    @Environment(\.theme) private var theme
    
    // Access settings for translation configuration
    @EnvironmentObject private var appSettings: AppSettingsStore
    
    private var isTranslatePrompt: Bool {
        prompt.id == PredefinedPrompts.translatePromptId
    }

    private var isTranslate2Prompt: Bool {
        prompt.id == PredefinedPrompts.translatePrompt2Id
    }

    private var isAnyTranslatePrompt: Bool {
        isTranslatePrompt || isTranslate2Prompt
    }

    private var savedLanguages: [String] {
        appSettings.savedTranslationLanguages
    }

    private var currentTargetLanguage: String {
        isTranslate2Prompt ? appSettings.translationTargetLanguage2 : appSettings.translationTargetLanguage
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Main Prompt Row
            Button(action: action) {
                HStack(spacing: 8) {
                    Image(systemName: prompt.icon)
                        .font(.system(size: 14))
                        .foregroundColor(isDisabled ? theme.textMuted.opacity(0.6) : theme.textSecondary)

                    VStack(alignment: .leading, spacing: 1) {
                        Text(prompt.title)
                            .foregroundColor(isDisabled ? theme.textMuted.opacity(0.6) : theme.textPrimary.opacity(0.9))
                            .font(.system(size: 13))
                            .lineLimit(1)
                        
                        // Subtitle for Translate active state
                        if isSelected && isAnyTranslatePrompt {
                            Text(currentTargetLanguage)
                                .font(.system(size: 10))
                                .foregroundColor(theme.textMuted)
                                .lineLimit(1)
                        }
                    }

                    Spacer()

                    if isSelected {
                        Image(systemName: "checkmark")
                            .foregroundColor(isDisabled ? theme.statusSuccess.opacity(0.7) : theme.statusSuccess)
                            .font(.system(size: 10))
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 4)
                .padding(.horizontal, 8)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .background(isSelected ? theme.panelBackground : Color.clear)
            .cornerRadius(4)
            .help(prompt.displayDescription ?? "")
            
            // Inline Chips for Translation (Only when selected)
            if isSelected && isAnyTranslatePrompt && !savedLanguages.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(savedLanguages, id: \.self) { language in
                            Button {
                                if isTranslate2Prompt {
                                    appSettings.selectTranslationLanguage2(language)
                                } else {
                                    appSettings.selectTranslationLanguage(language)
                                }
                            } label: {
                                Text(language)
                                    .font(.system(size: 10))
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 3)
                                    .background(currentTargetLanguage == language ? theme.accentColor : theme.panelBackground)
                                    .foregroundColor(theme.textPrimary)
                                    .cornerRadius(8)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 8) // Match row padding approximately
                    .padding(.bottom, 6)
                    .padding(.top, 2)
                }
            }
        }
        .background(isSelected && isAnyTranslatePrompt ? theme.panelBackground.opacity(0.6) : Color.clear) // Subtle background for the expanded area
        .cornerRadius(4)
    }
} 
