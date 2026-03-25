import SwiftUI

struct MetricsContent: View {
    let transcriptions: [Transcription]
    let selectedRange: HistoryTimeRange
    @State private var showKeyboardShortcuts = false
    @Environment(\.theme) private var theme

    var body: some View {
        Group {
            if transcriptions.isEmpty {
                emptyStateView
            } else {
                VStack(spacing: 20) {
                    metricsSection
                }
                .padding(.vertical, 28)
                .padding(.horizontal, 32)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(theme.windowBackground)
            }
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "waveform")
                .font(.system(size: 56, weight: .semibold))
                .foregroundColor(theme.textSecondary)
            Text("No Transcriptions Yet")
                .font(theme.typography.title3)
            Text("Start your first recording to unlock value insights.")
                .foregroundColor(theme.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(theme.windowBackground)
    }
    
    // MARK: - Sections

    private var filteredTranscriptions: [Transcription] {
        guard let cutoff = selectedRange.cutoffDate else { return transcriptions }
        return transcriptions.filter { $0.timestamp >= cutoff }
    }

    private var metricsSection: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 240), spacing: 16)], spacing: 16) {
            MetricCard(
                icon: "mic.fill",
                title: "Sessions Recorded",
                value: "\(filteredTranscriptions.count)",
                detail: "HoAh sessions completed",
                color: theme.accentColor
            )
            
            MetricCard(
                icon: "text.alignleft",
                title: "Words Dictated",
                value: Formatters.formattedNumber(totalWordsTranscribed),
                detail: "words generated",
                color: theme.accentColor
            )
        }
    }
    
    // MARK: - Computed Metrics
    
    private var totalWordsTranscribed: Int {
        filteredTranscriptions.reduce(0) { $0 + $1.text.smartWordCount }
    }
}
    
private enum Formatters {
    static let numberFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return formatter
    }()
    
    static func formattedNumber(_ value: Int) -> String {
        return numberFormatter.string(from: NSNumber(value: value)) ?? "\(value)"
    }
}
