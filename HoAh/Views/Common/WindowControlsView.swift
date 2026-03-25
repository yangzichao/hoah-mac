import SwiftUI

private enum WindowAction {
    case close
    case minimize
    case zoom
}

struct WindowControlsView: View {
    @Environment(\.theme) private var theme

    var body: some View {
        HStack(spacing: 8) {
            windowButton(.close, color: theme.trafficLightClose)
            windowButton(.minimize, color: theme.trafficLightMinimize)
            windowButton(.zoom, color: theme.trafficLightZoom)
        }
    }

    private func windowButton(_ action: WindowAction, color: Color) -> some View {
        Button {
            guard let window = WindowManager.shared.currentMainWindow() else { return }
            switch action {
            case .close:
                window.performClose(nil)
            case .minimize:
                window.miniaturize(nil)
            case .zoom:
                window.performZoom(nil)
            }
        } label: {
            Circle()
                .fill(color)
                .frame(width: 11, height: 11)
                .overlay(
                    Circle()
                        .stroke(theme.windowControlsBorder.opacity(0.4), lineWidth: 0.6)
                )
                .shadow(color: Color.black.opacity(0.12), radius: 1, x: 0, y: 0.5)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel(for: action))
    }

    private func accessibilityLabel(for action: WindowAction) -> Text {
        switch action {
        case .close:
            return Text("Close window")
        case .minimize:
            return Text("Minimize window")
        case .zoom:
            return Text("Zoom window")
        }
    }
}
