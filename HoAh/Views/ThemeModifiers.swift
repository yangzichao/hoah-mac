
//
//  ThemeModifiers.swift
//  HoAh
//
//  Created by HoAh Assistant.
//

import SwiftUI

struct ThemedSwitchToggleStyle: ToggleStyle {
    let theme: ThemePalette
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        HStack {
            configuration.label
            Button(action: { configuration.isOn.toggle() }) {
                ZStack {
                    Capsule()
                        .fill(configuration.isOn ? theme.accentColor : theme.panelBackground)
                        .overlay(
                            Capsule()
                                .stroke(theme.panelBorder, lineWidth: 1)
                        )
                        .frame(width: 44, height: 24)
                    
                    Circle()
                        .fill(.white)
                        .frame(width: 18, height: 18)
                        .shadow(color: theme.shadowColor.opacity(0.2), radius: 1, x: 0, y: 1)
                        .offset(x: configuration.isOn ? 10 : -10)
                }
                .animation(.easeInOut(duration: 0.15), value: configuration.isOn)
            }
            .buttonStyle(.plain)
        }
        .opacity(isEnabled ? 1.0 : 0.5)
        .accessibilityElement(children: .combine)
        .accessibilityValue(Text(configuration.isOn ? "On" : "Off"))
    }
}

extension View {
    /// Applies theme-specific sidebar selection styling.
    /// Applies a custom colored background (e.g. Rust Red) to override the system blue.
    @ViewBuilder
    func applyThemeSidebarSelection(theme: ThemePalette, isSelected: Bool) -> some View {
        self.listRowBackground(
            isSelected
            ? RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(theme.sidebarItemBackgroundSelected)
                .padding(.horizontal, 8)
                .padding(.vertical, 2)
            : nil
        )
    }
}
