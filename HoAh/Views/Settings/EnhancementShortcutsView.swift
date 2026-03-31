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
    @EnvironmentObject private var enhancementService: AIEnhancementService
    @Environment(\.theme) private var theme
    @State private var isExpanded = false

    private var availableShortcutCount: Int {
        ClipboardAIActionShortcutManager.activeShortcutCount(for: enhancementService.promptShortcutPrompts.count)
    }

    private var enabledShortcutIndices: [Int] {
        ClipboardAIActionShortcutManager.enabledShortcutIndices(
            for: enhancementService.promptShortcutPrompts.count,
            enabledStates: appSettings.clipboardEnhancementShortcutSlotEnabledStates
        )
    }

    private var enabledShortcutSummaryLabel: String {
        ClipboardAIActionShortcutManager.shortcutSummaryLabel(for: enabledShortcutIndices)
    }

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

                    Text(LocalizedStringKey("Select text, trigger an AI Action with a shortcut, and HoAh will copy the result to your clipboard and paste it into the focused input."))
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

            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    shortcutStatusPill(
                        systemImage: appSettings.isClipboardEnhancementShortcutsEnabled ? "bolt.fill" : "pause.fill",
                        tint: appSettings.isClipboardEnhancementShortcutsEnabled ? theme.accentColor : theme.textMuted,
                        text: availableShortcutCount > 0
                            ? "\(enabledShortcutIndices.count)/\(availableShortcutCount)"
                            : "0"
                    )

                    if availableShortcutCount > 0 {
                        shortcutStatusPill(
                            systemImage: "square.grid.2x2",
                            tint: theme.statusInfo,
                            text: ClipboardAIActionShortcutManager.shortcutRangeLabel(for: availableShortcutCount)
                        )
                    }
                }

                HStack(spacing: 8) {
                    KeyChip(label: "⌥", isActive: appSettings.isClipboardEnhancementShortcutsEnabled && !enabledShortcutIndices.isEmpty)
                    KeyChip(label: "⇧", isActive: appSettings.isClipboardEnhancementShortcutsEnabled && !enabledShortcutIndices.isEmpty)
                    KeyChip(label: enabledShortcutSummaryLabel, isActive: appSettings.isClipboardEnhancementShortcutsEnabled && !enabledShortcutIndices.isEmpty)
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(theme.panelBackground.opacity(0.52))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(theme.panelBorder.opacity(0.8), lineWidth: 1)
            )

            if isExpanded {
                VStack(alignment: .leading, spacing: 14) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(LocalizedStringKey("This feature is disabled by default. Once enabled, the shortcut works globally while HoAh is running."))
                            .font(theme.typography.caption)
                            .foregroundColor(theme.textSecondary)

                        if availableShortcutCount > 0 {
                            Text(
                                String(
                                    format: NSLocalizedString("Default shortcuts use ⌥⇧%@. You can customize each action below.", comment: "Explains the default selection action shortcut range based on the number of available AI actions"),
                                    ClipboardAIActionShortcutManager.shortcutRangeLabel(for: availableShortcutCount)
                                )
                            )
                                .font(theme.typography.caption)
                                .foregroundColor(theme.textSecondary)
                        }
                    }
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(theme.inputBackground.opacity(0.58))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(theme.inputBorder.opacity(0.75), lineWidth: 1)
                    )

                    if appSettings.isClipboardEnhancementShortcutsEnabled {
                        if availableShortcutCount > 0 {
                            ClipboardActionShortcutEditor(slotCount: availableShortcutCount)
                        } else {
                            Text(LocalizedStringKey("No AI Actions available yet. Add or enable an AI Action to create Selection Action shortcuts."))
                                .font(theme.typography.caption)
                                .foregroundColor(theme.textSecondary)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 14)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(CardBackground(isSelected: false))
                        }
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

    private func shortcutStatusPill(systemImage: String, tint: Color, text: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: systemImage)
                .font(.system(size: 11, weight: .semibold))

            Text(text)
                .font(theme.typography.caption2)
                .fontWeight(.semibold)
                .lineLimit(1)
        }
        .foregroundColor(tint)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            Capsule(style: .continuous)
                .fill(tint.opacity(0.10))
        )
        .overlay(
            Capsule(style: .continuous)
                .stroke(tint.opacity(0.18), lineWidth: 1)
        )
    }
}

private struct ClipboardActionShortcutEditor: View {
    @EnvironmentObject private var appSettings: AppSettingsStore
    @EnvironmentObject private var enhancementService: AIEnhancementService
    @Environment(\.theme) private var theme
    let slotCount: Int

    private let columns = [
        GridItem(.adaptive(minimum: 280, maximum: 420), spacing: 14, alignment: .top)
    ]

