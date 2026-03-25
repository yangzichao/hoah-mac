import SwiftUI
import AppKit

/// Settings view for configuring automatic daily export of transcriptions.
struct AutoExportSettingsView: View {
    @EnvironmentObject private var appSettings: AppSettingsStore
    @Environment(\.theme) private var theme
    @State private var showingFolderPicker = false
    @State private var pathValidationError: String?
    @State private var isExpanded = false
    @State private var isPathAccessible = false
    @State private var didAutoPrompt = false
    
    private var displayPath: String {
        appSettings.autoExportDisplayPath ?? NSLocalizedString("auto_export_no_folder", comment: "")
    }
    
    private var hasValidPath: Bool {
        appSettings.hasValidAutoExportPath
    }

    private var needsPermission: Bool {
        hasValidPath && !isPathAccessible
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Collapsible Header
            Button(action: { withAnimation(.easeInOut(duration: 0.2)) { isExpanded.toggle() } }) {
                HStack(spacing: 8) {
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(theme.typography.caption)
                        .foregroundColor(theme.textSecondary)
                    
                    Text(LocalizedStringKey("auto_export_title"))
                        .font(theme.typography.headline)
                    
                    Spacer()
                    
                    // Status badge in collapsed state
                    if appSettings.isAutoExportEnabled && hasValidPath && isPathAccessible {
                        HStack(spacing: 4) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(theme.statusSuccess)
                            Text(LocalizedStringKey("auto_export_status_on"))
                                .font(theme.typography.caption)
                                .foregroundColor(theme.textSecondary)
                        }
                    } else if appSettings.isAutoExportEnabled && needsPermission {
                        HStack(spacing: 4) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(theme.statusWarning)
                            Text(LocalizedStringKey("auto_export_status_needs_permission"))
                                .font(theme.typography.caption)
                                .foregroundColor(theme.textSecondary)
                        }
                    } else if hasValidPath {
                        Text(LocalizedStringKey("auto_export_status_off"))
                            .font(theme.typography.caption)
                            .foregroundColor(theme.textSecondary)
                    }
                }
                .padding(.vertical, 10)
                .padding(.horizontal, 12)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            
            // Expandable Content
            if isExpanded {
                VStack(alignment: .leading, spacing: 12) {
                    Divider()
                    
                    Text(LocalizedStringKey("auto_export_description"))
                        .font(theme.typography.caption)
                        .foregroundColor(theme.textSecondary)
                    
                    // Folder Selection
                    HStack(spacing: 8) {
                        // Path display
                        HStack {
                            if hasValidPath {
                                Image(systemName: "folder.fill")
                                    .foregroundColor(theme.accentColor)
                            } else {
                                Image(systemName: "folder.badge.questionmark")
                                    .foregroundColor(theme.statusWarning)
                            }
                            
                            Text(displayPath)
                                .font(.system(.caption, design: .monospaced))
                                .lineLimit(1)
                                .truncationMode(.middle)
                            
                            Spacer()
                        }
                        .padding(6)
                        .background(theme.windowBackground)
                        .cornerRadius(4)
                        
                        Button(action: selectFolder) {
                            Text(LocalizedStringKey("auto_export_select_folder"))
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)

                        if needsPermission {
                            Button(action: selectFolder) {
                                Text(LocalizedStringKey("auto_export_reauthorize"))
                            }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.small)
                        }
                        
                        if hasValidPath {
                            Button(action: clearFolder) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(theme.textSecondary)
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    if let error = pathValidationError {
                        HStack(spacing: 6) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(theme.statusWarning)
                            Text(error)
                                .font(theme.typography.caption)
                                .foregroundColor(theme.textSecondary)
                        }
                    }
                    
                    // Enable Toggle
                    Toggle(isOn: Binding(
                        get: { appSettings.isAutoExportEnabled },
                        set: { newValue in
                            if newValue && (!hasValidPath || needsPermission) {
                                selectFolder()
                            } else {
                                appSettings.isAutoExportEnabled = newValue
                                refreshPathValidation()
                            }
                        }
                    )) {
                        Text(LocalizedStringKey("auto_export_enable_toggle"))
                            .font(theme.typography.subheadline)
                    }
                    .toggleStyle(ThemedSwitchToggleStyle(theme: theme))
                    .controlSize(.small)
                    .disabled(!hasValidPath)
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 10)
            }
        }
        .background(CardBackground(isSelected: false))
        .onAppear {
            refreshPathValidation()
            autoPromptIfNeeded(forceExpand: true)
        }
        .onChange(of: isExpanded) { _, newValue in
            if newValue {
                refreshPathValidation()
                autoPromptIfNeeded()
            } else {
                didAutoPrompt = false
            }
        }
        .onChange(of: hasValidPath) { _, _ in
            refreshPathValidation()
            autoPromptIfNeeded(forceExpand: true)
        }
        .onChange(of: isPathAccessible) { _, _ in
            autoPromptIfNeeded(forceExpand: true)
        }
    }
    
    private func selectFolder() {
        let panel = NSOpenPanel()
        panel.title = NSLocalizedString("Select export folder", comment: "")
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = true
        panel.prompt = NSLocalizedString("Select", comment: "")
        
        panel.begin { response in
            if response == .OK, let url = panel.url {
                do {
                    try SecurityScopedBookmarkManager.saveBookmark(for: url)
                    // Enable auto export after selecting folder
                    appSettings.isAutoExportEnabled = true
                    refreshPathValidation()
                } catch {
                    pathValidationError = error.localizedDescription
                }
            }
        }
    }
    
    private func clearFolder() {
        SecurityScopedBookmarkManager.clearBookmark()
        appSettings.isAutoExportEnabled = false
        refreshPathValidation()
    }

    private func refreshPathValidation() {
        guard hasValidPath else {
            isPathAccessible = false
            pathValidationError = nil
            return
        }

        isPathAccessible = AutoExportService.shared.validateExportPath()
        if isPathAccessible {
            pathValidationError = nil
        } else {
            pathValidationError = NSLocalizedString("auto_export_permission_required", comment: "")
        }
    }

    private func autoPromptIfNeeded(forceExpand: Bool = false) {
        guard !didAutoPrompt else { return }
        guard appSettings.isAutoExportEnabled, needsPermission else { return }
        if forceExpand { isExpanded = true }
        didAutoPrompt = true
        DispatchQueue.main.async {
            selectFolder()
        }
    }
}
