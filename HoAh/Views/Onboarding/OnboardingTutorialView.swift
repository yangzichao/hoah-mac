import SwiftUI
import KeyboardShortcuts

struct OnboardingTutorialView: View {
    @Binding var hasCompletedOnboarding: Bool
    @EnvironmentObject private var hotkeyManager: HotkeyManager
    @EnvironmentObject private var localizationManager: LocalizationManager
    @Environment(\.theme) private var theme
    
    @State private var currentStep = 0
    @State private var isAnimating = false
    
    private let totalSteps = 3
    private var maxStep: Int { totalSteps - 1 }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Shared Background
                OnboardingBackgroundView()
                
                VStack(spacing: 0) {
                    // Main Content Area
                    ZStack {
                        if displayStep == 0 {
                            BasicsStepView(hotkeyManager: hotkeyManager)
                                .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity),
                                                      removal: .move(edge: .leading).combined(with: .opacity)))
                        } else if displayStep == 1 {
                            AIFeaturesStepView(localizationManager: localizationManager)
                                .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity),
                                                      removal: .move(edge: .leading).combined(with: .opacity)))
                        } else if displayStep == 2 {
                            ProTipsStepView(hasCompletedOnboarding: $hasCompletedOnboarding)
                                .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity),
                                                      removal: .move(edge: .leading).combined(with: .opacity)))
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .id(displayStep) // Force refresh for transitions
                    
                    // Bottom Navigation Bar
                    VStack(spacing: 20) {
                        // Page Indicators
                        HStack(spacing: 8) {
                            ForEach(0..<totalSteps, id: \.self) { index in
                                Circle()
                                    .fill(displayStep == index ? theme.pageIndicatorActive : theme.pageIndicatorInactive)
                                    .frame(width: 8, height: 8)
                                    .scaleEffect(displayStep == index ? 1.2 : 1.0)
                                    .animation(.spring(), value: displayStep)
                            }
                        }
                        
                        // Navigation Buttons
                        HStack {
                            if displayStep > 0 {
                                Button(LocalizedStringKey("onboarding_tutorial_back")) {
                                    retreatStep()
                                }
                                .buttonStyle(.plain)
                                .foregroundColor(theme.textMuted)
                                .font(.system(size: 16, weight: .medium))
                            }
                            
                            Spacer()
                            
                            if displayStep < maxStep {
                                Button(action: {
                                    advanceStep()
                                }) {
                                    HStack(spacing: 4) {
                                        Text(LocalizedStringKey("onboarding_tutorial_next"))
                                        Image(systemName: "arrow.right")
                                    }
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(theme.primaryButtonText)
                                    .padding(.horizontal, 24)
                                    .padding(.vertical, 12)
                                    .background(theme.accentColor)
                                    .cornerRadius(20)
                                }
                                .buttonStyle(ScaleButtonStyle())
                            }
                        }
                        .frame(width: 300) // Constrain width of nav bar
                    }
                    .padding(.bottom, 50)
                }
            }
        }
    }
    
    private var displayStep: Int {
        min(max(currentStep, 0), maxStep)
    }
    
    private func advanceStep() {
        withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
            currentStep = min(currentStep + 1, maxStep)
        }
    }
    
    private func retreatStep() {
        withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
            currentStep = max(currentStep - 1, 0)
        }
    }
}

// MARK: - Step 1: Basics
struct BasicsStepView: View {
    @ObservedObject var hotkeyManager: HotkeyManager
    @EnvironmentObject private var whisperState: WhisperState
    @Environment(\.theme) private var theme
    
    @State private var transcriptionResult: String = ""
    @State private var hasDetectedHotkey = false
    @State private var isShortcutSheetPresented = false
    @State private var previousHotkey: HotkeyManager.HotkeyOption?
    
