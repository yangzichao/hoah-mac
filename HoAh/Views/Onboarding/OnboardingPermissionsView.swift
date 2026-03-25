import SwiftUI
import AVFoundation
import AppKit

struct OnboardingPermissionsView: View {
    @Binding var hasCompletedOnboarding: Bool
    @EnvironmentObject private var appSettings: AppSettingsStore
    @Environment(\.theme) private var theme
    
    // State
    @State private var currentStep = 0
    @State private var showModelDownload = false
    
    // Managers
    @ObservedObject private var audioDeviceManager = AudioDeviceManager.shared
    
    // Steps: Microphone -> Device -> Accessibility -> (Model Download)
    private let totalSteps = 3
    
    var body: some View {
        ZStack {
            GeometryReader { geometry in
                ZStack {
                    OnboardingBackgroundView()
                    
                    VStack(spacing: 0) {
                        // Content Area
                        ZStack {
                            if currentStep == 0 {
                                MicrophonePermissionView(
                                    onGranted: {
                                        withAnimation { currentStep += 1 }
                                    }
                                )
                                .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity),
                                                      removal: .move(edge: .leading).combined(with: .opacity)))
                            } else if currentStep == 1 {
                                AudioDevicePermissionView(
                                    audioDeviceManager: audioDeviceManager,
                                    onContinue: {
                                        withAnimation { currentStep += 1 }
                                    }
                                )
                                .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity),
                                                      removal: .move(edge: .leading).combined(with: .opacity)))
                            } else if currentStep == 2 {
                                AccessibilityPermissionView(
                                    onContinue: {
                                        // Skip keyboard shortcut step, go directly to model download
                                        withAnimation { showModelDownload = true }
                                    }
                                )
                                .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity),
                                                      removal: .move(edge: .leading).combined(with: .opacity)))
                            }
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .id(currentStep)
                        
                        // Bottom Navigation (Dots only)
                        VStack(spacing: 20) {
                            HStack(spacing: 8) {
                                ForEach(0..<totalSteps, id: \.self) { index in
                                    Circle()
                                        .fill(currentStep == index ? theme.pageIndicatorActive : theme.pageIndicatorInactive)
                                        .frame(width: 8, height: 8)
                                        .scaleEffect(currentStep == index ? 1.2 : 1.0)
                                        .animation(.spring(), value: currentStep)
                                }
                            }
                        }
                        .padding(.bottom, 50)
                    }
                }
            }
            
            if showModelDownload {
                OnboardingModelDownloadView(hasCompletedOnboarding: $hasCompletedOnboarding)
                    .transition(.move(edge: .trailing).combined(with: .opacity))
            }
        }
    }
}

// MARK: - Step 1: Microphone
struct MicrophonePermissionView: View {
    let onGranted: () -> Void
    @State private var status: AVAuthorizationStatus = .notDetermined
    
    var body: some View {
        OnboardingPermissionCard(
            icon: "mic.fill",
            titleKey: "onboarding_permissions_microphone_title",
            descriptionKey: "onboarding_permissions_microphone_description",
            primaryButtonTitleKey: buttonTitleKey,
            primaryAction: requestAccess
        )
        .onAppear {
            status = AVCaptureDevice.authorizationStatus(for: .audio)
        }
    }
    
    private var buttonTitleKey: String {
        switch status {
        case .authorized: return "onboarding_permissions_button_continue"
        case .denied, .restricted: return "onboarding_permissions_open_settings"
        default: return "onboarding_permissions_button_enable"
        }
    }
    
    private func requestAccess() {
        if status == .authorized {
            onGranted()
            return
        }
        
        if status == .denied || status == .restricted {
            if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone") {
                NSWorkspace.shared.open(url)
            }
            return
        }
        
        AVCaptureDevice.requestAccess(for: .audio) { granted in
            DispatchQueue.main.async {
                status = granted ? .authorized : .denied
                if granted {
                    onGranted()
                }
            }
        }
    }
}

// MARK: - Step 2: Audio Device
struct AudioDevicePermissionView: View {
    @ObservedObject var audioDeviceManager: AudioDeviceManager
    let onContinue: () -> Void
    @Environment(\.theme) private var theme
    
