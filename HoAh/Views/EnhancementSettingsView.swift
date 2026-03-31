import SwiftUI
import UniformTypeIdentifiers

/// EnhancementSettingsView manages AI enhancement providers (LLMs for text post-processing).
/// For transcription models (speech-to-text), see ModelManagementView.
struct EnhancementSettingsView: View {
    @EnvironmentObject private var enhancementService: AIEnhancementService
    @EnvironmentObject private var aiService: AIService
    @EnvironmentObject private var appSettings: AppSettingsStore
    @Environment(\.theme) private var theme
    @Environment(\.openURL) private var openURL
    @State private var isEditingPrompt = false
    @State private var isSettingsExpanded = true
    @State private var selectedPromptForEdit: CustomPrompt?
    @State private var pendingPromptKind: PromptKind = .active
    @State private var isUserProfileExpanded = false
    @State private var isAIConfigExpanded = true
    @State private var isPromptTriggersExpanded = true
    @State private var isAddConfigurationSheetPresented = false
    @State private var highlightConfigurationSection = false

    private var autoPrompts: [CustomPrompt] { enhancementService.activePrompts }

    /// Filtered prompts to display in the grid (hides second translation when disabled)
    private var displayedPrompts: [CustomPrompt] {
        if appSettings.isSecondTranslationEnabled {
            return enhancementService.activePrompts
        } else {
            return enhancementService.activePrompts.filter { $0.id != PredefinedPrompts.translatePrompt2Id }
        }
    }

    private var activeAutoPromptTitle: String {
        if let prompt = autoPrompts.first(where: { $0.id == enhancementService.selectedPromptId }) {
            return prompt.displayTitle
        }
        return NSLocalizedString("None", comment: "")
    }



    private var isTranslateModeSelected: Bool {
        enhancementService.activePrompt?.id == PredefinedPrompts.translatePromptId
    }

    private var isTranslate2ModeSelected: Bool {
        enhancementService.activePrompt?.id == PredefinedPrompts.translatePrompt2Id
    }

    private var isQnaModeSelected: Bool {
        enhancementService.activePrompt?.id == PredefinedPrompts.qnaPromptId
    }
    
    private var isPolishModeSelected: Bool {
        enhancementService.activePrompt?.id == PredefinedPrompts.polishPromptId
    }
    
    private var selectedPrompt: CustomPrompt? {
        enhancementService.activePrompt
    }
    
