import SwiftUI
import SwiftData

enum ContentTab: String, CaseIterable {
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

struct TranscriptionCard: View {
    @Environment(\.theme) private var theme
    let transcription: Transcription
    let isExpanded: Bool
    let isSelected: Bool
    let onDelete: () -> Void
    let onToggleSelection: () -> Void

    @State private var selectedTab: ContentTab = .original

    private var availableTabs: [ContentTab] {
        var tabs: [ContentTab] = []
        if transcription.enhancedText != nil {
            tabs.append(.enhanced)
        }
        tabs.append(.original)
        if transcription.aiRequestSystemMessage != nil || transcription.aiRequestUserMessage != nil {
            tabs.append(.aiRequest)
        }
        return tabs
    }

    private var hasAudioFile: Bool {
        if let urlString = transcription.audioFileURL,
           let url = URL(string: urlString),
           FileManager.default.fileExists(atPath: url.path) {
            return true
        }
        return false
    }

    private var sourceLabel: String? {
        switch transcription.sourceKind {
        case .dictation:
            return nil
        case .clipboardAction:
            return NSLocalizedString("Clipboard AI Action", comment: "History source label for clipboard AI actions")
        }
    }

    private var shouldShowAudioDuration: Bool {
        !transcription.isClipboardAction && transcription.duration > 0
    }

    private var headerBadgeText: String {
        if let sourceLabel, transcription.isClipboardAction {
            return sourceLabel
        }
        return formatTiming(transcription.duration)
    }

    private var copyTextForCurrentTab: String {
        switch selectedTab {
        case .original:
            return transcription.text
        case .enhanced:
            return transcription.enhancedText ?? transcription.text
        case .aiRequest:
            var result = ""
            if let systemMsg = transcription.aiRequestSystemMessage, !systemMsg.isEmpty {
                result += systemMsg
            }
            if let userMsg = transcription.aiRequestUserMessage, !userMsg.isEmpty {
                if !result.isEmpty {
                    result += "\n\n"
                }
                result += userMsg
            }
            return result.isEmpty ? transcription.text : result
        }
    }

    private var originalContentView: some View {
        Text(transcription.text)
            .font(theme.typography.body)
            .lineSpacing(2)
            .textSelection(.enabled)
    }

    private func enhancedContentView(_ enhancedText: String) -> some View {
        Text(enhancedText)
            .font(theme.typography.body)
            .lineSpacing(2)
            .textSelection(.enabled)
    }

    private var aiRequestContentView: some View {
        VStack(alignment: .leading, spacing: 12) {

            if let systemMsg = transcription.aiRequestSystemMessage, !systemMsg.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("System Prompt")
                        .font(theme.typography.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(theme.textSecondary)
                    Text(systemMsg)
                        .font(theme.typography.caption)
                        .monospaced()
                        .lineSpacing(2)
                        .textSelection(.enabled)
                }
            }

            if let userMsg = transcription.aiRequestUserMessage, !userMsg.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("User Message")
                        .font(theme.typography.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(theme.textSecondary)
                    Text(userMsg)
                        .font(theme.typography.caption)
                        .monospaced()
                        .lineSpacing(2)
                        .textSelection(.enabled)
                }
            }
        }
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
                            .fill(isSelected ? theme.accentColor.opacity(0.75) : Color.clear)
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

