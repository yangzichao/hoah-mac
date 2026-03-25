import SwiftUI

struct ProBadge: View {
    @Environment(\.theme) private var theme
    var body: some View {
        Text("PRO")
            .font(.system(size: 10, weight: .semibold))
            .foregroundColor(theme.textPrimary)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(
                RoundedRectangle(cornerRadius: 4)
                    .fill(theme.statusInfo.opacity(0.8))
            )
    }
}

#Preview {
    ProBadge()
} 