    private var hasAnyConfigurations: Bool { !appSettings.aiEnhancementConfigurations.isEmpty }
    private var hasValidConfigurations: Bool { !appSettings.validAIConfigurations.isEmpty }
    private var canSelectPrompts: Bool { appSettings.isAIEnhancementEnabled && hasValidConfigurations }
    private var shouldShowOffWarning: Bool { !appSettings.isAIEnhancementEnabled && hasValidConfigurations }
    private var shouldDimEnhancementUI: Bool { hasValidConfigurations && !appSettings.isAIEnhancementEnabled }
    private var shouldShowUserProfileSection: Bool { false }
    private var shouldEnablePagePromptShortcuts: Bool {
        canSelectPrompts &&
        !isEditingPrompt &&
        selectedPromptForEdit == nil &&
        !isAddConfigurationSheetPresented
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 32) {
                // Header
                HStack(spacing: 16) {
                    Image(systemName: "wand.and.stars")
                        .font(.system(size: 32))
                        .foregroundStyle(theme.statusInfo)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("AI Action")
                            .font(theme.typography.title2)
                        Text("ai_action_description")
                            .font(theme.typography.subheadline)
                            .foregroundStyle(theme.textSecondary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                // Main Settings Sections
                VStack(spacing: 24) {
                    // Enable/Disable Toggle Section
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Text(LocalizedStringKey("Enable Auto Enhancement"))
                                        .font(theme.typography.headline)
                                    
                                    if !appSettings.isAIEnhancementEnabled {
                                        Image(systemName: "exclamationmark.triangle.fill")
                                            .foregroundColor(theme.statusWarning)
                                            .font(theme.typography.caption)
                                    }
                                     
                                    InfoTip(
                                        title: NSLocalizedString("AI Enhancement", comment: ""),
                                        message: NSLocalizedString("AI enhancement lets you pass the transcribed audio through LLMs to post-process using different prompts suitable for different use cases like e-mails, summary, writing, etc.", comment: "")
                                    )
                                }
                                
                                Text(LocalizedStringKey("Automatically apply AI-powered enhancement after each transcription"))
                                    .font(theme.typography.caption)
                                    .foregroundColor(theme.textSecondary)
                            }
                            
                            Spacer()
                            
                            Toggle("", isOn: Binding(
                                get: { appSettings.isAIEnhancementEnabled },
                                set: { newValue in
                                    if newValue {
                                        // Use centralized method for consistency
                                        if !appSettings.tryEnableAIEnhancement() {
                                            // Show notification instead of popover
                                            NotificationManager.shared.showNotification(
                                                title: NSLocalizedString("Please configure AI in Settings → Enhancement", comment: ""),
                                                type: .warning
                                            )
                                            withAnimation(.easeInOut) {
                                                highlightConfigurationSection = true
                                            }
                                            // Remove highlight after a short delay
                                            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                                                withAnimation(.easeOut(duration: 0.25)) {
                                                    highlightConfigurationSection = false
                                                }
                                            }
                                        }
                                    } else {
                                        appSettings.isAIEnhancementEnabled = false
                                    }
                                }
                            ))
                            .toggleStyle(ThemedSwitchToggleStyle(theme: theme))
                            .labelsHidden()
                            .scaleEffect(1.2)
                        }
                        
                    }
                    .padding()
                    .background(CardBackground(isSelected: false))
                    .opacity(hasValidConfigurations ? 1.0 : 0.6)
                    
                    // 1. AI Configuration Card
                    VStack(alignment: .leading, spacing: 16) {
                        // Status indicator: only show warning when off
                        if shouldShowOffWarning {
                            HStack(alignment: .top, spacing: 8) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundColor(theme.statusWarning)
                                    .font(theme.typography.caption)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(NSLocalizedString("AI Enhancement: Off", comment: ""))
                                        .font(theme.typography.caption)
                                        .fontWeight(.semibold)
                                        .foregroundColor(theme.statusWarning)
                                    Text(appSettings.aiEnhancementConfigurations.isEmpty
                                         ? NSLocalizedString("Add a configuration to enable.", comment: "")
                                         : NSLocalizedString("Turn it on to apply your configuration.", comment: ""))
                                    .font(theme.typography.caption)
                                    .foregroundColor(theme.textSecondary)
                                }
                            }
                            .padding(10)
                            .background(theme.statusWarning.opacity(0.08))
                            .cornerRadius(8)
                        }
                        
                        if !hasAnyConfigurations {
                            HStack(alignment: .top, spacing: 10) {
                                Image(systemName: "wand.and.rays")
                                    .foregroundColor(theme.accentColor)
                                    .font(.callout)
                                
                                VStack(alignment: .leading, spacing: 6) {
                                    Text(NSLocalizedString("Add an AI configuration to get started.", comment: ""))
                                        .font(theme.typography.subheadline)
                                        .fontWeight(.semibold)
                                    Text(NSLocalizedString("AI Enhancement needs at least one valid configuration before it can be turned on.", comment: ""))
                                        .font(theme.typography.caption)
                                        .foregroundColor(theme.textSecondary)
                                    
                                    Button(NSLocalizedString("Add Configuration", comment: "")) {
                                        isAddConfigurationSheetPresented = true
                                    }
                                    .buttonStyle(.borderedProminent)
                                    .controlSize(.small)
                                }
                            }
                            .padding(12)
                            .background(theme.accentColor.opacity(0.08))
                            .cornerRadius(10)
                        } else if !hasValidConfigurations {
                            HStack(alignment: .top, spacing: 10) {
                                Image(systemName: "exclamationmark.triangle")
                                    .foregroundColor(theme.statusWarning)
                                    .font(.callout)
                                
                                VStack(alignment: .leading, spacing: 6) {
                                    Text(NSLocalizedString("No valid configurations available.", comment: ""))
                                        .font(theme.typography.subheadline)
                                        .fontWeight(.semibold)
                                    Text(NSLocalizedString("Edit an existing configuration or add a new one to enable AI Enhancement.", comment: ""))
                                        .font(theme.typography.caption)
                                        .foregroundColor(theme.textSecondary)
                                    
                                    Button(NSLocalizedString("Add Configuration", comment: "")) {
                                        isAddConfigurationSheetPresented = true
                                    }
                                    .buttonStyle(.bordered)
                                    .controlSize(.small)
                                }
                            }
                            .padding(12)
                            .background(theme.statusWarning.opacity(0.08))
                            .cornerRadius(10)
                        }

                        ConfigurationListView(showingAddSheet: $isAddConfigurationSheetPresented)
                    }
                    .padding()
                    .background(CardBackground(isSelected: false))
                    .overlay(
                        RoundedRectangle(cornerRadius: theme.cardCornerRadius)
                            .stroke(theme.accentColor.opacity(highlightConfigurationSection ? 0.9 : 0.0), lineWidth: 2)
                            .animation(.easeInOut(duration: 0.2), value: highlightConfigurationSection)
                    )
                    .opacity(shouldDimEnhancementUI ? 0.6 : 1.0)
                    
                    // 2. Default Enhancement Mode Card
                    VStack(alignment: .leading, spacing: 16) {
                        HStack(spacing: 8) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(LocalizedStringKey("Default Auto-Enhancement"))
                                    .font(theme.typography.headline)
                                Text(LocalizedStringKey("Select the default AI behavior applied to every dictation."))
                                    .font(theme.typography.caption)
                                    .foregroundColor(theme.textSecondary)
                            }
                            
                            Spacer()

                            Button {
                                pendingPromptKind = .active
                                isEditingPrompt = true
                            } label: {
                                Label(
                                    NSLocalizedString("add_prompt_button_title", comment: ""),
                                    systemImage: "plus"
                                )
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                            
                            Button(LocalizedStringKey("Reset Built-in Prompts")) {
                                enhancementService.resetPredefinedPrompts()
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                        }
                        
                        Text("\(NSLocalizedString("ai_enhancement_auto_prompt_hint", comment: "")) \(activeAutoPromptTitle).")
                            .font(theme.typography.caption)
                            .foregroundColor(theme.textSecondary)
                        
                        ReorderablePromptGrid(
                            boundPrompts: $enhancementService.activePrompts,
                            selectedPromptId: enhancementService.selectedPromptId,
                            onPromptSelected: { prompt in
                                enhancementService.setActivePrompt(prompt)
                            },
                            onEditPrompt: { prompt in
                                selectedPromptForEdit = prompt
                            },
                            onDeletePrompt: { prompt in
                                enhancementService.deletePrompt(prompt)
                            },
                            hiddenPromptIds: appSettings.isSecondTranslationEnabled ? [] : [PredefinedPrompts.translatePrompt2Id]
                        )
                        .opacity(canSelectPrompts ? 1.0 : 0.4)
                        .allowsHitTesting(canSelectPrompts)
                        
                            if let selectedPrompt {
                                // Specific Mode Configuration Card
                                VStack(alignment: .leading, spacing: 12) {
                                    HStack {
                                        Text(selectedPrompt.displayTitle)
                                            .font(theme.typography.headline)
                                        
                                        Spacer()
                                        
                                        Text(LocalizedStringKey("mode_settings_title"))
                                            .font(theme.typography.caption)
                                            .fontWeight(.bold)
                                            .foregroundColor(theme.textSecondary)
                                            .textCase(.uppercase)
                                    }
                                    
                                    if let desc = selectedPrompt.displayDescription, !desc.isEmpty {
                                        Text(desc)
                                            .font(theme.typography.caption)
                                            .foregroundColor(theme.textSecondary)
                                            .fixedSize(horizontal: false, vertical: true)
                                    }
                                    
                                    // Only show controls if pertinent
                                    if isTranslateModeSelected || isTranslate2ModeSelected || isQnaModeSelected || isPolishModeSelected {
                                        Divider()
                                            .padding(.vertical, 4)

                                        if isTranslateModeSelected {
                                            TranslationTargetSelector(
                                                targetLanguage: $appSettings.translationTargetLanguage,
                                                showOriginalInOutput: $appSettings.showOriginalTextInTranslation
                                            )
                                        } else if isTranslate2ModeSelected {
                                            TranslationTargetSelector(
                                                targetLanguage: $appSettings.translationTargetLanguage2,
                                                showOriginalInOutput: $appSettings.showOriginalTextInTranslation2,
                                                isPrimaryTranslation: false
                                            )
                                        } else if isQnaModeSelected {
                                            VStack(alignment: .leading, spacing: 8) {
                                                Toggle(LocalizedStringKey("qa_show_original_toggle"), isOn: $appSettings.showOriginalTextInQA)
                                                    .toggleStyle(ThemedSwitchToggleStyle(theme: theme))
                                                Text(LocalizedStringKey("qa_show_original_hint"))
                                                    .font(theme.typography.caption2)
                                                    .foregroundColor(theme.textSecondary)
                                            }
                                        } else if isPolishModeSelected {
                                            PolishEnhancementOptions(
                                                formalWritingEnabled: $appSettings.isPolishFormalWritingEnabled,
                                                professionalEnabled: $appSettings.isPolishProfessionalEnabled
                                            )
                                        }
                                    }
                                }
                                .padding(16)
                                .background(theme.controlBackground)
                                .cornerRadius(12)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(theme.panelBorder, lineWidth: 1)
                                )
                                .shadow(color: theme.shadowColor.opacity(0.03), radius: 4, x: 0, y: 2)
                                .padding(.top, 12)
                                .transition(.opacity)
                            }
                        }
                        .padding()
                        .background(CardBackground(isSelected: false))
                        .opacity(shouldDimEnhancementUI ? 0.55 : 1.0)

                    if shouldShowUserProfileSection {
                        // User Profile Section
                        DisclosureGroup(isExpanded: $isUserProfileExpanded) {
                            VStack(alignment: .leading, spacing: 12) {
                                Divider()

                                Text(NSLocalizedString("Provide optional context about yourself to help AI better tailor responses. This information will be included in all enhancement requests.", comment: ""))
                                    .font(theme.typography.caption)
                                    .foregroundColor(theme.textSecondary)
                                    .fixedSize(horizontal: false, vertical: true)

                                ZStack(alignment: .topLeading) {
                                    if appSettings.userProfileContext.isEmpty {
                                        Text(NSLocalizedString("user_profile_placeholder", comment: ""))
                                            .font(theme.typography.caption)
                                            .foregroundColor(theme.textSecondary.opacity(0.5))
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 8)
                                    }

                                    TextEditor(text: $appSettings.userProfileContext)
                                        .font(theme.typography.caption)
                                        .frame(minHeight: 100, maxHeight: 150)
                                        .scrollContentBackground(.hidden)
                                        .background(theme.inputBackground)
                                        .cornerRadius(6)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 6)
                                                .stroke(theme.inputBorder, lineWidth: 1)
                                        )
                                }

                                HStack {
                                    Text(
                                        String(
                                            format: NSLocalizedString("user_profile_character_count", comment: "character count for user profile"),
                                            appSettings.userProfileContext.count
                                        )
                                    )
                                        .font(theme.typography.caption2)
                                        .foregroundColor(appSettings.userProfileContext.count > 500 ? theme.statusError : theme.textSecondary)

                                    Spacer()

                                    if !appSettings.userProfileContext.isEmpty {
                                        Button(NSLocalizedString("Clear", comment: "")) {
                                            appSettings.userProfileContext = ""
                                        }
                                        .buttonStyle(.plain)
                                        .font(theme.typography.caption)
                                        .foregroundColor(theme.accentColor)
                                    }
                                }
                            }
                        } label: {
                            HStack {
                                Text(NSLocalizedString("User Profile", comment: ""))
                                    .font(theme.typography.headline)

                                InfoTip(
                                    title: NSLocalizedString("User Profile", comment: ""),
                                    message: NSLocalizedString("Optional: Add context about yourself (name, role, industry, tech stack, etc.) to help AI provide more relevant responses.", comment: "")
                                )

                                Spacer()

                                if !appSettings.userProfileContext.isEmpty {
                                    Text(NSLocalizedString("Configured", comment: ""))
                                        .font(theme.typography.caption)
                                        .foregroundColor(theme.textSecondary)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(theme.accentColor.opacity(0.1))
                                        .cornerRadius(8)
                                }
                            }
                        }
                        .padding()
                        .background(CardBackground(isSelected: false))
                    }
                    
                    ClipboardActionShortcutsSection()
                    EnhancementShortcutsSection()
                }
            }
            .padding(32)
        }
        .frame(minWidth: 600, minHeight: 500)
        .background(theme.controlBackground)
        .background(pagePromptShortcutBindings)
        .sheet(isPresented: $isEditingPrompt) {
            PromptEditorView(mode: .add(kind: pendingPromptKind))
        }
        .sheet(item: $selectedPromptForEdit) { prompt in
            PromptEditorView(mode: .edit(prompt))
        }
    }

    @ViewBuilder
    private var pagePromptShortcutBindings: some View {
        VStack(spacing: 0) {
            ForEach(Array(displayedPrompts.prefix(10).enumerated()), id: \.element.id) { index, prompt in
                Button("") {
                    guard shouldEnablePagePromptShortcuts else { return }
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        enhancementService.setActivePrompt(prompt)
                    }
                }
                .keyboardShortcut(shortcutKeyEquivalent(for: index), modifiers: [.command])
                .disabled(!shouldEnablePagePromptShortcuts)
                .accessibilityHidden(true)
                .frame(width: 0, height: 0)
                .opacity(0.001)
            }
        }
        .frame(width: 0, height: 0)
    }

    private func shortcutKeyEquivalent(for index: Int) -> KeyEquivalent {
        let keys: [Character] = ["1", "2", "3", "4", "5", "6", "7", "8", "9", "0"]
        return KeyEquivalent(keys[index])
    }
}


