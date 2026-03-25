import SwiftUI
import AppKit

struct HelpView: View {
    @EnvironmentObject private var appSettings: AppSettingsStore
    @State private var showResetConfirmation = false
    @Environment(\.theme) private var theme
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Resources Section
                VStack(alignment: .leading, spacing: 16) {
                    // User Guide
                    
                    // User Guide
                    Link(destination: URL(string: "https://hoah.app/guide/")!) {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(LocalizedStringKey("help_user_guide_title"))
                                    .foregroundColor(theme.textPrimary)
                                    .fontWeight(.medium)
                                Text(LocalizedStringKey("help_user_guide_desc"))
                                    .font(theme.typography.caption)
                                    .foregroundColor(theme.textSecondary)
                            }
                            Spacer()
                            Image(systemName: "arrow.up.right")
                                .font(theme.typography.subheadline)
                                .foregroundColor(theme.textSecondary)
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)

                    Divider()

                    // API Setup Guide
                    Link(destination: URL(string: "https://hoah.app/help/")!) {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(LocalizedStringKey("help_api_guide_title"))
                                    .foregroundColor(theme.textPrimary)
                                    .fontWeight(.medium)
                                Text(LocalizedStringKey("help_api_guide_desc"))
                                    .font(theme.typography.caption)
                                    .foregroundColor(theme.textSecondary)
                            }
                            Spacer()
                            Image(systemName: "arrow.up.right")
                                .font(theme.typography.subheadline)
                                .foregroundColor(theme.textSecondary)
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)

                    Divider()

                    // Official Website
                    Link(destination: URL(string: "https://hoah.app/")!) {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(LocalizedStringKey("help_documentation_title"))
                                    .foregroundColor(theme.textPrimary)
                                    .fontWeight(.medium)
                                Text(LocalizedStringKey("help_documentation_desc"))
                                    .font(theme.typography.caption)
                                    .foregroundColor(theme.textSecondary)
                            }
                            Spacer()
                            Image(systemName: "arrow.up.right")
                                .font(theme.typography.subheadline)
                                .foregroundColor(theme.textSecondary)
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
                .padding(20)
                .background(theme.controlBackground)
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(theme.panelBorder, lineWidth: 1)
                )

                SettingsSection(
                    icon: "wrench.and.screwdriver.fill",
                    title: "help_troubleshooting_title",
                    subtitle: "help_troubleshooting_desc"
                ) {
                    VStack(alignment: .leading, spacing: 16) {
                        // Reset Onboarding
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(LocalizedStringKey("help_reset_onboarding_title"))
                                    .font(theme.typography.body)
                                Text(LocalizedStringKey("help_reset_onboarding_desc"))
                                    .font(theme.typography.caption)
                                    .foregroundColor(theme.textSecondary)
                            }
                            Spacer()
                            Button(LocalizedStringKey("help_reset_flow_button")) {
                                appSettings.hasCompletedOnboarding = false
                            }
                        }
                        
                        Divider()
                        
                        // Reset System Settings
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(LocalizedStringKey("help_reset_prefs_title"))
                                    .font(theme.typography.body)
                                Text(LocalizedStringKey("help_reset_prefs_desc"))
                                    .font(theme.typography.caption)
                                    .foregroundColor(theme.textSecondary)
                            }
                            Spacer()
                            Button(LocalizedStringKey("help_reset_defaults_button")) {
                                showResetConfirmation = true
                            }
                            .alert(LocalizedStringKey("help_reset_confirm_title"), isPresented: $showResetConfirmation) {
                                Button(LocalizedStringKey("help_reset_button"), role: .destructive) {
                                    appSettings.resetSystemSettings()
                                }
                                Button(LocalizedStringKey("help_cancel_button"), role: .cancel) { }
                            } message: {
                                Text(LocalizedStringKey("help_reset_confirm_message"))
                            }
                        }
                        
                        Divider()
                        
                        // Restart App
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(LocalizedStringKey("help_restart_app_title"))
                                    .font(theme.typography.body)
                                Text(LocalizedStringKey("help_restart_app_desc"))
                                    .font(theme.typography.caption)
                                    .foregroundColor(theme.textSecondary)
                            }
                            Spacer()
                            Button(LocalizedStringKey("help_restart_button")) {
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
                    }
                }
            }
            .padding(20)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(theme.windowBackground)
    }
}