    var body: some View {
        VStack(spacing: 32) {
            VStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(theme.accentColor.opacity(0.1))
                        .frame(width: 80, height: 80)
                    Image(systemName: "headphones")
                        .font(.system(size: 36))
                        .foregroundColor(theme.accentColor)
                }
                
                Text(LocalizedStringKey("onboarding_permissions_device_title"))
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundColor(theme.textPrimary)
                
                Text(LocalizedStringKey("onboarding_permissions_device_description"))
                    .font(theme.typography.body)
                    .foregroundColor(theme.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            
            // Custom Dropdown
            if audioDeviceManager.availableDevices.isEmpty {
                Text(LocalizedStringKey("No input devices found"))
                    .foregroundColor(theme.textSecondary)
                    .padding()
            } else {
                Menu {
                    ForEach(audioDeviceManager.availableDevices, id: \.id) { device in
                        Button(action: {
                            audioDeviceManager.selectDevice(id: device.id)
                            audioDeviceManager.selectInputMode(.custom)
                        }) {
                            if audioDeviceManager.selectedDeviceID == device.id {
                                Label(device.name, systemImage: "checkmark")
                            } else {
                                Text(device.name)
                            }
                        }
                    }
                } label: {
                    HStack {
                        Text(currentDeviceName)
                            .foregroundColor(theme.textPrimary)
                            .lineLimit(1)
                        Spacer()
                        Image(systemName: "chevron.up.chevron.down")
                            .foregroundColor(theme.textMuted)
                    }
                    .padding()
                    .frame(width: 280)
                    .background(theme.panelBackground)
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(theme.panelBorder, lineWidth: 1)
                    )
                }
                .menuStyle(.borderlessButton)
            }
            
            Button(action: onContinue) {
                Text(LocalizedStringKey("onboarding_permissions_button_continue"))
                    .font(theme.typography.headline)
                    .foregroundColor(theme.primaryButtonText)
                    .frame(width: 200, height: 50)
                    .background(theme.accentColor)
                    .cornerRadius(25)
            }
            .buttonStyle(ScaleButtonStyle())
        }
        .padding(40)
        .frame(maxWidth: 450)
        .background(theme.inputBackground)
        .cornerRadius(24)
        .overlay(
            RoundedRectangle(cornerRadius: 24)
                .stroke(theme.panelBorder, lineWidth: 1)
        )
        .onAppear {
            audioDeviceManager.loadAvailableDevices()
            // Auto-select logic if needed (and list is not empty)
            if audioDeviceManager.selectedDeviceID == nil && !audioDeviceManager.availableDevices.isEmpty {
               autoSelectDevice()
            }
        }
    }
    
    private var currentDeviceName: String {
        if let id = audioDeviceManager.selectedDeviceID,
           let device = audioDeviceManager.availableDevices.first(where: { $0.id == id }) {
            return device.name
        }
        return NSLocalizedString("Select Device", comment: "")
    }
    
    private func autoSelectDevice() {
        let builtIn = audioDeviceManager.availableDevices.first {
            $0.name.localizedCaseInsensitiveContains("built-in") ||
            $0.name.localizedCaseInsensitiveContains("internal")
        }
        if let device = builtIn ?? audioDeviceManager.availableDevices.first {
            audioDeviceManager.selectDevice(id: device.id)
            audioDeviceManager.selectInputMode(.custom)
        }
    }
}

// MARK: - Step 3: Accessibility
struct AccessibilityPermissionView: View {
    let onContinue: () -> Void
    @State private var isTrusted = false
    @State private var showRestartAlert = false
    @Environment(\.theme) private var theme
    
