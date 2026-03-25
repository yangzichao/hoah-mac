import Foundation

/// Manages security-scoped bookmarks for sandbox-compatible folder access.
/// Used to persist user-selected folder paths across app launches.
struct SecurityScopedBookmarkManager {
    
    private static let bookmarkKey = "autoExportFolderBookmark"
    
    /// Creates and stores a security-scoped bookmark for a URL.
    /// - Parameter url: The folder URL to create a bookmark for
    /// - Throws: Error if bookmark creation fails
    static func saveBookmark(for url: URL) throws {
        let bookmarkData = try url.bookmarkData(
            options: .withSecurityScope,
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        )
        UserDefaults.hoah.set(bookmarkData, forKey: bookmarkKey)
    }
    
    /// Resolves stored bookmark back to a URL.
    /// - Returns: The resolved URL, or nil if no bookmark exists or resolution fails
    static func resolveBookmark() -> URL? {
        guard let bookmarkData = UserDefaults.hoah.data(forKey: bookmarkKey) else {
            return nil
        }
        
        do {
            var isStale = false
            let url = try URL(
                resolvingBookmarkData: bookmarkData,
                options: .withSecurityScope,
                relativeTo: nil,
                bookmarkDataIsStale: &isStale
            )
            
            // In unsandboxed dev builds, avoid touching other apps' containers to prevent
            // macOS AppData prompts. If the stored bookmark points there, skip and let the
            // user reselect a normal folder.
            let isSandboxed = ProcessInfo.processInfo.environment["APP_SANDBOX_CONTAINER_ID"] != nil
            if !isSandboxed,
               url.path.contains("/Library/Containers/"),
               !url.path.contains("com.yangzichao.hoah") {
                print("[SecurityScopedBookmarkManager] Skipping foreign container bookmark in unsandboxed build: \(url.path)")
                return nil
            }
            
            // If bookmark is stale, try to refresh it
            if isStale {
                try? saveBookmark(for: url)
            }
            
            return url
        } catch {
            print("[SecurityScopedBookmarkManager] Failed to resolve bookmark: \(error)")
            return nil
        }
    }
    
    /// Clears the stored bookmark.
    static func clearBookmark() {
        UserDefaults.hoah.removeObject(forKey: bookmarkKey)
    }
    
    /// Checks if a bookmark exists and is valid.
    /// - Returns: true if a valid bookmark exists
    static func hasValidBookmark() -> Bool {
        resolveBookmark() != nil
    }
    
    /// Starts accessing the security-scoped resource.
    /// Must be balanced with `stopAccessing(url:)`.
    /// - Parameter url: The URL to start accessing
    /// - Returns: true if access was granted
    @discardableResult
    static func startAccessing(url: URL) -> Bool {
        url.startAccessingSecurityScopedResource()
    }
    
    /// Stops accessing the security-scoped resource.
    /// - Parameter url: The URL to stop accessing
    static func stopAccessing(url: URL) {
        url.stopAccessingSecurityScopedResource()
    }
}
