import Foundation

/// Status of a GitHub repository
enum GitHubRepoStatus: Sendable, Equatable {
    case unchecked
    case checking
    case publicRepo
    case privateRepo
    case unavailable  // 404 - deleted or doesn't exist
    case notSignedIn  // Need to sign in for accurate status

    var label: String {
        switch self {
        case .unchecked: return "Unchecked"
        case .checking: return "Checking..."
        case .publicRepo: return "Public"
        case .privateRepo: return "Private"
        case .unavailable: return "Unavailable"
        case .notSignedIn: return "Sign in for status"
        }
    }

    var icon: String {
        switch self {
        case .unchecked: return "questionmark.circle"
        case .checking: return "arrow.trianglehead.2.clockwise"
        case .publicRepo: return "globe"
        case .privateRepo: return "lock.fill"
        case .unavailable: return "xmark.circle"
        case .notSignedIn: return "person.crop.circle.badge.questionmark"
        }
    }
}

/// Detailed repo info from GitHub API
struct GitHubRepoInfo: Sendable {
    let status: GitHubRepoStatus
    let isPrivate: Bool
    let defaultBranch: String?
    let description: String?
    let starCount: Int
    let forkCount: Int
    let updatedAt: Date?
}

/// Service to check GitHub repository status using authenticated API
actor GitHubChecker {
    private var cache: [String: GitHubRepoInfo] = [:]

    /// Checks repo status using authenticated GitHub API
    /// - Parameters:
    ///   - repoName: The repo name in format "owner/repo"
    ///   - token: The GitHub access token (nil if not signed in)
    /// - Returns: Detailed repo info
    func checkRepoStatus(repoName: String, token: String?) async -> GitHubRepoInfo {
        // Return cached result if available
        if let cached = cache[repoName] {
            return cached
        }

        // Check if authenticated
        guard let token = token else {
            return GitHubRepoInfo(
                status: .notSignedIn,
                isPrivate: false,
                defaultBranch: nil,
                description: nil,
                starCount: 0,
                forkCount: 0,
                updatedAt: nil
            )
        }

        // GitHub API endpoint
        let urlString = "https://api.github.com/repos/\(repoName)"
        guard let url = URL(string: urlString) else {
            return makeUnavailableInfo()
        }

        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/vnd.github.v3+json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 5  // Short timeout to avoid hanging

        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                return makeUnavailableInfo()
            }

            switch httpResponse.statusCode {
            case 200:
                // Parse the repo data
                let info = try parseRepoResponse(data: data)
                cache[repoName] = info
                return info

            case 404:
                // Repo doesn't exist or was deleted
                let info = makeUnavailableInfo()
                cache[repoName] = info
                return info

            case 401:
                // Token expired
                return GitHubRepoInfo(
                    status: .notSignedIn,
                    isPrivate: false,
                    defaultBranch: nil,
                    description: nil,
                    starCount: 0,
                    forkCount: 0,
                    updatedAt: nil
                )

            default:
                return makeUnavailableInfo()
            }

        } catch {
            // Network error
            return makeUnavailableInfo()
        }
    }

    /// Simple status check (returns just the status enum)
    func getStatus(repoName: String, token: String?) async -> GitHubRepoStatus {
        let info = await checkRepoStatus(repoName: repoName, token: token)
        return info.status
    }

    /// Clears the cache
    func clearCache() {
        cache.removeAll()
    }

    // MARK: - Private Helpers

    private func parseRepoResponse(data: Data) throws -> GitHubRepoInfo {
        struct RepoResponse: Codable {
            let `private`: Bool
            let defaultBranch: String?
            let description: String?
            let stargazersCount: Int
            let forksCount: Int
            let updatedAt: String?

            enum CodingKeys: String, CodingKey {
                case `private`
                case defaultBranch = "default_branch"
                case description
                case stargazersCount = "stargazers_count"
                case forksCount = "forks_count"
                case updatedAt = "updated_at"
            }
        }

        let repo = try JSONDecoder().decode(RepoResponse.self, from: data)

        let dateFormatter = ISO8601DateFormatter()
        let updatedAt = repo.updatedAt.flatMap { dateFormatter.date(from: $0) }

        return GitHubRepoInfo(
            status: repo.private ? .privateRepo : .publicRepo,
            isPrivate: repo.private,
            defaultBranch: repo.defaultBranch,
            description: repo.description,
            starCount: repo.stargazersCount,
            forkCount: repo.forksCount,
            updatedAt: updatedAt
        )
    }

    private func makeUnavailableInfo() -> GitHubRepoInfo {
        GitHubRepoInfo(
            status: .unavailable,
            isPrivate: false,
            defaultBranch: nil,
            description: nil,
            starCount: 0,
            forkCount: 0,
            updatedAt: nil
        )
    }
}