private struct TranslationTargetSelector: View {
    @EnvironmentObject private var appSettings: AppSettingsStore
    @Binding var targetLanguage: String
    @Binding var showOriginalInOutput: Bool
    var isPrimaryTranslation: Bool = true
    @Environment(\.theme) private var theme

    private var savedLanguages: [String] {
        appSettings.savedTranslationLanguages
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(LocalizedStringKey("translation_target_title"))
                    .font(theme.typography.subheadline)
                    .fontWeight(.semibold)

                Spacer()

                Link(destination: URL(string: "https://hoah.app/#creative")!) {
                    HStack(spacing: 4) {
                        Text(LocalizedStringKey("translation_target_explore_creative"))
                        Image(systemName: "sparkles")
                    }
                    .font(theme.typography.caption)
            }
            .buttonStyle(.plain)
            .foregroundColor(theme.accentColor)
            .onHover { isHovering in
                if isHovering { NSCursor.pointingHand.push() }
                else { NSCursor.pop() }
            }
        }

        Text(LocalizedStringKey("translation_target_custom_hint"))
            .font(theme.typography.caption)
            .foregroundColor(theme.textSecondary)

            // Input Row
            HStack(spacing: 8) {
                TextField(
                    LocalizedStringKey("translation_target_custom_placeholder"),
                    text: $targetLanguage
                )
                .textFieldStyle(.roundedBorder)
                .onSubmit {
                    appSettings.addTranslationLanguage(targetLanguage)
                }

                Button {
                    appSettings.addTranslationLanguage(targetLanguage)
                } label: {
                    Image(systemName: "plus")
                }
                .disabled(targetLanguage.isEmpty || savedLanguages.contains(targetLanguage))
                .help("Save to quick select")
            }