    var body: some View {
        VStack(spacing: 40) {
            // Header
            VStack(spacing: 8) {
                Text(LocalizedStringKey("onboarding_tutorial_basics_title"))
                    .font(.system(size: 36, weight: .bold, design: .rounded))
                    .foregroundColor(theme.textPrimary)
                Text(LocalizedStringKey("onboarding_tutorial_basics_subtitle"))
                    .font(theme.typography.title3)
                    .foregroundColor(theme.textSecondary)
            }
            
            HStack(alignment: .center, spacing: 48) {
                // Left Column: Input / Trigger
                VStack(spacing: 32) {
                    Text(LocalizedStringKey("onboarding_try_it_title"))
                        .font(theme.typography.headline)
                        .foregroundColor(theme.textPrimary)
                        .padding(.bottom, -12) // Slightly pull closer to the visual
                    
                    // The Key - prominent display
                    ZStack {
                        RoundedRectangle(cornerRadius: 24)
                            .fill(theme.keyCardBackground)
                            .frame(width: 140, height: 140)
                            .shadow(color: theme.keyCardShadow, radius: 20, x: 0, y: 10)
                            .overlay(
                                RoundedRectangle(cornerRadius: 24)
                                    .stroke(theme.keyCardBorder, lineWidth: 1)
                            )
                        
                        VStack(spacing: 8) {
                            if let shortcut = hotkeyManager.primaryHotkeyShortcut {
                                KeyboardShortcutView(shortcut: shortcut)
                                    .scaleEffect(0.9)
                            } else if showsOptionIcon {
                                Image(systemName: "option")
                                    .font(.system(size: 56))
                            } else {
                                KeyCapView(text: fallbackModifierSymbol)
                            }
                            Text(hotkeyManager.primaryHotkeyDisplayNameShort)
                                .font(.system(size: 16, weight: .bold))
                        }
                        .foregroundColor(theme.textPrimary)
                    }

                    // Instructions
                    VStack(spacing: 6) {
                        Text(primaryHotkeyInstructionText)
                            .font(theme.typography.body)
                            .fontWeight(.medium)
                            .foregroundColor(theme.textPrimary.opacity(0.95))
                    }
                    .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                
                // Right Column: Feedback / Output
                VStack(spacing: 20) {
                    // Hotkey self-test + fallback
                    VStack(spacing: 12) {
                        HStack(spacing: 10) {
                            Circle()
                                .fill(hasDetectedHotkey ? theme.statusSuccess : theme.statusPending)
                                .frame(width: 10, height: 10)
                                .shadow(color: hasDetectedHotkey ? theme.statusSuccess.opacity(0.5) : Color.clear, radius: 4)
                            
                            Text(hasDetectedHotkey
                                 ? LocalizedStringKey("onboarding_hotkey_test_success")
                                 : LocalizedStringKey("onboarding_hotkey_test_pending"))
                                .font(theme.typography.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(theme.textPrimary.opacity(0.9))
                            
                            Spacer()
                        }
                        
                        if !hasDetectedHotkey {
                            Text(LocalizedStringKey("onboarding_hotkey_test_help"))
                                .font(theme.typography.caption)
                                .foregroundColor(theme.textMuted)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .fixedSize(horizontal: false, vertical: true)

                            Button(LocalizedStringKey("onboarding_hotkey_test_custom_button")) {
                                previousHotkey = hotkeyManager.selectedHotkey1
                                hotkeyManager.selectedHotkey1 = .custom
                                isShortcutSheetPresented = true
                            }
                            .buttonStyle(.plain)
                            .font(theme.typography.caption)
                            .fontWeight(.medium)
                            .foregroundColor(theme.textPrimary)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(theme.panelButtonBackground)
                            .cornerRadius(8)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    .padding(20)
                    .background(theme.panelBackground)
                    .cornerRadius(16)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(theme.panelBorder, lineWidth: 1)
                    )
                    
                    // Result text field
                    ZStack(alignment: .topLeading) {
                        RoundedRectangle(cornerRadius: 16)
                            .fill(theme.inputBackground)
                            .cornerRadius(16)
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(theme.inputBorder, lineWidth: 1)
                            )
                        
                        if transcriptionResult.isEmpty {
                            HStack(spacing: 8) {
                                Image(systemName: "mic")
                                    .foregroundColor(theme.textMuted.opacity(0.5))
                                Text(LocalizedStringKey("onboarding_try_it_placeholder"))
                            }
                            .font(theme.typography.body)
                            .foregroundColor(theme.textMuted.opacity(0.7))
                            .padding(20)
                        } else {
                            ScrollView {
                                Text(transcriptionResult)
                                    .font(theme.typography.body)
                                    .foregroundColor(theme.textPrimary)
                                    .padding(20)
                                    .frame(maxWidth: .infinity, alignment: .topLeading)
                            }
                        }
                    }
                    .frame(height: 140) // Fixed height to match visuals better
                }
                .frame(maxWidth: .infinity)
            }
            .padding(.horizontal, 20)
            
            // Quick tips
            HStack(spacing: 32) {
                HStack(spacing: 8) {
                    Image(systemName: "xmark.circle")
                    Text(LocalizedStringKey("onboarding_tutorial_escape_tip"))
                }
                
                HStack(spacing: 8) {
                    Image(systemName: "doc.on.clipboard")
                    Text(LocalizedStringKey("onboarding_tutorial_clipboard_tip"))
                }
                
                HStack(spacing: 8) {
                    Image(systemName: "gearshape")
                    Text(LocalizedStringKey("onboarding_tutorial_hotkey_tip"))
                }
            }
            .font(theme.typography.caption)
            .fontWeight(.medium)
            .foregroundColor(theme.textMuted.opacity(0.8))
            .padding(.top, 10)
        }
        .padding(.vertical, 20)
        .padding(.horizontal, 40)
        .onReceive(NotificationCenter.default.publisher(for: .transcriptionCompleted)) { notification in
            if let transcription = notification.object as? Transcription {
                transcriptionResult = transcription.text
            }
        }
        .onChange(of: whisperState.isMiniRecorderVisible) { _, newValue in
            if newValue {
                hasDetectedHotkey = true
            }
        }
        .sheet(isPresented: $isShortcutSheetPresented) {
            VStack(spacing: 16) {
                Text(LocalizedStringKey("onboarding_hotkey_sheet_title"))
                    .font(theme.typography.headline)
                Text(LocalizedStringKey("onboarding_hotkey_sheet_desc"))
                    .font(theme.typography.caption)
                    .foregroundColor(theme.textSecondary)
                KeyboardShortcuts.Recorder(for: .toggleMiniRecorder) { _ in
                    hotkeyManager.updateShortcutStatus()
                }
                    .controlSize(.regular)
                Button(LocalizedStringKey("onboarding_hotkey_sheet_done")) {
                    isShortcutSheetPresented = false
                }
                .buttonStyle(.borderedProminent)
            }
            .padding(24)
            .frame(minWidth: 360)
            .onDisappear {
                if KeyboardShortcuts.getShortcut(for: .toggleMiniRecorder) == nil,
                   let previousHotkey = previousHotkey,
                   previousHotkey != .custom {
                    hotkeyManager.selectedHotkey1 = previousHotkey
                }
                previousHotkey = nil
            }
        }
    }

    private var showsOptionIcon: Bool {
        hotkeyManager.selectedHotkey1 == .rightOption || hotkeyManager.selectedHotkey1 == .leftOption
    }

    private var fallbackModifierSymbol: String {
        switch hotkeyManager.selectedHotkey1 {
        case .leftControl, .rightControl:
            return "⌃"
        case .rightCommand:
            return "⌘"
        case .rightShift:
            return "⇧"
        case .fn:
            return "Fn"
        default:
            return "⌥"
        }
    }

    private var primaryHotkeyInstructionText: String {
        String(
            format: NSLocalizedString("onboarding_try_instruction_dynamic", comment: "Onboarding hotkey instruction"),
            hotkeyManager.primaryHotkeyDisplayNameShort
        )
    }
}

struct ActionInstruction: View {
    let textKey: String
    let icon: String?
    @Environment(\.theme) private var theme
    
    var body: some View {
        VStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(theme.panelBackground)
                    .frame(width: 70, height: 70)
                
                if let icon = icon {
                    Image(systemName: icon)
                        .font(.system(size: 28))
                        .foregroundColor(theme.textPrimary.opacity(0.8))
                } else {
                    Text(LocalizedStringKey(textKey))
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(theme.textPrimary.opacity(0.8))
                }
            }
            
            // Label below if it was an icon
            if icon != nil {
                Text(LocalizedStringKey(textKey))
                    .font(theme.typography.caption)
                    .fontWeight(.medium)
                    .foregroundColor(theme.textMuted)
            } else {
                Text(" ") // Spacer to align baseline
                    .font(theme.typography.caption)
            }
        }
    }
}

