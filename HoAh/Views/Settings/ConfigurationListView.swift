import SwiftUI

/// Displays a simple list of AI Enhancement configuration profiles
/// Allows selecting, editing, and deleting configurations
struct ConfigurationListView: View {
    @EnvironmentObject private var appSettings: AppSettingsStore
    @EnvironmentObject private var validationService: ConfigurationValidationService
    @Binding var showingAddSheet: Bool
    @Environment(\.theme) private var theme
    @State private var configToEdit: AIEnhancementConfiguration?
    @State private var configToDelete: AIEnhancementConfiguration?
    @State private var showDeleteConfirmation = false
    @State private var pendingConfigToEnable: AIEnhancementConfiguration?
    @State private var showEnablePrompt = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                Text(NSLocalizedString("AI Configurations", comment: ""))
                    .font(theme.typography.headline)

                Link(destination: URL(string: "https://hoah.app/help/")!) {
                     HStack(spacing: 4) {
                         Image(systemName: "gift.fill") // Gift icon appealing for free stuff
                             .foregroundColor(theme.statusWarning)
                         Text(NSLocalizedString("How to get a free API Key?", comment: "Help link"))
                     }
                     .font(theme.typography.caption)
                     .foregroundColor(theme.statusInfo)
                }
                .buttonStyle(.plain)
                .padding(.leading, 8)
                .onHover { isHovering in
                    if isHovering { NSCursor.pointingHand.push() }
                    else { NSCursor.pop() }
                }

                Spacer()

                Button {
                    showingAddSheet = true
                } label: {
                    Image(systemName: "plus")
                }
                .buttonStyle(.borderless)
                .help(NSLocalizedString("Add Configuration", comment: ""))
            }

            // Configuration List
            if appSettings.aiEnhancementConfigurations.isEmpty {
                Text(NSLocalizedString("No configurations. Click + to add one.", comment: ""))
                    .font(theme.typography.caption)
                    .foregroundColor(theme.textSecondary)
                    .padding(.vertical, 8)
            } else {
                VStack(spacing: 0) {
                    ForEach(appSettings.aiEnhancementConfigurations) { config in
                        AIConfigurationRow(
                            configuration: config,
                            isActive: appSettings.activeAIConfigurationId == config.id,
                            isValidating: validationService.validatingConfigId == config.id,
                            showSuccess: validationService.lastSuccessConfigId == config.id,
                            validationError: validationService.validatingConfigId == nil && validationService.validationErrorConfigId == config.id
                                ? validationService.validationError
                                : nil,
                            onSelect: {
                                if appSettings.isAIEnhancementEnabled {
                                    validationService.switchToConfiguration(id: config.id)
                                } else {
                                    pendingConfigToEnable = config
                                    showEnablePrompt = true
                                }
                            },
                            onEdit: {
                                configToEdit = config
                            },
                            onDelete: {
                                configToDelete = config
                                showDeleteConfirmation = true
                            },
                            onDismissError: {
                                validationService.clearError()
                            },
                            onRetry: {
                                validationService.switchToConfiguration(id: config.id, forceRefresh: true)
                            }
                        )

                        if config.id != appSettings.aiEnhancementConfigurations.last?.id {
                            Divider()
                                .padding(.leading, 32)
                        }
                    }
                }
                .background(theme.controlBackground)
                .cornerRadius(8)
            }
        }
        .sheet(isPresented: $showingAddSheet) {
            ConfigurationEditSheet(mode: .add)
        }
        .sheet(item: $configToEdit) { config in
            ConfigurationEditSheet(mode: .edit(config))
        }
        .alert(NSLocalizedString("Delete Configuration", comment: ""), isPresented: $showDeleteConfirmation) {
            Button(NSLocalizedString("Cancel", comment: ""), role: .cancel) {
                configToDelete = nil
            }
            Button(NSLocalizedString("Delete", comment: ""), role: .destructive) {
                if let config = configToDelete {
                    appSettings.deleteConfiguration(id: config.id)
                }
                configToDelete = nil
            }
        } message: {
            if let config = configToDelete {
                Text(String(format: NSLocalizedString("Are you sure you want to delete \"%@\"?", comment: ""), config.name))
            }
        }
        .alert(NSLocalizedString("Enable AI Enhancement?", comment: ""), isPresented: $showEnablePrompt) {
            Button(NSLocalizedString("Cancel", comment: ""), role: .cancel) {
                pendingConfigToEnable = nil
            }
            Button(NSLocalizedString("Enable", comment: "")) {
                if let config = pendingConfigToEnable {
                    appSettings.isAIEnhancementEnabled = true
                    validationService.switchToConfiguration(id: config.id)
                }
                pendingConfigToEnable = nil
            }
        } message: {
            Text(NSLocalizedString("AI Enhancement is off. Turn it on and use this configuration?", comment: ""))
        }
    }
}