            // Quick Select Chips
            if !savedLanguages.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(savedLanguages, id: \.self) { language in
                            HStack(spacing: 4) {
                                Text(language)
                                    .font(theme.typography.caption)
                                    .fontWeight(targetLanguage == language ? .bold : .regular)

                                if targetLanguage != language {
                                    Button {
                                        appSettings.removeTranslationLanguage(language)
                                    } label: {
                                        Image(systemName: "xmark")
                                            .font(theme.typography.caption2)
                                    }
                                    .buttonStyle(.plain)
                                    .opacity(0.5)
                                }
                            }
                            .padding(.vertical, 6)
                            .padding(.horizontal, 10)
                            .background(
                                Capsule()
                                    .fill(targetLanguage == language ? theme.accentColor : theme.panelBackground)
                            )
                            .foregroundColor(targetLanguage == language ? theme.primaryButtonText : theme.textPrimary)
                            .onTapGesture {
                                targetLanguage = language
                                // Add to list if not present
                                if !savedLanguages.contains(language) {
                                    appSettings.addTranslationLanguage(language)
                                }
                            }
                            .contextMenu {
                                Button("Remove") {
                                    appSettings.removeTranslationLanguage(language)
                                }
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }
            }

            Divider()
                .padding(.vertical, 4)

            // Show Original Toggle
            HStack(spacing: 12) {
                Toggle(LocalizedStringKey("translation_show_original_toggle"), isOn: $showOriginalInOutput)
                    .toggleStyle(ThemedSwitchToggleStyle(theme: theme))

                Text(LocalizedStringKey("translation_show_original_hint"))
                    .font(theme.typography.caption)
                    .foregroundColor(theme.textSecondary)
            }