// MARK: - Step 2: AI Features
struct AIFeaturesStepView: View {
    @ObservedObject var localizationManager: LocalizationManager
    @Environment(\.theme) private var theme
    
    var body: some View {
        VStack(alignment: .center, spacing: 32) {
            VStack(spacing: 16) {
                Text(LocalizedStringKey("onboarding_tutorial_ai_title"))
                    .font(.system(size: 40, weight: .bold, design: .rounded))
                    .foregroundColor(theme.textPrimary)
                Text(LocalizedStringKey("onboarding_tutorial_ai_subtitle"))
                    .font(theme.typography.title2)
                    .foregroundColor(theme.textSecondary)
            }
            
            HStack(spacing: 24) {
                // Feature 1: Polish
                FeatureCard(
                    icon: "wand.and.stars",
                    titleKey: "onboarding_tutorial_polish_title",
                    descriptionKey: "onboarding_tutorial_polish_description"
                )
                
                // Feature 2: Translate
                FeatureCard(
                    icon: "globe",
                    titleKey: "onboarding_tutorial_translate_title",
                    descriptionKey: "onboarding_tutorial_translate_description"
                )
            }
            .frame(height: 280)

            VStack(alignment: .leading, spacing: 8) {
                Text(LocalizedStringKey("onboarding_tutorial_ai_setup_title"))
                    .font(theme.typography.headline)
                    .foregroundColor(theme.textPrimary)
                
                Text(LocalizedStringKey("onboarding_tutorial_ai_setup_bullet1"))
                    .font(theme.typography.subheadline)
                    .foregroundColor(theme.textSecondary)
                
                Text(LocalizedStringKey("onboarding_tutorial_ai_setup_bullet2"))
                    .font(theme.typography.subheadline)
                    .foregroundColor(theme.textSecondary)
                
                Text(LocalizedStringKey("onboarding_tutorial_ai_setup_bullet3"))
                    .font(theme.typography.subheadline)
                    .foregroundColor(theme.textSecondary)
                
                Text(LocalizedStringKey("onboarding_tutorial_ai_setup_bullet4"))
                    .font(theme.typography.subheadline)
                    .foregroundColor(theme.textSecondary)
            }
            .padding(20)
            .background(theme.panelBackground)
            .cornerRadius(16)
        }
        .padding()
    }
}