/// Simple row for an AI configuration with validation state
private struct AIConfigurationRow: View {
    let configuration: AIEnhancementConfiguration
    let isActive: Bool
    let isValidating: Bool
    let showSuccess: Bool
    let validationError: ConfigurationValidationError?
    let onSelect: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void
    let onDismissError: () -> Void
    let onRetry: () -> Void
    @Environment(\.theme) private var theme

    @State private var isHovered = false
    @State private var showErrorPopover = false

    var body: some View {
        HStack(spacing: 12) {
            // Selection/validation indicator
            Group {
                if isValidating {
                    ProgressView()
                        .scaleEffect(0.7)
                        .frame(width: 16, height: 16)
                } else if showSuccess {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(theme.statusSuccess)
                        .font(.system(size: 16))
                } else if isActive {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(theme.accentColor)
                        .font(.system(size: 16))
                } else {
                    Image(systemName: "circle")
                        .foregroundColor(theme.textSecondary)
                        .font(.system(size: 16))
                }
            }

            // Provider icon
            Image(systemName: configuration.providerIcon)
                .foregroundColor(theme.textSecondary)
                .frame(width: 20)

            // Name and summary
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(configuration.name)
                        .font(theme.typography.body)
                        .lineLimit(1)

                    if !configuration.isValid {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(theme.statusWarning)
                            .font(theme.typography.caption)
                    }
                    
                    // Validation error indicator
                    if validationError != nil {
                        Button {
                            showErrorPopover = true
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(theme.statusError)
                                .font(theme.typography.caption)
                        }
                        .buttonStyle(.borderless)
                        .popover(isPresented: $showErrorPopover) {
                            ValidationErrorPopover(
                                error: validationError!,
                                onDismiss: {
                                    showErrorPopover = false
                                    onDismissError()
                                },
                                onRetry: {
                                    showErrorPopover = false
                                    onRetry()
                                }
                            )
                        }
                    }
                }

                Text(configuration.summary)
                    .font(theme.typography.caption)
                    .foregroundColor(theme.textSecondary)
                    .lineLimit(1)
            }

            Spacer()

            // Action buttons (visible on hover)
            if isHovered && !isValidating {
                HStack(spacing: 8) {
                    Button {
                        onEdit()
                    } label: {
                        Image(systemName: "pencil")
                            .font(theme.typography.caption)
                    }
                    .buttonStyle(.borderless)

                    Button {
                        onDelete()
                    } label: {
                        Image(systemName: "trash")
                            .font(theme.typography.caption)
                            .foregroundColor(theme.statusError)
                    }
                    .buttonStyle(.borderless)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .contentShape(Rectangle())
        .background(isHovered ? theme.accentColor.opacity(0.1) : Color.clear)
        .onTapGesture {
            if configuration.isValid && !isValidating {
                onSelect()
            }
        }
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.1)) {
                isHovered = hovering
            }
        }
        .contextMenu {
            Button {
                onSelect()
            } label: {
                Label(NSLocalizedString("Set as Active", comment: ""), systemImage: "checkmark.circle")
            }
            .disabled(!configuration.isValid || isActive || isValidating)

            Button {
                onEdit()
            } label: {
                Label(NSLocalizedString("Edit", comment: ""), systemImage: "pencil")
            }

            Divider()

            Button(role: .destructive) {
                onDelete()
            } label: {
                Label(NSLocalizedString("Delete", comment: ""), systemImage: "trash")
            }
        }
    }
}

/// Popover showing validation error with recovery options
private struct ValidationErrorPopover: View {
    let error: ConfigurationValidationError
    let onDismiss: () -> Void
    let onRetry: () -> Void
    @Environment(\.theme) private var theme
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(theme.statusError)
                Text(NSLocalizedString("Validation Failed", comment: ""))
                    .font(theme.typography.headline)
            }
            
            Text(error.errorDescription ?? "")
                .font(theme.typography.body)
            
            if let suggestion = error.recoverySuggestion {
                Text(suggestion)
                    .font(theme.typography.caption)
                    .foregroundColor(theme.textSecondary)
            }
            
            HStack {
                Button(NSLocalizedString("Dismiss", comment: "")) {
                    onDismiss()
                }
                .buttonStyle(.borderless)
                
                Button(NSLocalizedString("Retry", comment: "")) {
                    onRetry()
                }
                .buttonStyle(.borderedProminent)
            }
            .padding(.top, 4)
        }
        .padding()
        .frame(width: 280)
    }
}