    var body: some View {
        OnboardingPermissionCard(
            icon: "accessibility",
            titleKey: "onboarding_permissions_accessibility_title",
            descriptionKey: "onboarding_permissions_accessibility_description",
            primaryButtonTitleKey: isTrusted ? "onboarding_permissions_button_continue" : "onboarding_permissions_open_settings",
            primaryAction: {
                if isTrusted {
                    onContinue()
                } else {
                    openSettings()
                }
            },
            secondaryAction: {
                if !isTrusted {
                     Button {
                         checkTrust()
                         if isTrusted {
                             onContinue()
                         } else {
                             showRestartAlert = true
                         }
                     } label: {
                         Text(LocalizedStringKey("onboarding_permissions_accessibility_authorized_restart"))
                     }
                     .buttonStyle(.plain)
                     .foregroundColor(theme.textMuted)
                     .font(theme.typography.subheadline)
                }
            }
        )
        .alert(isPresented: $showRestartAlert) {
            Alert(
                title: Text(LocalizedStringKey("onboarding_restart_required_title")),
                message: Text(LocalizedStringKey("onboarding_restart_required_message")),
                primaryButton: .default(Text(LocalizedStringKey("onboarding_restart_now")), action: restartApp),
                secondaryButton: .cancel(Text(LocalizedStringKey("Cancel")))
            )
        }
        .onAppear {
            checkTrust()
        }
        .onReceive(Timer.publish(every: 1, on: .main, in: .common).autoconnect()) { _ in
            checkTrust()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            checkTrust()
        }
    }
    
    private func checkTrust() {
        isTrusted = AXIsProcessTrusted()
    }
    
    private func openSettings() {
        let options: NSDictionary = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
        AXIsProcessTrustedWithOptions(options)
        
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }
    
    private func restartApp() {
        let appURL = Bundle.main.bundleURL
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = true
        configuration.createsNewApplicationInstance = true
        
        NSWorkspace.shared.openApplication(at: appURL, configuration: configuration) { _, _ in
             DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                 NSApp.terminate(nil)
             }
        }
    }
}

// MARK: - Reusable Card Component
struct OnboardingPermissionCard<SecondaryView: View>: View {
    let icon: String
    let titleKey: String
    let descriptionKey: String
    let primaryButtonTitleKey: String
    let primaryAction: () -> Void
    let secondaryAction: (() -> SecondaryView)?
    @Environment(\.theme) private var theme
    
    init(icon: String, 
         titleKey: String, 
         descriptionKey: String, 
         primaryButtonTitleKey: String, 
         primaryAction: @escaping () -> Void, 
         @ViewBuilder secondaryAction: @escaping () -> SecondaryView) {
        self.icon = icon
        self.titleKey = titleKey
        self.descriptionKey = descriptionKey
        self.primaryButtonTitleKey = primaryButtonTitleKey
        self.primaryAction = primaryAction
        self.secondaryAction = secondaryAction
    }
    
    var body: some View {
        VStack(spacing: 32) {
            VStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(theme.accentColor.opacity(0.1))
                        .frame(width: 80, height: 80)
                    Image(systemName: icon)
                        .font(.system(size: 36))
                        .foregroundColor(theme.accentColor)
                }
                
                Text(LocalizedStringKey(titleKey))
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundColor(theme.textPrimary)
                
                Text(LocalizedStringKey(descriptionKey))
                    .font(theme.typography.body)
                    .foregroundColor(theme.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            
            VStack(spacing: 16) {
                Button(action: primaryAction) {
                    Text(LocalizedStringKey(primaryButtonTitleKey))
                        .font(theme.typography.headline)
                        .foregroundColor(theme.primaryButtonText)
                        .frame(width: 220, height: 50)
                        .background(theme.accentColor)
                        .cornerRadius(25)
                }
                .buttonStyle(ScaleButtonStyle())
                
                if let secondaryAction = secondaryAction {
                    secondaryAction()
                }
            }
        }
        .padding(40)
        .frame(maxWidth: 450)
        .background(theme.inputBackground)
        .cornerRadius(24)
        .overlay(
            RoundedRectangle(cornerRadius: 24)
                .stroke(theme.panelBorder, lineWidth: 1)
        )
    }
}

extension OnboardingPermissionCard where SecondaryView == EmptyView {
    init(icon: String, titleKey: String, descriptionKey: String, primaryButtonTitleKey: String, primaryAction: @escaping () -> Void) {
        self.init(icon: icon, titleKey: titleKey, descriptionKey: descriptionKey, primaryButtonTitleKey: primaryButtonTitleKey, primaryAction: primaryAction, secondaryAction: { EmptyView() })
    }
}
