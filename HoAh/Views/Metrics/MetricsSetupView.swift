import SwiftUI
import KeyboardShortcuts

struct MetricsSetupView: View {
    @EnvironmentObject private var whisperState: WhisperState
    @EnvironmentObject private var hotkeyManager: HotkeyManager
    @State private var isAccessibilityEnabled = AXIsProcessTrusted()
    @Environment(\.theme) private var theme
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header
                VStack(spacing: 12) {
                    AppIconView()
                        .frame(width: 80, height: 80)
                        .padding(.bottom, 20)
                       
                    VStack(spacing: 4) {
                        Text("Welcome to HoAh")
                            .font(theme.typography.title)
                            .multilineTextAlignment(.center)
                        
                        Text("Complete the setup to get started")
                            .font(theme.typography.subheadline)
                            .foregroundColor(theme.textSecondary)
                            .multilineTextAlignment(.center)
                    }
                }
                .padding(.top, 20)
                .padding(.bottom, 20)
                
                // Setup Steps
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(0..<3) { index in
                        setupStep(for: index)
                        if index < 2 {
                            Divider().padding(.leading, 70)
                        }
                    }
                }
                .background(theme.windowBackground)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(theme.panelBorder, lineWidth: 1)
                )
                .padding(.horizontal)
                
                Spacer(minLength: 20)
                
                // Action Button
                actionButton
                    .frame(maxWidth: 400)
                
                // Help Text
                helpText
            }
            .padding()
        }
        .frame(minWidth: 500, minHeight: 600)
        .background(theme.controlBackground)
    }
    
    private func setupStep(for index: Int) -> some View {
        let stepInfo: (isCompleted: Bool, icon: String, title: String, description: String)
        
        switch index {
        case 0:
            stepInfo = (
                isCompleted: hotkeyManager.hasConfiguredRecordingTrigger,
                icon: "command",
                title: "Set Keyboard Shortcut",
                description: "Use HoAh anywhere with a shortcut."
            )
        case 1:
            stepInfo = (
                isCompleted: isAccessibilityEnabled,
                icon: "hand.raised.fill",
                title: "Enable Accessibility",
                description: "Paste transcribed text at your cursor."
            )
        default:
            stepInfo = (
                isCompleted: whisperState.currentTranscriptionModel != nil,
                icon: "arrow.down.to.line",
                title: "Download Model",
                description: "Choose an AI model to start transcribing."
            )
        }
        
        return HStack(spacing: 16) {
            Image(systemName: stepInfo.icon)
                .font(.system(size: 18))
                .frame(width: 40, height: 40)
                .background((stepInfo.isCompleted ? theme.statusSuccess : theme.accentColor).opacity(0.1))
                .foregroundColor(stepInfo.isCompleted ? theme.statusSuccess : theme.accentColor)
                .clipShape(Circle())
            
            VStack(alignment: .leading, spacing: 3) {
                Text(stepInfo.title)
                    .font(theme.typography.headline)
                    .fontWeight(.semibold)
                Text(stepInfo.description)
                    .font(theme.typography.subheadline)
                    .foregroundColor(theme.textSecondary)
            }
            
            Spacer()
            
            if stepInfo.isCompleted {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 24))
                    .foregroundColor(theme.statusSuccess)
            } else {
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(theme.separatorColor)
            }
        }
        .padding()
    }
    
    private var actionButton: some View {
        Button(action: handleActionButton) {
            HStack {
                Text(getActionButtonTitle())
                    .fontWeight(.semibold)
                Image(systemName: "arrow.right")
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(theme.accentColor)
            .foregroundColor(theme.primaryButtonText)
            .cornerRadius(12)
        }
        .buttonStyle(.plain)
        .shadow(color: theme.accentColor.opacity(0.3), radius: 8, y: 4)
    }
    
    private func handleActionButton() {
        if isShortcutAndAccessibilityGranted {
            openModelManagement()
        } else {
            // Handle different permission requests based on which one is missing
            if !hotkeyManager.hasConfiguredRecordingTrigger {
                openSettings()
            } else if !AXIsProcessTrusted() {
                if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
                    NSWorkspace.shared.open(url)
                }
            } else if whisperState.currentTranscriptionModel == nil {
                openModelManagement()
            }
        }
    }
    
    private func getActionButtonTitle() -> String {
        if !hotkeyManager.hasConfiguredRecordingTrigger {
            return "Configure Shortcut"
        } else if !AXIsProcessTrusted() {
            return "Enable Accessibility"
        } else if whisperState.currentTranscriptionModel == nil {
            return "Download Model"
        }
        return "Get Started"
    }
    
    private var helpText: some View {
        Text("Need help? Check the Help menu for support options")
            .font(theme.typography.caption)
            .foregroundColor(theme.textSecondary)
    }
    
    private var isShortcutAndAccessibilityGranted: Bool {
        hotkeyManager.hasConfiguredRecordingTrigger &&
        AXIsProcessTrusted()
    }
    
    private func openSettings() {
        NotificationCenter.default.post(
            name: .navigateToDestination,
            object: nil,
            userInfo: ["destination": "Settings"]
        )
    }
    
    private func openModelManagement() {
        NotificationCenter.default.post(
            name: .navigateToDestination,
            object: nil,
            userInfo: ["destination": "Dictation Models"]
        )
    }
}
