import SwiftUI
import SwiftData
import Charts
import KeyboardShortcuts

struct MetricsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Transcription.timestamp) private var transcriptions: [Transcription]
    @EnvironmentObject private var whisperState: WhisperState
    @EnvironmentObject private var hotkeyManager: HotkeyManager
    @Environment(\.theme) private var theme
    @State private var selectedHistoryRange: HistoryTimeRange = .last7Days
    
    var body: some View {
        VStack(spacing: 0) {
            MetricsContent(
                transcriptions: Array(transcriptions),
                selectedRange: selectedHistoryRange
            )

            if !transcriptions.isEmpty {
                Divider()
                    .padding(.top, 8)

                TranscriptionHistoryView(selectedRange: $selectedHistoryRange)
            }
        }
        .background(theme.controlBackground)
    }
}
