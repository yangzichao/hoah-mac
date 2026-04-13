import SwiftUI
import AppKit

// MARK: - UI Extensions
extension CustomPrompt {
    func promptIcon(
        isSelected: Bool,
        orderBadge: String? = nil,
        onTap: @escaping () -> Void,
        onEdit: ((CustomPrompt) -> Void)? = nil,
        onDelete: ((CustomPrompt) -> Void)? = nil
    ) -> some View {
        VStack(spacing: 8) {
            ZStack {
                // Dynamic background with blur effect
                RoundedRectangle(cornerRadius: 14)
                    .fill(
                        LinearGradient(
                            gradient: isSelected ?
                                Gradient(colors: [
                                    Color.accentColor.opacity(0.9),
                                    Color.accentColor.opacity(0.7)
                                ]) :
                                Gradient(colors: [
                                    Color(NSColor.controlBackgroundColor).opacity(0.95),
                                    Color(NSColor.controlBackgroundColor).opacity(0.85)
                                ]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(
                                LinearGradient(
                                    gradient: Gradient(colors: [
                                        isSelected ?
                                            Color.white.opacity(0.3) : Color.white.opacity(0.15),
                                        isSelected ?
                                            Color.white.opacity(0.1) : Color.white.opacity(0.05)
                                    ]),
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1
                            )
                    )
                    .shadow(
                        color: isSelected ?
                            Color.accentColor.opacity(0.4) : Color.black.opacity(0.1),
                        radius: isSelected ? 10 : 6,
                        x: 0,
                        y: 3
                    )

                // Decorative background elements
                Circle()
                    .fill(
                        RadialGradient(
                            gradient: Gradient(colors: [
                                isSelected ?
                                    Color.white.opacity(0.15) : Color.white.opacity(0.08),
                                Color.clear
                            ]),
                            center: .center,
                            startRadius: 1,
                            endRadius: 25
                        )
                    )
                    .frame(width: 50, height: 50)
                    .offset(x: -15, y: -15)
                    .blur(radius: 2)

                // Icon with enhanced effects
                Image(systemName: icon)
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(
                        LinearGradient(
                            colors: isSelected ?
                                [Color.white, Color.white.opacity(0.9)] :
                                [Color.primary.opacity(0.9), Color.primary.opacity(0.7)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .shadow(
                        color: isSelected ?
                            Color.white.opacity(0.5) : Color.clear,
                        radius: 4
                    )
                    .shadow(
                        color: isSelected ?
                            Color.accentColor.opacity(0.5) : Color.clear,
                        radius: 3
                    )
            }
            .frame(width: 48, height: 48)
            .overlay(alignment: .topTrailing) {
                if let orderBadge {
                    orderBadgeView(orderBadge, isSelected: isSelected)
                }
            }

            // Enhanced title styling
            VStack(spacing: 2) {
                Text(displayTitle)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(isSelected ? .primary : .secondary)
                    .lineLimit(1)
                    .frame(maxWidth: 70)

                // Trigger word section with consistent height
                triggerWordBadge(isSelected: isSelected)
            }
        }
        .padding(.top, orderBadge == nil ? 0 : 8)
        .padding(.horizontal, 4)
        .padding(.vertical, 6)
        .contentShape(Rectangle())
        .scaleEffect(isSelected ? 1.05 : 1.0)
        .onTapGesture(count: 2) {
            if let onEdit = onEdit {
                onEdit(self)
            }
        }
        .onTapGesture(count: 1) {
            onTap()
        }
        .contextMenu {
            if onEdit != nil || onDelete != nil {
                if let onEdit = onEdit {
                    Button {
                        onEdit(self)
                    } label: {
                        Label("Edit", systemImage: "pencil")
                    }
                }

                if let onDelete = onDelete {
                    Button(role: .destructive) {
                        let alert = NSAlert()
                        alert.messageText = "Delete Prompt?"
                        alert.informativeText = "Are you sure you want to delete '\(self.title)' prompt? This action cannot be undone."
                        alert.alertStyle = .warning
                        alert.addButton(withTitle: "Delete")
                        alert.addButton(withTitle: "Cancel")

                        let response = alert.runModal()
                        if response == .alertFirstButtonReturn {
                            onDelete(self)
                        }
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
            }
        }
    }

    // MARK: - Private helpers

    private func orderBadgeView(_ badge: String, isSelected: Bool) -> some View {
        HStack(spacing: 2) {
            Image(systemName: "command")
                .font(.system(size: 7, weight: .semibold, design: .rounded))
            Text(badge)
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .monospacedDigit()
        }
        .foregroundStyle(isSelected ? Color.accentColor.opacity(0.98) : Color.primary.opacity(0.78))
        .padding(.horizontal, 7)
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: isSelected ?
                            [Color.white.opacity(0.98), Color.white.opacity(0.9)] :
                            [Color(NSColor.windowBackgroundColor).opacity(0.98), Color(NSColor.controlBackgroundColor).opacity(0.94)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .stroke(
                    isSelected ? Color.accentColor.opacity(0.16) : Color.black.opacity(0.08),
                    lineWidth: 1
                )
        )
        .shadow(color: Color.black.opacity(isSelected ? 0.12 : 0.07), radius: 8, x: 0, y: 3)
        .offset(x: 9, y: -9)
    }

    @ViewBuilder
    private func triggerWordBadge(isSelected: Bool) -> some View {
        ZStack(alignment: .center) {
            if !triggerWords.isEmpty {
                HStack(spacing: 2) {
                    Image(systemName: "mic.fill")
                        .font(.system(size: 7))
                        .foregroundColor(isSelected ? .accentColor.opacity(0.9) : .secondary.opacity(0.7))

                    if triggerWords.count == 1 {
                        Text("\"\(triggerWords[0])...\"")
                            .font(.system(size: 8, weight: .regular))
                            .foregroundColor(isSelected ? .primary.opacity(0.8) : .secondary.opacity(0.7))
                            .lineLimit(1)
                    } else {
                        Text("\"\(triggerWords[0])...\" +\(triggerWords.count - 1)")
                            .font(.system(size: 8, weight: .regular))
                            .foregroundColor(isSelected ? .primary.opacity(0.8) : .secondary.opacity(0.7))
                            .lineLimit(1)
                    }
                }
                .frame(maxWidth: 70)
            }
        }
        .frame(height: 16)
    }

    // MARK: - Add New Button

    static func addNewButton(action: @escaping () -> Void) -> some View {
        VStack(spacing: 8) {
            ZStack {
                RoundedRectangle(cornerRadius: 14)
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                Color(NSColor.controlBackgroundColor).opacity(0.95),
                                Color(NSColor.controlBackgroundColor).opacity(0.85)
                            ]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(
                                LinearGradient(
                                    gradient: Gradient(colors: [
                                        Color.white.opacity(0.15),
                                        Color.white.opacity(0.05)
                                    ]),
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1
                            )
                    )
                    .shadow(color: Color.black.opacity(0.1), radius: 6, x: 0, y: 3)

                Circle()
                    .fill(
                        RadialGradient(
                            gradient: Gradient(colors: [
                                Color.white.opacity(0.08),
                                Color.clear
                            ]),
                            center: .center,
                            startRadius: 1,
                            endRadius: 25
                        )
                    )
                    .frame(width: 50, height: 50)
                    .offset(x: -15, y: -15)
                    .blur(radius: 2)

                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color.accentColor.opacity(0.9), Color.accentColor.opacity(0.7)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
            .frame(width: 48, height: 48)

            VStack(spacing: 2) {
                Text("Add New")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                    .frame(maxWidth: 70)

                Spacer()
                    .frame(height: 16)
            }
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 6)
        .contentShape(Rectangle())
        .onTapGesture(perform: action)
    }
}
