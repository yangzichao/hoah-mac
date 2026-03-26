import SwiftUI
import KeyboardShortcuts

struct EnhancementShortcutsView: View {
    var body: some View {
        VStack(spacing: 12) {
            ShortcutRow(
                title: "Switch Action",
                description: "Switch between your saved actions with ⌘1–⌘0. The shortcut works while the recorder is visible, and also on this page when the HoAh window is focused.",
                keyDisplay: ["⌘", "1 – 0"]
            )
        }
        .background(Color.clear)
    }
}

struct EnhancementShortcutsSection: View {
    @State private var isExpanded = false
    @Environment(\.theme) private var theme
    
    var body: some View {
        VStack(spacing: 0) {
            Button {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "command")
                        .font(.system(size: 20))
                        .foregroundColor(theme.accentColor)
                        .frame(width: 24, height: 24)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(NSLocalizedString("Enhancement Shortcuts", comment: ""))
                            .font(theme.typography.headline)
                            .foregroundColor(theme.textPrimary)
                        Text(NSLocalizedString("Keep enhancement prompts handy", comment: ""))
                            .font(theme.typography.subheadline)
                            .foregroundColor(theme.textSecondary)
                    }
                    
                    Spacer()
                    
                    Image(systemName: "chevron.down")
                        .rotationEffect(.degrees(isExpanded ? 0 : -90))
                        .foregroundColor(theme.textSecondary)
                        .font(.system(size: 14, weight: .semibold))
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            
            if isExpanded {
                Divider()
                    .transition(.opacity)
                
                VStack(alignment: .leading, spacing: 16) {
                    EnhancementShortcutsView()

                    Text(NSLocalizedString("AI Action shortcuts work while the recorder is visible. On this page, ⌘1–⌘0 also works when the HoAh window is focused.", comment: ""))
                        .font(theme.typography.caption)
                        .foregroundColor(theme.textSecondary)
                }
                .padding(16)
                .transition(
                    .asymmetric(
                        insertion: .opacity.combined(with: .scale(scale: 0.98, anchor: .top)),
                        removal: .opacity
                    )
                )
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(CardBackground(isSelected: false))
    }
}

// MARK: - Supporting Views
private struct ShortcutRow: View {
    let title: String
    let description: String
    let keyDisplay: [String]
    @Environment(\.theme) private var theme

    init(title: String, description: String, keyDisplay: [String]) {
        self.title = title
        self.description = description
        self.keyDisplay = keyDisplay
    }

    var body: some View {
        HStack(alignment: .center, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(LocalizedStringKey(title))
                        .font(theme.typography.headline)
                        .foregroundColor(theme.textPrimary)
                    InfoTip(title: title, message: description)
                }

                Text(LocalizedStringKey(description))
                    .font(theme.typography.caption)
                    .foregroundColor(theme.textSecondary)
                    .lineLimit(2)
            }

            Spacer(minLength: 12)

            keyDisplayView()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(CardBackground(isSelected: false))
    }

    @ViewBuilder
    private func keyDisplayView() -> some View {
        HStack(spacing: 8) {
            ForEach(keyDisplay, id: \.self) { key in
                KeyChip(label: key)
            }
        }
    }
}

private struct KeyChip: View {
    let label: String
    var isActive: Bool? = nil
    @Environment(\.theme) private var theme

    var body: some View {
        let active = isActive ?? true

        Text(label)
            .font(theme.typography.caption)
            .fontWeight(.semibold)
            .fontDesign(.rounded)
            .foregroundColor(active ? theme.textPrimary : theme.textSecondary)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                theme.controlBackground.opacity(active ? 0.9 : 0.6),
                                theme.controlBackground.opacity(active ? 0.7 : 0.5)
                            ]),
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .strokeBorder(
                        theme.separatorColor.opacity(active ? 0.4 : 0.2),
                        lineWidth: 1
                    )
            )
            .shadow(color: theme.shadowColor.opacity(active ? 0.15 : 0.05), radius: 2, x: 0, y: 1)
            .opacity(active ? 1.0 : 0.6)
    }
}

