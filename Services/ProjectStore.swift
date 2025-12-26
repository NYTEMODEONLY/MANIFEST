import Foundation
import SwiftUI
import Observation

/// Sort options for the project list
enum SortOption: String, CaseIterable, Identifiable {
    case alphabetical = "A-Z"
    case lastModified = "Last Modified"
    case creationDate = "Created"
    case hasGit = "Git Repos First"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .alphabetical: return "textformat.abc"
        case .lastModified: return "clock"
        case .creationDate: return "calendar"
        case .hasGit: return "arrow.triangle.branch"
        }
    }
}

/// Main observable store for all project data and state
@Observable
@MainActor
final class ProjectStore {
    // MARK: - Published State

    private(set) var projects: [Project] = []
    private(set) var isScanning: Bool = false
    private(set) var scanProgress: Double = 0.0
    private(set) var errorMessage: String?
    private(set) var rootFolderURL: URL?

    /// GitHub repo status cache (keyed by repo name like "user/repo")
    private(set) var gitHubStatusCache: [String: GitHubRepoStatus] = [:]

    var selectedProject: Project?
    var searchText: String = ""
    var sortOption: SortOption = .alphabetical

    // MARK: - Dependencies

    private let scanner = ProjectScanner()
    private let bookmarkManager = BookmarkManager()

    // MARK: - Computed Properties

    /// Filtered and sorted projects based on current sort option
    var displayedProjects: [Project] {
        let filtered = searchText.isEmpty
            ? projects
            : projects.filter { $0.name.localizedCaseInsensitiveContains(searchText) }

        switch sortOption {
        case .alphabetical:
            return filtered.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        case .lastModified:
            return filtered.sorted { $0.modificationDate > $1.modificationDate }
        case .creationDate:
            return filtered.sorted { $0.creationDate > $1.creationDate }
        case .hasGit:
            return filtered.sorted { (lhs, rhs) in
                if lhs.hasGit == rhs.hasGit {
                    return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
                }
                return lhs.hasGit && !rhs.hasGit
            }
        }
    }

    var hasProjects: Bool { !projects.isEmpty }
    var hasRootFolder: Bool { rootFolderURL != nil }

    /// Stats for display
    var projectCount: Int { projects.count }
    var gitProjectCount: Int { projects.filter { $0.hasGit }.count }
    var readmeProjectCount: Int { projects.filter { $0.hasReadme }.count }

    // MARK: - Initialization

    init() {
        // Don't do anything heavy in init
        // Restore is triggered by the view
    }

    /// Call this once the app is ready to restore previous session
    func restoreIfNeeded() {
        guard !hasRootFolder && !isScanning else { return }
        Task {
            await restoreSavedFolder()
        }
    }

    // MARK: - Public Methods

    /// Opens folder picker and starts scanning
    func selectFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.message = "Select a folder containing your projects"
        panel.prompt = "Select"

        if panel.runModal() == .OK, let url = panel.url {
            Task {
                await setRootFolder(url)
            }
        }
    }

    /// Sets the root folder and triggers a scan
    func setRootFolder(_ url: URL) async {
        do {
            try bookmarkManager.saveBookmark(for: url)
            rootFolderURL = url
            await scan()
        } catch {
            errorMessage = "Failed to save folder access: \(error.localizedDescription)"
        }
    }

    /// Refreshes the project list
    func refresh() async {
        guard rootFolderURL != nil else { return }
        await scan()
    }

    /// Clears the error message
    func clearError() {
        errorMessage = nil
    }

    /// Gets the GitHub status for a project (returns cached or unchecked)
    func gitHubStatus(for project: Project) -> GitHubRepoStatus {
        guard let repoName = project.gitHubRepoName else {
            return .unchecked
        }
        return gitHubStatusCache[repoName] ?? .unchecked
    }

    /// Checks the GitHub status for a project (makes network request if needed)
    /// - Parameters:
    ///   - project: The project to check
    ///   - isAuthenticated: Whether the user is signed in to GitHub
    ///   - token: The GitHub access token (if authenticated)
    func checkGitHubStatus(for project: Project, isAuthenticated: Bool, token: String?) {
        guard let repoName = project.gitHubRepoName else { return }

        // Skip if already have a result
        if let cached = gitHubStatusCache[repoName],
           cached != .unchecked && cached != .notSignedIn {
            return
        }

        // If not signed in, show that status
        guard isAuthenticated else {
            gitHubStatusCache[repoName] = .notSignedIn
            return
        }

        // Mark as checking
        gitHubStatusCache[repoName] = .checking

        // Use URLSession directly instead of actor to avoid deadlock
        guard let url = URL(string: "https://api.github.com/repos/\(repoName)") else {
            gitHubStatusCache[repoName] = .unavailable
            return
        }

        var request = URLRequest(url: url)
        if let token = token {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        request.setValue("application/vnd.github.v3+json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 5

        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            DispatchQueue.main.async {
                guard let self = self else { return }

                if let httpResponse = response as? HTTPURLResponse {
                    switch httpResponse.statusCode {
                    case 200:
                        // Check if private
                        if let data = data,
                           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                           let isPrivate = json["private"] as? Bool {
                            self.gitHubStatusCache[repoName] = isPrivate ? .privateRepo : .publicRepo
                        } else {
                            self.gitHubStatusCache[repoName] = .publicRepo
                        }
                    case 404:
                        self.gitHubStatusCache[repoName] = .unavailable
                    default:
                        self.gitHubStatusCache[repoName] = .unavailable
                    }
                } else {
                    self.gitHubStatusCache[repoName] = .unavailable
                }
            }
        }.resume()
    }

    /// Clears cached GitHub statuses (call after signing in)
    func clearGitHubStatusCache() {
        gitHubStatusCache.removeAll()
    }

    // MARK: - Private Methods

    private func restoreSavedFolder() async {
        if let url = bookmarkManager.restoreBookmark() {
            rootFolderURL = url
            await scan()
        }
    }

    private func scan() async {
        guard let url = rootFolderURL else { return }

        isScanning = true
        scanProgress = 0.0
        errorMessage = nil

        do {
            // Start security-scoped access
            guard url.startAccessingSecurityScopedResource() else {
                throw ScanError.accessDenied
            }
            defer { url.stopAccessingSecurityScopedResource() }

            projects = try await scanner.scanDirectory(
                at: url,
                progressHandler: { @MainActor [weak self] progress in
                    self?.scanProgress = progress
                }
            )
        } catch {
            errorMessage = "Scan failed: \(error.localizedDescription)"
        }

        isScanning = false
    }
}

// MARK: - Errors

enum ScanError: LocalizedError {
    case accessDenied
    case invalidDirectory

    var errorDescription: String? {
        switch self {
        case .accessDenied:
            return "Cannot access the selected folder. Please grant permission."
        case .invalidDirectory:
            return "The selected path is not a valid directory."
        }
    }
}