    var body: some View {
        HStack(spacing: 12) {
            Toggle("", isOn: Binding(
                get: { isSelected },
                set: { _ in onToggleSelection() }
            ))
            .toggleStyle(CircularCheckboxStyle())
            .labelsHidden()
            
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text(transcription.timestamp, format: .dateTime.month(.abbreviated).day().year().hour().minute())
                        .font(theme.typography.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(theme.textSecondary)
                    Spacer()

                    Text(headerBadgeText)
                        .font(theme.typography.subheadline)
                        .fontWeight(.medium)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(theme.statusInfo.opacity(0.1))
                        .foregroundColor(theme.statusInfo)
                        .cornerRadius(6)
                }
                .drawingGroup()

                if isExpanded {
                    HStack(spacing: 4) {
                    ForEach(availableTabs, id: \.self) { tab in
                        TabButton(
                            title: tab.titleKey,
                            isSelected: selectedTab == tab,
                            action: { selectedTab = tab }
                        )
                    }

                        Spacer()

                        AnimatedCopyButton(textToCopy: copyTextForCurrentTab)
                    }
                    .padding(.vertical, 8)
                    .padding(.horizontal, 4)

                    ScrollView {
                        VStack(alignment: .leading, spacing: 12) {
                            switch selectedTab {
                            case .original:
                                originalContentView
                            case .enhanced:
                                if let enhancedText = transcription.enhancedText {
                                    enhancedContentView(enhancedText)
                                }
                            case .aiRequest:
                                aiRequestContentView
                            }
                        }
                        .padding(.vertical, 8)
                    }
                    .frame(maxHeight: 300)
                    .cornerRadius(8)

                    if hasAudioFile, let urlString = transcription.audioFileURL,
                       let url = URL(string: urlString) {
                        Divider()
                            .padding(.vertical, 8)
                        AudioPlayerView(url: url)
                    }

                    if hasMetadata {
                        Divider()
                            .padding(.vertical, 8)

                        VStack(alignment: .leading, spacing: 10) {
                            if let sourceLabel {
                                metadataRow(icon: "tray.and.arrow.down.fill", label: "Source", value: sourceLabel)
                            }
                            if shouldShowAudioDuration {
                                metadataRow(icon: "hourglass", label: "Audio Duration", value: formatTiming(transcription.duration))
                            }
                            if let modelName = transcription.transcriptionModelName {
                                metadataRow(icon: "cpu.fill", label: NSLocalizedString("Transcription Model", comment: ""), value: modelName)
                            }
                            if let aiModel = transcription.aiEnhancementModelName {
                                metadataRow(icon: "sparkles", label: "Enhancement Model", value: aiModel)
                            }
                            if let promptName = transcription.promptName {
                                metadataRow(icon: "text.bubble.fill", label: "Prompt Used", value: promptName)
                            }
                            if let duration = transcription.transcriptionDuration {
                                metadataRow(icon: "clock.fill", label: "Transcription Time", value: formatTiming(duration))
                            }
                            if let duration = transcription.enhancementDuration {
                                metadataRow(icon: "clock.fill", label: "Enhancement Time", value: formatTiming(duration))
                            }
                        }
                    }
                } else {
                    Text(transcription.enhancedText ?? transcription.text)
                        .font(theme.typography.body)
                        .lineLimit(2)
                        .lineSpacing(2)
                }
            }
        }
        .padding(16)
        .background(CardBackground(isSelected: false))
        .cornerRadius(12)
        .shadow(color: theme.shadowColor.opacity(0.05), radius: 3, x: 0, y: 2)
        .contextMenu {
            if let enhancedText = transcription.enhancedText {
                Button {
                    let _ = ClipboardManager.copyToClipboard(enhancedText)
                } label: {
                    Label("Copy Enhanced", systemImage: "doc.on.doc")
                }
            }

            Button {
                let _ = ClipboardManager.copyToClipboard(transcription.text)
            } label: {
                Label("Copy Original", systemImage: "doc.on.doc")
            }

            Button(role: .destructive) {
                onDelete()
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
        .onChange(of: isExpanded) { oldValue, newValue in
            if newValue {
                selectedTab = transcription.enhancedText != nil ? .enhanced : .original
            }
        }
    }

    private var hasMetadata: Bool {
        sourceLabel != nil ||
        transcription.transcriptionModelName != nil ||
        transcription.aiEnhancementModelName != nil ||
        transcription.promptName != nil ||
        transcription.transcriptionDuration != nil ||
        transcription.enhancementDuration != nil
    }
    
    private func formatTiming(_ duration: TimeInterval) -> String {
        if duration < 1 {
            return String(format: "%.0fms", duration * 1000)
        }
        if duration < 60 {
            return String(format: "%.1fs", duration)
        }
        let minutes = Int(duration) / 60
        let seconds = duration.truncatingRemainder(dividingBy: 60)
        return String(format: "%dm %.0fs", minutes, seconds)
    }
    
    private func metadataRow(icon: String, label: String, value: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(theme.typography.caption)
                .fontWeight(.medium)
                .foregroundColor(theme.textSecondary)
                .frame(width: 20, alignment: .center)
            
            Text(LocalizedStringKey(label))
                .font(theme.typography.caption)
                .fontWeight(.medium)
                .foregroundColor(theme.textPrimary)
            Spacer()
            Text(value)
                .font(theme.typography.caption)
                .fontWeight(.semibold)
                .foregroundColor(theme.textSecondary)
        }
    }
}
