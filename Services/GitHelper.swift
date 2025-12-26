import Foundation

/// Extracts git remote URL from .git/config
actor GitHelper {

    /// Extracts the origin remote URL from a git repository
    func extractRemoteURL(from projectURL: URL) async -> String? {
        let configPath = projectURL
            .appendingPathComponent(".git")
            .appendingPathComponent("config")

        guard let configData = try? Data(contentsOf: configPath),
              let configString = String(data: configData, encoding: .utf8) else {
            return nil
        }

        return parseRemoteURL(from: configString)
    }

    /// Parses the remote "origin" URL from git config content
    private func parseRemoteURL(from configContent: String) -> String? {
        let lines = configContent.components(separatedBy: .newlines)
        var inOriginSection = false

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            // Check for [remote "origin"] section
            if trimmed.hasPrefix("[remote \"origin\"]") {
                inOriginSection = true
                continue
            }

            // Check for new section (exit origin)
            if trimmed.hasPrefix("[") && inOriginSection {
                break
            }

            // Extract URL if in origin section
            if inOriginSection && trimmed.hasPrefix("url = ") {
                let url = trimmed.replacingOccurrences(of: "url = ", with: "")
                return url.isEmpty ? nil : url
            }
        }

        return nil
    }

    /// Converts git SSH URL to HTTPS URL for display
    func normalizeGitURL(_ url: String) -> String {
        if url.hasPrefix("git@github.com:") {
            return url
                .replacingOccurrences(of: "git@github.com:", with: "https://github.com/")
                .replacingOccurrences(of: ".git", with: "")
        }
        return url.replacingOccurrences(of: ".git", with: "")
    }
}