struct ClipboardActionShortcutsSection: View {
    @EnvironmentObject private var appSettings: AppSettingsStore
    @Environment(\.theme) private var theme
    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "doc.on.clipboard")
                    .font(.system(size: 20))
                    .foregroundColor(theme.accentColor)
                    .frame(width: 24, height: 24)

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text(LocalizedStringKey("Selection Action"))
                            .font(theme.typography.headline)
                            .foregroundColor(theme.textPrimary)

                        Text(LocalizedStringKey("Experimental"))
                            .font(theme.typography.caption2)
                            .fontWeight(.semibold)
                            .foregroundColor(theme.statusWarning)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(theme.statusWarning.opacity(0.12))
                            .clipShape(Capsule())
                    }

                    Text(LocalizedStringKey("Copy the currently selected text, run it through an AI Action, and paste the result into the focused input."))
                        .font(theme.typography.subheadline)
                        .foregroundColor(theme.textSecondary)
                }

                Spacer()

                HStack(spacing: 10) {
                    Toggle("", isOn: $appSettings.isClipboardEnhancementShortcutsEnabled)
                        .toggleStyle(ThemedSwitchToggleStyle(theme: theme))
                        .labelsHidden()

                    Button {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.88)) {
                            isExpanded.toggle()
                        }
                    } label: {
                        Image(systemName: "chevron.down")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(theme.textSecondary)
                            .rotationEffect(.degrees(isExpanded ? 0 : -90))
                            .frame(width: 28, height: 28)
                            .background(theme.controlBackground.opacity(0.55))
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                }
            }

            HStack(spacing: 8) {
                KeyChip(label: "⌥", isActive: appSettings.isClipboardEnhancementShortcutsEnabled)
                KeyChip(label: "⇧", isActive: appSettings.isClipboardEnhancementShortcutsEnabled)
                KeyChip(label: "1 – 0", isActive: appSettings.isClipboardEnhancementShortcutsEnabled)
            }

            if isExpanded {
                VStack(alignment: .leading, spacing: 14) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(LocalizedStringKey("This feature is disabled by default. Once enabled, the shortcut works globally while HoAh is running."))
                            .font(theme.typography.caption)
                            .foregroundColor(theme.textSecondary)

                        Text(LocalizedStringKey("Default shortcuts use ⌥⇧1–0. You can customize each slot below."))
                            .font(theme.typography.caption)
                            .foregroundColor(theme.textSecondary)
                    }

                    if appSettings.isClipboardEnhancementShortcutsEnabled {
                        ClipboardActionShortcutEditor()
                    }
                }
                .transition(
                    .asymmetric(
                        insertion: .opacity.combined(with: .move(edge: .top)),
                        removal: .opacity
                    )
                )
            }
        }
        .padding(16)
        .background(CardBackground(isSelected: false))
        .animation(.easeInOut(duration: 0.25), value: isExpanded)
    }
}

private struct ClipboardActionShortcutEditor: View {
    @EnvironmentObject private var enhancementService: AIEnhancementService
    @Environment(\.theme) private var theme

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    private var shortcutPrompts: [CustomPrompt] {
        enhancementService.promptShortcutPrompts
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(LocalizedStringKey("Customize Selection Action Shortcuts"))
                .font(theme.typography.headline)
                .foregroundColor(theme.textPrimary)

            Text(LocalizedStringKey("Default is Option + Shift + number. Record a new shortcut for any action if you want a different mapping."))
                .font(theme.typography.caption)
                .foregroundColor(theme.textSecondary)

            LazyVGrid(columns: columns, spacing: 10) {
                ForEach(ClipboardAIActionShortcutManager.shortcutEditorSlots, id: \.index) { slot in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(promptTitle(for: slot.index))
                                .font(theme.typography.caption)
                                .foregroundColor(promptExists(for: slot.index) ? theme.textPrimary : theme.textSecondary)
                                .lineLimit(1)

                            Text(promptSubtitle(for: slot.index))
                                .font(theme.typography.caption2)
                                .foregroundColor(theme.textSecondary)
                                .lineLimit(1)
                        }

                        Spacer(minLength: 8)

                        KeyboardShortcuts.Recorder(for: slot.name)
                            .controlSize(.small)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(theme.controlBackground.opacity(0.6))
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(CardBackground(isSelected: false))
    }

    private func promptExists(for index: Int) -> Bool {
        index < shortcutPrompts.count
    }

    private func promptTitle(for index: Int) -> String {
        if index < shortcutPrompts.count {
            return shortcutPrompts[index].displayTitle
        }
        return String(format: NSLocalizedString("Action %d", comment: "Label for clipboard action shortcut slot"), index + 1)
    }

    private func promptSubtitle(for index: Int) -> String {
        if promptExists(for: index) {
            return String(format: NSLocalizedString("Shortcut Slot %d", comment: "Label for clipboard action shortcut position"), index + 1)
        }
        return NSLocalizedString("No matching AI Action yet", comment: "Shown when a clipboard shortcut slot has no corresponding AI action")
    }
}