            // Enable Second Translation Toggle (only shown for primary translation)
            if isPrimaryTranslation {
                Divider()
                    .padding(.vertical, 4)

                HStack(spacing: 12) {
                    Toggle(LocalizedStringKey("second_translation_toggle_title"), isOn: $appSettings.isSecondTranslationEnabled)
                        .toggleStyle(ThemedSwitchToggleStyle(theme: theme))

                    Text(LocalizedStringKey("second_translation_toggle_hint"))
                        .font(theme.typography.caption)
                        .foregroundColor(theme.textSecondary)
                }
            }
        }
        .padding(.top, 4)
        .onAppear {
            // Ensure we have defaults if empty
            if savedLanguages.isEmpty {
                appSettings.savedTranslationLanguagesRaw = TranslationTargetPresets.defaultSavedLanguagesRaw
            }

            // Map legacy ISO codes (e.g. "en") into friendly names for UI.
            if let known = TranslationLanguage.matchingLanguage(for: targetLanguage) {
                targetLanguage = known.gptName
            }

            // Ensure a selection exists (default to first saved, or English)
            if targetLanguage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                if let first = savedLanguages.first {
                    targetLanguage = first
                } else {
                    targetLanguage = "English"
                }
            }
        }
    }
}

// MARK: - Polish Mode Enhancement Options
private struct PolishEnhancementOptions: View {
    @Binding var formalWritingEnabled: Bool
    @Binding var professionalEnabled: Bool
    @Environment(\.theme) private var theme
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Usage recommendation
            HStack(spacing: 4) {
                Image(systemName: "info.circle")
                    .font(theme.typography.caption2)
                    .foregroundColor(theme.textSecondary)
                Text(LocalizedStringKey("polish_enhancement_recommendation"))
                    .font(theme.typography.caption2)
                    .foregroundColor(theme.textSecondary)
            }
            .padding(.bottom, 4)
            
