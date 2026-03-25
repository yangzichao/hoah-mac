import SwiftUI

struct AnimatedCopyButton: View {
    let textToCopy: String
    @State private var isCopied: Bool = false
    @Environment(\.theme) private var theme
    
    var body: some View {
        Button {
            copyToClipboard()
        } label: {
            HStack(spacing: 4) {
                Image(systemName: isCopied ? "checkmark" : "doc.on.doc")
                    .font(.system(size: 12, weight: isCopied ? .bold : .regular))
                    .foregroundColor(theme.textPrimary)
                Text(isCopied ? "Copied" : "Copy")
                    .font(.system(size: 12, weight: isCopied ? .medium : .regular))
                    .foregroundColor(theme.textPrimary)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                Capsule()
                    .fill(isCopied ? theme.statusSuccess.opacity(0.8) : theme.statusInfo)
            )
        }
        .buttonStyle(.plain)
        .scaleEffect(isCopied ? 1.05 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isCopied)
    }
    
    private func copyToClipboard() {
        let _ = ClipboardManager.copyToClipboard(textToCopy)
        withAnimation {
            isCopied = true
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation {
                isCopied = false
            }
        }
    }
}

struct AnimatedCopyButton_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 20) {
            AnimatedCopyButton(textToCopy: "Sample text")
            Text("Before Copy")
                .padding()
        }
        .padding()
    }
} 
