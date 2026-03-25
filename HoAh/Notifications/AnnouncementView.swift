import SwiftUI

struct AnnouncementView: View {
    @Environment(\.theme) private var theme
    let title: String
    let description: String
    let onClose: () -> Void
    let onLearnMore: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                Text(title)
                    .font(theme.typography.headline)
                    .foregroundColor(theme.notificationTitle)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)

                Spacer()

                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(theme.notificationBody.opacity(0.8))
                }
                .buttonStyle(PlainButtonStyle())
            }

            if !description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                ScrollView {
                    Text(description)
                        .font(theme.typography.subheadline)
                        .foregroundColor(theme.notificationBody)
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(maxHeight: 120)
            }

            HStack(spacing: 8) {
                Button(action: onLearnMore) {
                    Text("Learn more")
                        .font(theme.typography.caption2)
                        .foregroundColor(theme.notificationActionText)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(theme.notificationActionBackground)
                        )
                }
                .buttonStyle(PlainButtonStyle())

                Button(action: onClose) {
                    Text("Dismiss")
                        .font(theme.typography.caption2)
                        .foregroundColor(theme.notificationBody)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 6)
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .frame(minWidth: 360, idealWidth: 420)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(.clear)
                .background(
                    ZStack {
                        theme.notificationBackground
                        LinearGradient(
                            colors: [
                                theme.notificationBackground,
                                theme.notificationSecondaryBackground
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                        VisualEffectView(material: .hudWindow, blendingMode: .withinWindow)
                            .opacity(0.05)
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(theme.notificationBorder, lineWidth: 0.5)
        )
    }
}


 