            // Formal Writing Toggle
            Toggle(LocalizedStringKey("polish_formal_writing_toggle"), isOn: $formalWritingEnabled)
                .toggleStyle(ThemedSwitchToggleStyle(theme: theme))
            
            Text(LocalizedStringKey("polish_formal_writing_hint"))
                .font(theme.typography.caption2)
                .foregroundColor(theme.textSecondary)
            
            // Professional Toggle
            Toggle(LocalizedStringKey("polish_professional_toggle"), isOn: $professionalEnabled)
                .toggleStyle(ThemedSwitchToggleStyle(theme: theme))
                .padding(.top, 4)
            
            Text(LocalizedStringKey("polish_professional_hint"))
                .font(theme.typography.caption2)
                .foregroundColor(theme.textSecondary)
            
            // Combined mode indicator
            if formalWritingEnabled && professionalEnabled {
                HStack(spacing: 4) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(theme.typography.caption2)
                        .foregroundColor(theme.accentColor)
                    Text(LocalizedStringKey("polish_combined_mode_active"))
                        .font(theme.typography.caption2)
                        .foregroundColor(theme.textSecondary)
                }
                .padding(.top, 4)
            }
        }
        .padding(.top, 12)
    }
}

// MARK: - Drag & Drop Reorderable Grid
private struct ReorderablePromptGrid: View {
    @EnvironmentObject private var enhancementService: AIEnhancementService
    @Environment(\.theme) private var theme