// MARK: - Step 3: Why HoAh
struct ProTipsStepView: View {
    @Binding var hasCompletedOnboarding: Bool
    @Environment(\.theme) private var theme
    
    private let features: [(icon: String, titleKey: String)] = [
        ("lock.shield.fill", "onboarding_feature_private"),
        ("gift.fill", "onboarding_feature_free"),
        ("nosign", "onboarding_feature_no_ads"),
        ("person.fill.xmark", "onboarding_feature_no_signup"),
        ("eye.slash.fill", "onboarding_feature_opensource"),
        ("leaf.fill", "onboarding_feature_minimal")
    ]
    
    var body: some View {
        VStack(alignment: .center, spacing: 32) {
            VStack(spacing: 12) {
                Text(LocalizedStringKey("onboarding_tutorial_privacy_title"))
                    .font(.system(size: 36, weight: .bold, design: .rounded))
                    .foregroundColor(theme.textPrimary)
                Text(LocalizedStringKey("onboarding_tutorial_privacy_subtitle"))
                    .font(theme.typography.title3)
                    .foregroundColor(theme.textSecondary)
            }
            
            // Features Grid - 2x3
            VStack(spacing: 16) {
                HStack(spacing: 16) {
                    ForEach(0..<3, id: \.self) { index in
                        FeatureBadge(icon: features[index].icon, titleKey: features[index].titleKey)
                    }
                }
                HStack(spacing: 16) {
                    ForEach(3..<6, id: \.self) { index in
                        FeatureBadge(icon: features[index].icon, titleKey: features[index].titleKey)
                    }
                }
            }
            .padding(24)
            .background(theme.panelBackground)
            .cornerRadius(20)
            
            // Tagline
            Text(LocalizedStringKey("onboarding_tagline"))
                .font(theme.typography.subheadline)
                .foregroundColor(theme.textMuted.opacity(0.8))
                .multilineTextAlignment(.center)
            
            Button(action: {
                withAnimation {
                    hasCompletedOnboarding = true
                }
            }) {
                Text(LocalizedStringKey("onboarding_tutorial_start_button"))
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(theme.primaryButtonText)
                    .frame(width: 240, height: 60)
                    .background(theme.accentColor)
                    .cornerRadius(30)
                    .shadow(color: theme.keyCardShadow, radius: 10, x: 0, y: 5)
            }
            .buttonStyle(ScaleButtonStyle())
        }
        .padding()
    }
}

struct FeatureBadge: View {
    let icon: String
    let titleKey: String
    @Environment(\.theme) private var theme
    
    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 24))
                .foregroundColor(theme.accentColor)
            Text(LocalizedStringKey(titleKey))
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(theme.textPrimary.opacity(0.9))
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.8)
        }
        .frame(width: 100, height: 80)
        .background(theme.panelBackground)
        .cornerRadius(12)
    }
}

struct FeatureCard: View {
    let icon: String
    let titleKey: String
    let descriptionKey: String
    @Environment(\.theme) private var theme
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 32))
                .foregroundColor(theme.accentColor)
                .padding(12)
                .background(theme.accentColor.opacity(0.1))
                .clipShape(Circle())
            
            Text(LocalizedStringKey(titleKey))
                .font(theme.typography.title3)
                .fontWeight(.bold)
                .foregroundColor(theme.textPrimary)
            
            Text(LocalizedStringKey(descriptionKey))
                .font(.system(size: 15))
                .foregroundColor(theme.textSecondary)
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)
            
            Spacer()
        }
        .padding(24)
        .frame(width: 240)
        .background(theme.panelBackground)
        .cornerRadius(20)
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(theme.panelBorder, lineWidth: 1)
        )
    }
} 
