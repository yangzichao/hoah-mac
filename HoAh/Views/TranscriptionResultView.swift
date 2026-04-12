import SwiftUI

enum TranscriptionTab: String, CaseIterable {
    case original
    case enhanced
    case aiRequest
    
    var titleKey: LocalizedStringKey {
        switch self {
        case .original: return LocalizedStringKey("transcription_tab_original")
        case .enhanced: return LocalizedStringKey("transcription_tab_enhanced")
        case .aiRequest: return LocalizedStringKey("transcription_tab_ai_request")
        }
    }
}

struct TranscriptionResultView: View {
    @Environment(\.theme) private var theme
    let transcription: Transcription
    
    @State private var selectedTab: TranscriptionTab = .original
    
    private var availableTabs: [TranscriptionTab] {
        var tabs: [TranscriptionTab] = [.original]
        if transcription.enhancedText != nil {
            tabs.append(.enhanced)
        }
        if transcription.aiRequestSystemMessage != nil || transcription.aiRequestUserMessage != nil {
            tabs.append(.aiRequest)
        }
        return tabs
    }
    
    private var textForSelectedTab: String {
        switch selectedTab {
        case .original:
            return transcription.text
        case .enhanced:
            return transcription.enhancedText ?? ""
        case .aiRequest:
            var result = ""
            if let systemMsg = transcription.aiRequestSystemMessage, !systemMsg.isEmpty {
                result += systemMsg
            }
            if let userMsg = transcription.aiRequestUserMessage, !userMsg.isEmpty {
                if !result.isEmpty { result += "\n\n" }
                result += userMsg
            }
            return result.isEmpty ? transcription.text : result
        }
    }

    /// For copy/save: use successful enhanced text, fall back to original transcript on AI failure.
    private var copyTextForSelectedTab: String {
        switch selectedTab {
        case .enhanced:
            return transcription.copyableEnhancedText ?? transcription.text
        default:
            return textForSelectedTab
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Transcription Result")
                .font(theme.typography.headline)
            
            if availableTabs.count > 1 {
                HStack(spacing: 2) {
                    ForEach(availableTabs, id: \.self) { tab in
                        TabButton(title: tab.titleKey,
                                  isSelected: selectedTab == tab,
                                  action: { selectedTab = tab })
                    }
                    Spacer()
                    AnimatedCopyButton(textToCopy: copyTextForSelectedTab)
                    AnimatedSaveButton(textToSave: copyTextForSelectedTab)
                }
                .padding(.vertical, 8)
                .padding(.horizontal, 4)
            } else {
                HStack {
                    Spacer()
                    AnimatedCopyButton(textToCopy: copyTextForSelectedTab)
                    AnimatedSaveButton(textToSave: copyTextForSelectedTab)
                }
            }
            
            ScrollView {
                Text(textForSelectedTab)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            
            HStack {
                Text(String(format: NSLocalizedString("Duration: %@", comment: ""), formatDuration(transcription.duration)))
                    .font(theme.typography.caption)
                    .foregroundColor(theme.textSecondary)
                Spacer()
            }
        }
        .padding()
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
    
    private struct TabButton: View {
        @Environment(\.theme) private var theme
        let title: LocalizedStringKey
        let isSelected: Bool
        let action: () -> Void
        
        var body: some View {
            Button(action: action) {
                Text(title)
                    .font(theme.typography.caption)
                    .fontWeight(isSelected ? .semibold : .medium)
                    .foregroundColor(isSelected ? theme.textPrimary : theme.textSecondary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(isSelected ? theme.accentColor : Color.clear)
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(isSelected ? Color.clear : theme.panelBorder, lineWidth: 1)
                            )
                            .contentShape(.capsule)
                    )
            }
            .buttonStyle(.plain)
            .animation(.easeInOut(duration: 0.2), value: isSelected)
        }
    }
}