    @Binding var boundPrompts: [CustomPrompt]
    let selectedPromptId: UUID?
    let onPromptSelected: (CustomPrompt) -> Void
    let onEditPrompt: ((CustomPrompt) -> Void)?
    let onDeletePrompt: ((CustomPrompt) -> Void)?
    var isEnabled: Bool = true
    var isPromptEnabled: ((CustomPrompt) -> Bool)? = nil
    var onTogglePromptEnabled: ((CustomPrompt, Bool) -> Void)? = nil
    var hiddenPromptIds: Set<UUID> = []

    @State private var draggingItem: CustomPrompt?

    /// Prompts to display (excludes hidden ones)
    private var visiblePrompts: [CustomPrompt] {
        boundPrompts.filter { !hiddenPromptIds.contains($0.id) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if visiblePrompts.isEmpty {
                Text(LocalizedStringKey("No prompts available"))
                    .foregroundColor(theme.textSecondary)
                    .font(theme.typography.caption)
            } else {
                let columns = [
                    GridItem(.adaptive(minimum: 100, maximum: 140), spacing: 16)
                ]

                LazyVGrid(columns: columns, spacing: 16) {
                    ForEach(Array(visiblePrompts.enumerated()), id: \.element.id) { index, prompt in
                        let promptEnabled = isPromptEnabled?(prompt) ?? true
                        let isTriggerMode = onTogglePromptEnabled != nil
                        // In trigger mode, "Usage" means "Enabled", so we treat enabled items as visually selected.
                        // In default mode, "Usage" means "Selected as default", so we check IDs.
                        let isSelected = isTriggerMode ? promptEnabled : (selectedPromptId == prompt.id)

                        VStack(spacing: 10) {
                            prompt.promptIcon(
                                isSelected: isSelected,
                                orderBadge: shortcutBadgeLabel(for: index),
                                onTap: {
                                    if let onToggle = onTogglePromptEnabled {
                                        // Trigger Mode: Toggle enabled state
                                        onToggle(prompt, !promptEnabled)
                                    } else {
                                        // Default Mode: Select as default
                                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                            onPromptSelected(prompt)
                                        }
                                    }
                                },
                                onEdit: onEditPrompt,
                                onDelete: onDeletePrompt
                            )
                            .animation(.easeInOut(duration: 0.15), value: draggingItem?.id == prompt.id)
                            .onDrag {
                                draggingItem = prompt
                                return NSItemProvider(object: prompt.id.uuidString as NSString)
                            }
                            .onDrop(
                                of: [UTType.text],
                                delegate: PromptDropDelegate(
                                    item: prompt,
                                    prompts: $boundPrompts,
                                    draggingItem: $draggingItem
                                )
                            )
                            // Toggle removed: Card tap now handles toggling
                        }
                        .opacity((draggingItem?.id == prompt.id ? 0.3 : 1.0) * (promptEnabled ? 1.0 : 0.45))
                        .scaleEffect(draggingItem?.id == prompt.id ? 1.05 : 1.0)
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .stroke(
                                    draggingItem != nil && draggingItem?.id != prompt.id
                                    ? theme.accentColor.opacity(0.25)
                                    : Color.clear,
                                    lineWidth: 1
                                )
                        )
                    }
                    
                }
                .padding(.vertical, 12)
                .padding(.horizontal, 16)
                .opacity(isEnabled ? 1 : 0.55)
                
                HStack {
                    Image(systemName: "info.circle")
                        .font(theme.typography.caption)
                        .foregroundColor(theme.textSecondary)
                    
                    Text(LocalizedStringKey("Double-click to edit • Right-click for more options"))
                        .font(theme.typography.caption)
                        .foregroundColor(theme.textSecondary)
                }
                .padding(.top, 8)
                .padding(.horizontal, 16)
            }
        }
    }

    private func shortcutBadgeLabel(for index: Int) -> String {
        index == 9 ? "0" : String(index + 1)
    }
}