    private var shortcutPrompts: [CustomPrompt] {
        enhancementService.promptShortcutPrompts
    }

    private var editorSlots: [(index: Int, name: KeyboardShortcuts.Name)] {
        ClipboardAIActionShortcutManager.shortcutEditorSlots(for: slotCount)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(LocalizedStringKey("Customize Selection Action Shortcuts"))
                    .font(theme.typography.headline)
                    .foregroundColor(theme.textPrimary)

                Text(LocalizedStringKey("Default is Option + Shift + number. Record a new shortcut for any action if you want a different mapping."))
                    .font(theme.typography.caption)
                    .foregroundColor(theme.textSecondary)
            }

            LazyVGrid(columns: columns, spacing: 14) {
                ForEach(editorSlots, id: \.index) { slot in
                    ClipboardActionShortcutCard(
                        slotIndex: slot.index,
                        shortcutName: slot.name,
                        promptTitle: promptTitle(for: slot.index),
                        isEnabled: slotEnabledBinding(for: slot.index)
                    )
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(theme.panelBackground.opacity(0.42))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(theme.panelBorder.opacity(0.75), lineWidth: 1)
        )
    }

    private func promptTitle(for index: Int) -> String {
        if index < shortcutPrompts.count {
            return shortcutPrompts[index].displayTitle
        }
        return String(format: NSLocalizedString("Action %d", comment: "Label for clipboard action shortcut slot"), index + 1)
    }

    private func slotEnabledBinding(for index: Int) -> Binding<Bool> {
        Binding(
            get: { appSettings.isClipboardEnhancementShortcutSlotEnabled(at: index) },
            set: { appSettings.setClipboardEnhancementShortcutSlotEnabled($0, at: index) }
        )
    }
}

private struct ClipboardActionShortcutCard: View {
    let slotIndex: Int
    let shortcutName: KeyboardShortcuts.Name
    let promptTitle: String
    @Binding var isEnabled: Bool

    @Environment(\.theme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(promptTitle)
                        .font(theme.typography.body)
                        .foregroundColor(theme.textPrimary)
                        .lineLimit(2)

                    HStack(spacing: 6) {
                        Image(systemName: isEnabled ? "checkmark.circle.fill" : "minus.circle")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(isEnabled ? theme.accentColor : theme.textMuted)

                        Text(String(format: NSLocalizedString("Shortcut Slot %d", comment: "Label for clipboard action shortcut position"), slotIndex + 1))
                            .font(theme.typography.caption2)
                            .foregroundColor(theme.textSecondary)
                    }
                }

                Spacer(minLength: 12)

                HStack(spacing: 10) {
                    Text(isEnabled ? LocalizedStringKey("Enabled") : LocalizedStringKey("Disabled"))
                        .font(theme.typography.caption2)
                        .fontWeight(.semibold)
                        .foregroundColor(isEnabled ? theme.accentColor : theme.textMuted)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(
                            Capsule(style: .continuous)
                                .fill((isEnabled ? theme.accentColor : theme.textMuted).opacity(0.10))
                        )
                        .overlay(
                            Capsule(style: .continuous)
                                .stroke((isEnabled ? theme.accentColor : theme.textMuted).opacity(0.18), lineWidth: 1)
                        )

                    Toggle(isOn: $isEnabled) {
                        EmptyView()
                    }
                    .toggleStyle(ThemedSwitchToggleStyle(theme: theme))
                    .labelsHidden()
                    .controlSize(.small)
                }
            }

            Rectangle()
                .fill(theme.separatorColor.opacity(0.85))
                .frame(height: 1)

            HStack(alignment: .center, spacing: 12) {
                HStack(spacing: 8) {
                    Image(systemName: "keyboard")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(theme.textSecondary)

                    Text(LocalizedStringKey("Keyboard Shortcut"))
                        .font(theme.typography.caption)
                        .foregroundColor(theme.textSecondary)
                }

                Spacer(minLength: 12)

                KeyboardShortcuts.Recorder(for: shortcutName)
                    .controlSize(.small)
                    .labelsHidden()
                    .frame(minWidth: 152, alignment: .trailing)
                    .opacity(isEnabled ? 1.0 : disabledOpacity)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill((isEnabled ? theme.inputBackground : theme.controlBackground).opacity(isEnabled ? 0.90 : 0.62))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(
                    isEnabled ? theme.accentColor.opacity(0.18) : theme.inputBorder.opacity(0.85),
                    lineWidth: 1
                )
        )
        .shadow(color: theme.shadowColor.opacity(isEnabled ? 0.08 : 0.03), radius: 8, x: 0, y: 3)
        .opacity(isEnabled ? 1.0 : disabledOpacity)
        .fixedSize(horizontal: false, vertical: true)
    }

    private var disabledOpacity: CGFloat {
        0.70
    }
}
