
import Foundation
import AppKit

class HoAhMarkdownExportService {
    
    /// Exports transcriptions to multiple Markdown files, grouped by day.
    /// If a default export path is configured, exports directly there.
    /// Otherwise, shows a folder picker dialog.
    /// - Parameters:
    ///   - transcriptions: The list of transcriptions to export.
    func exportTranscriptionsToDailyMarkdown(transcriptions: [Transcription]) {
        // 1. Group by day
        let grouped = Dictionary(grouping: transcriptions) { transcription -> String in
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            return formatter.string(from: transcription.timestamp)
        }
        
        // 2. Check for configured default path
        if let defaultURL = SecurityScopedBookmarkManager.resolveBookmark() {
            // Use default path directly
            if SecurityScopedBookmarkManager.startAccessing(url: defaultURL) {
                defer { SecurityScopedBookmarkManager.stopAccessing(url: defaultURL) }
                writeFiles(grouped: grouped, to: defaultURL)
                showExportSuccessNotification(count: transcriptions.count)
            } else {
                // Fallback to folder picker if access fails
                showFolderPicker(grouped: grouped)
            }
        } else {
            // No default path, show folder picker
            showFolderPicker(grouped: grouped)
        }
    }
    
    private func showFolderPicker(grouped: [String: [Transcription]]) {
        let openPanel = NSOpenPanel()
        openPanel.title = NSLocalizedString("Select a folder to export daily Markdown files", comment: "")
        openPanel.canChooseDirectories = true
        openPanel.canChooseFiles = false
        openPanel.allowsMultipleSelection = false
        openPanel.canCreateDirectories = true
        openPanel.prompt = NSLocalizedString("Export Here", comment: "")
        
        openPanel.begin { result in
            if result == .OK, let folderURL = openPanel.url {
                self.writeFiles(grouped: grouped, to: folderURL)
            }
        }
    }
    
    private func showExportSuccessNotification(count: Int) {
        Task { @MainActor in
            NotificationManager.shared.showNotification(
                title: String(format: NSLocalizedString("Exported %d transcriptions", comment: ""), count),
                type: .success
            )
        }
    }
    
    private func writeFiles(grouped: [String: [Transcription]], to folderURL: URL) {
        let timeFormatter = DateFormatter()
        timeFormatter.timeStyle = .medium
        timeFormatter.dateStyle = .none
        
        for (dateString, dayTranscriptions) in grouped {
            // Sort by time within the day
            let sortedTranscriptions = dayTranscriptions.sorted { $0.timestamp < $1.timestamp }
            
            var content = "# \(dateString)\n\n"
            
            for transcription in sortedTranscriptions {
                let timeString = timeFormatter.string(from: transcription.timestamp)
                let timezoneOffset = formatTimezoneOffset()
                content += "## \(timeString) (\(timezoneOffset))\n\n"

                if transcription.isClipboardAction {
                    content += "> Source: Selection AI Action\n\n"
                }
                
                // Prioritize enhanced text, fallback to original
                if let enhanced = transcription.enhancedText, !enhanced.isEmpty {
                    content += "\(enhanced)\n\n"
                } else {
                    content += "\(transcription.text)\n\n"
                }
                
                content += "---\n\n"
            }
            
            let fileURL = folderURL.appendingPathComponent("hoah-\(dateString).md")
            
            do {
                try content.write(to: fileURL, atomically: true, encoding: .utf8)
            } catch {
                print("Failed to write markdown file for \(dateString): \(error)")
            }
        }
        
        // Open the folder after export
        NSWorkspace.shared.activateFileViewerSelecting([folderURL])
    }
    
    /// Formats the current timezone offset (e.g., "UTC+8" or "UTC-5")
    private func formatTimezoneOffset() -> String {
        let seconds = TimeZone.current.secondsFromGMT()
        let hours = seconds / 3600
        let minutes = abs(seconds % 3600) / 60
        
        if minutes == 0 {
            if hours >= 0 {
                return "UTC+\(hours)"
            } else {
                return "UTC\(hours)"
            }
        } else {
            let sign = hours >= 0 ? "+" : "-"
            return "UTC\(sign)\(abs(hours)):\(String(format: "%02d", minutes))"
        }
    }
}