// MARK: - Drop Delegates
private struct PromptDropDelegate: DropDelegate {
    let item: CustomPrompt
    @Binding var prompts: [CustomPrompt]
    @Binding var draggingItem: CustomPrompt?
    
    func dropEntered(info: DropInfo) {
        guard let draggingItem = draggingItem, draggingItem != item else { return }
        guard let fromIndex = prompts.firstIndex(of: draggingItem),
              let toIndex = prompts.firstIndex(of: item) else { return }
        
        // Move item as you hover for immediate visual update
        if prompts[toIndex].id != draggingItem.id {
            withAnimation(.easeInOut(duration: 0.12)) {
                let from = fromIndex
                let to = toIndex
                prompts.move(fromOffsets: IndexSet(integer: from), toOffset: to > from ? to + 1 : to)
            }
        }
    }
    
    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: .move)
    }
    
    func performDrop(info: DropInfo) -> Bool {
        draggingItem = nil
        return true
    }
}

private struct PromptEndDropDelegate: DropDelegate {
    @Binding var prompts: [CustomPrompt]
    @Binding var draggingItem: CustomPrompt?
    
    func validateDrop(info: DropInfo) -> Bool { true }
    func dropUpdated(info: DropInfo) -> DropProposal? { DropProposal(operation: .move) }
    
    func performDrop(info: DropInfo) -> Bool {
        guard let draggingItem = draggingItem,
              let currentIndex = prompts.firstIndex(of: draggingItem) else {
            self.draggingItem = nil
            return false
        }
        
        // Move to end if dropped on the trailing "Add New" tile
        withAnimation(.easeInOut(duration: 0.12)) {
            prompts.move(fromOffsets: IndexSet(integer: currentIndex), toOffset: prompts.endIndex)
        }
        self.draggingItem = nil
        return true
    }
}
