import Foundation

/// Service coordinating automatic export of transcriptions to daily log files.
class AutoExportService {
    
    /// Singleton instance
    static let shared = AutoExportService()
    
    private init() {}
    
    /// Appends a transcription to the daily log if auto export is enabled.
    /// Errors are logged silently without interrupting user workflow.
    /// - Parameters:
    ///   - text: Original transcription text
    ///   - enhancedText: Enhanced text (optional, preferred over original)
    ///   - timestamp: The timestamp of the transcription
    func appendTranscriptionIfEnabled(
        text: String,
        enhancedText: String?,
        timestamp: Date = Date()
    ) {
        // Check if auto export is enabled
        guard UserDefaults.hoah.bool(forKey: "isAutoExportEnabled") else {
            return
        }
        
        // Resolve export folder
        guard let folderURL = resolveExportURL() else {
            print("[AutoExportService] No valid export path configured")
            return
        }
        
        // Start accessing security-scoped resource
        guard SecurityScopedBookmarkManager.startAccessing(url: folderURL) else {
            print("[AutoExportService] Failed to access export folder")
            return
        }
        
        defer {
            SecurityScopedBookmarkManager.stopAccessing(url: folderURL)
        }
        
        // Append to daily log
        do {
            try DailyLogWriter.append(
                text: text,
                enhancedText: enhancedText,
                to: folderURL,
                for: timestamp
            )
        } catch {
            // Log error silently, don't interrupt user workflow
            print("[AutoExportService] Failed to append transcription: \(error)")
        }
    }
    
    /// Validates the configured export path is accessible.
    /// - Returns: true if path is valid and accessible
    func validateExportPath() -> Bool {
        guard let url = resolveExportURL() else {
            return false
        }
        
        // Check if folder exists and is writable
        var isDirectory: ObjCBool = false
        let exists = FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory)
        
        guard exists && isDirectory.boolValue else {
            return false
        }
        
        // Try to access the security-scoped resource
        guard SecurityScopedBookmarkManager.startAccessing(url: url) else {
            return false
        }
        
        defer {
            SecurityScopedBookmarkManager.stopAccessing(url: url)
        }
        
        return FileManager.default.isWritableFile(atPath: url.path)
    }
    
    /// Resolves the security-scoped bookmark to a URL.
    /// - Returns: The resolved URL, or nil if no valid bookmark exists
    func resolveExportURL() -> URL? {
        SecurityScopedBookmarkManager.resolveBookmark()
    }
    
    /// Returns the display path for the configured export folder.
    /// - Returns: Path string for UI display, or nil if not configured
    func displayPath() -> String? {
        resolveExportURL()?.path
    }
}
