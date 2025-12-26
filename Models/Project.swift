import Foundation
import SwiftUI

/// Represents a single project folder with all extracted metadata
struct Project: Identifiable, Hashable, Sendable {
    let id: UUID
    let name: String
    let path: URL
    let creationDate: Date
    let modificationDate: Date
    let projectType: ProjectType
    let gitRemoteURL: String?
    let readmePreview: String?
    let hasGit: Bool
    let hasReadme: Bool

    nonisolated init(
        id: UUID = UUID(),
        name: String,
        path: URL,
        creationDate: Date,
        modificationDate: Date,
        projectType: ProjectType,
        gitRemoteURL: String? = nil,
        readmePreview: String? = nil,
        hasGit: Bool = false,
        hasReadme: Bool = false
    ) {
        self.id = id
        self.name = name
        self.path = path
        self.creationDate = creationDate
        self.modificationDate = modificationDate
        self.projectType = projectType
        self.gitRemoteURL = gitRemoteURL
        self.readmePreview = readmePreview
        self.hasGit = hasGit
        self.hasReadme = hasReadme
    }

    // MARK: - Computed Properties

    /// GitHub repo name extracted from remote URL (e.g., "user/repo")
    var gitHubRepoName: String? {
        guard let url = gitRemoteURL else { return nil }

        // Handle: https://github.com/user/repo or git@github.com:user/repo
        if url.contains("github.com") {
            let cleaned = url
                .replacingOccurrences(of: "https://github.com/", with: "")
                .replacingOccurrences(of: "git@github.com:", with: "")
                .replacingOccurrences(of: ".git", with: "")

            let components = cleaned.split(separator: "/")
            if components.count >= 2 {
                return "\(components[0])/\(components[1])"
            }
        }
        return nil
    }

    /// Normalized HTTPS GitHub URL for opening in browser
    var gitHubURL: URL? {
        guard let repoName = gitHubRepoName else { return nil }
        return URL(string: "https://github.com/\(repoName)")
    }

    /// Relative date string (e.g., "3 days ago")
    var formattedModificationDate: String {
        Self.dateFormatter.localizedString(for: modificationDate, relativeTo: Date())
    }

    /// Shared date formatter for performance
    private static let dateFormatter: RelativeDateTimeFormatter = {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter
    }()

    /// SF Symbol for project type
    var typeIcon: String {
        projectType.iconName
    }

    /// Color for project type badge
    var typeColor: Color {
        projectType.color
    }
}

// MARK: - Hashable & Equatable

extension Project {
    static func == (lhs: Project, rhs: Project) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}
