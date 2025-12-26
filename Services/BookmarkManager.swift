import Foundation

/// Manages security-scoped bookmarks for persistent folder access
final class BookmarkManager: Sendable {
    private let bookmarkKey = "com.manifest.rootFolderBookmark"

    /// Saves a security-scoped bookmark for the given URL
    func saveBookmark(for url: URL) throws {
        let bookmarkData = try url.bookmarkData(
            options: .withSecurityScope,
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        )

        UserDefaults.standard.set(bookmarkData, forKey: bookmarkKey)
    }

    /// Restores the previously saved security-scoped bookmark
    func restoreBookmark() -> URL? {
        guard let bookmarkData = UserDefaults.standard.data(forKey: bookmarkKey) else {
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

            // Refresh stale bookmark
            if isStale {
                try saveBookmark(for: url)
            }

            return url
        } catch {
            print("Failed to restore bookmark: \(error)")
            return nil
        }
    }

    /// Clears the saved bookmark
    func clearBookmark() {
        UserDefaults.standard.removeObject(forKey: bookmarkKey)
    }
}
