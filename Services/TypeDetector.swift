import Foundation

/// Detects project type based on configuration files present in the folder
actor TypeDetector {

    /// Detects the project type by checking for known config files
    func detectType(at url: URL) async -> ProjectType {
        let fileManager = FileManager.default

        // Priority-ordered detection patterns
        let patterns: [(fileName: String, type: ProjectType)] = [
            ("Package.swift", .swift),
            ("package.json", .nodejs),
            ("Cargo.toml", .rust),
            ("go.mod", .go),
            ("pubspec.yaml", .flutter),
            ("pyproject.toml", .python),
            ("requirements.txt", .python),
            ("setup.py", .python),
            ("Gemfile", .ruby),
            ("pom.xml", .java),
            ("build.gradle", .java),
        ]

        // Check for each pattern in priority order
        for pattern in patterns {
            let filePath = url.appendingPathComponent(pattern.fileName)
            if fileManager.fileExists(atPath: filePath.path) {
                return pattern.type
            }
        }

        // Check for Xcode or .NET projects by extension
        if let contents = try? fileManager.contentsOfDirectory(
            at: url,
            includingPropertiesForKeys: nil,
            options: .skipsHiddenFiles
        ) {
            for item in contents {
                let ext = item.pathExtension.lowercased()
                if ext == "xcodeproj" || ext == "xcworkspace" {
                    return .swift
                }
                if ext == "csproj" || ext == "sln" {
                    return .dotnet
                }
            }
        }

        return .unknown
    }
}
