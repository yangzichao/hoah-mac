import SwiftUI

struct WindowHeaderView: View {
    @Environment(\.theme) private var theme

    var body: some View {
        HStack(spacing: 0) {
            WindowControlsView()
                .padding(.leading, 10)
            Spacer()
        }
        .frame(height: 32)
        .background(theme.windowHeaderBackground)
        .overlay(
            Rectangle()
                .frame(height: 1)
                .foregroundColor(theme.windowHeaderBorder),
            alignment: .bottom
        )
    }
}
