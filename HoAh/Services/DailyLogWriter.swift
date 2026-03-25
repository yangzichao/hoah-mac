import Foundation

/// Handles file operations for daily log files.
/// Each day's transcriptions are stored in a single Markdown file.
struct DailyLogWriter {
    
    /// Generates filename for a given date (e.g., "hoah-2024-12-23.md")
    /// Uses the user's local timezone.
    /// - Parameter date: The date to generate filename for
    /// - Returns: Filename string
    static func filename(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = .current
        return "hoah-\(formatter.string(from: date)).md"
    }
    
    /// Formats a transcription entry with timestamp and timezone.
    /// - Parameters:
    ///   - text: Original transcription text
    ///   - enhancedText: Enhanced text (optional, preferred over original)
    ///   - timestamp: The timestamp of the transcription
    /// - Returns: Formatted Markdown entry
    static func formatEntry(
        text: String,
        enhancedText: String? = nil,
        timestamp: Date
    ) -> String {
        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "HH:mm"
        timeFormatter.timeZone = .current
        
        let timeString = timeFormatter.string(from: timestamp)
        let timezoneOffset = formatTimezoneOffset()
        
        // Use enhanced text if available, otherwise original
        let content = (enhancedText?.isEmpty == false ? enhancedText : text) ?? text
        
        return """
        ## \(timeString) (\(timezoneOffset))
        
        \(content)
        
        ---
        
        """
    }
    
    /// Appends entry to the daily log file, creating if needed.
    /// - Parameters:
    ///   - text: Original transcription text
    ///   - enhancedText: Enhanced text (optional)
    ///   - folderURL: The folder to write to
    ///   - date: The date for the log file
    /// - Throws: Error if write fails
    static func append(
        text: String,
        enhancedText: String?,
        to folderURL: URL,
        for date: Date
    ) throws {
        let fileURL = folderURL.appendingPathComponent(filename(for: date))
        let entry = formatEntry(text: text, enhancedText: enhancedText, timestamp: date)
        
        if FileManager.default.fileExists(atPath: fileURL.path) {
            // Append to existing file
            let fileHandle = try FileHandle(forWritingTo: fileURL)
            defer { try? fileHandle.close() }
            
            try fileHandle.seekToEnd()
            if let data = entry.data(using: .utf8) {
                try fileHandle.write(contentsOf: data)
            }
        } else {
            // Create new file with header
            let header = createHeader(for: date)
            let content = header + entry
            try content.write(to: fileURL, atomically: true, encoding: .utf8)
        }
    }
    
    // MARK: - Private Helpers
    
    /// Creates the header for a new daily log file.
    private static func createHeader(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = .current
        return "# \(formatter.string(from: date))\n\n"
    }
    
    /// Formats the current timezone offset (e.g., "UTC+8" or "UTC-5")
    private static func formatTimezoneOffset() -> String {
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
