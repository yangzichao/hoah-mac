import SwiftUI

struct ExperimentalFeaturesSection: View {
    @AppStorage("isExperimentalFeaturesEnabled", store: .hoah) private var isExperimentalFeaturesEnabled = false
    @Environment(\.theme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Image(systemName: "flask")
                    .font(.system(size: 20))
                    .foregroundColor(theme.accentColor)
                    .frame(width: 24, height: 24)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Experimental Features")
                        .font(theme.typography.headline)
                    Text("Experimental features that might be unstable & bit buggy.")
                        .font(theme.typography.subheadline)
                        .foregroundColor(theme.textSecondary)
                }

                Spacer()

                Toggle("Experimental Features", isOn: $isExperimentalFeaturesEnabled)
                    .labelsHidden()
                    .toggleStyle(ThemedSwitchToggleStyle(theme: theme))
            }

            if isExperimentalFeaturesEnabled {
                Divider()
                    .padding(.vertical, 4)
                    .transition(.opacity.combined(with: .move(edge: .top)))

                Text("No experimental features currently available.")
                    .font(theme.typography.caption)
                    .foregroundColor(theme.textSecondary)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .animation(.easeInOut(duration: 0.3), value: isExperimentalFeaturesEnabled)
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(CardBackground(isSelected: false, useAccentGradientWhenSelected: true))
    }
}
