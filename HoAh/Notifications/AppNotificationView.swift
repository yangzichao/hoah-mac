import SwiftUI

struct AppNotificationView: View {
    @Environment(\.theme) private var theme
    let title: String
    let type: NotificationType
    let duration: TimeInterval
    let onClose: () -> Void
    let onTap: (() -> Void)?
    
    @State private var progress: Double = 1.0
    @State private var timer: Timer?

    enum NotificationType {
        case error
        case warning
        case info
        case success

        var iconName: String {
            switch self {
            case .error: return "xmark.octagon.fill"
            case .warning: return "exclamationmark.triangle.fill"
            case .info: return "info.circle.fill"
            case .success: return "checkmark.circle.fill"
            }
        }

        var iconColor: Color {
            switch self {
            case .error: return .red
            case .warning: return .yellow
            case .info: return .blue
            case .success: return .green
            }
        }
        }

        var body: some View {
            ZStack {
                HStack(alignment: .center, spacing: 12) {
                    // Type icon
                    Image(systemName: type.iconName)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(iconColor(for: type))
                        .frame(width: 20, height: 20)

                // Single message text
                Text(title)
                    .font(theme.typography.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(theme.notificationTitle)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                
                Spacer()
                
                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(theme.notificationBody.opacity(0.7))
                }
                .buttonStyle(PlainButtonStyle())
                .frame(width: 16, height: 16)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .frame(minWidth: 280, maxWidth: 380, minHeight: 44)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            theme.notificationBackground,
                            theme.notificationSecondaryBackground
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .overlay {
                    VisualEffectView(material: .hudWindow, blendingMode: .withinWindow)
                        .opacity(0.05)
                }
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(theme.notificationBorder, lineWidth: 0.5)
        )
        .overlay(
            VStack {
                Spacer()
                GeometryReader { geometry in
                    Rectangle()
                        .fill(theme.notificationAccent.opacity(0.8))
                        .frame(width: geometry.size.width * max(0, progress), height: 2)
                        .animation(.linear(duration: 0.1), value: progress)
                }
                .frame(height: 2)
            }
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        )
        .onAppear {
            startProgressTimer()
        }
        .onDisappear {
            timer?.invalidate()
        }
        .onTapGesture {
            if let onTap = onTap {
                onTap()
                onClose()
            }
        }
    }

    private func iconColor(for type: NotificationType) -> Color {
        switch type {
        case .error:
            return theme.statusError
        case .warning:
            return theme.statusWarning
        case .info:
            return theme.statusInfo
        case .success:
            return theme.statusSuccess
        }
    }

    private func startProgressTimer() {
        let updateInterval: TimeInterval = 0.1
        let totalSteps = duration / updateInterval
        let stepDecrement = 1.0 / totalSteps
        
        timer = Timer.scheduledTimer(withTimeInterval: updateInterval, repeats: true) { _ in
            if progress > 0 {
                progress = max(0, progress - stepDecrement)
            } else {
                timer?.invalidate()
                timer = nil
            }
        }
    }
}
