import Foundation

/// Async service for scanning project directories
actor ProjectScanner {
    private let typeDetector = TypeDetector()
    private let gitHelper = GitHelper()
    private let readmeExtractor = ReadmeExtractor()

    typealias ProgressHandler = @Sendable (Double) -> Void

    /// Scans a directory for project subfolders (one level deep)
    func scanDirectory(
        at url: URL,
        progressHandler: ProgressHandler? = nil
    ) async throws -> [Project] {
        let fileManager = FileManager.default

        // Get contents (one level deep)
        let contents = try fileManager.contentsOfDirectory(
            at: url,
            includingPropertiesForKeys: [
                .isDirectoryKey,
                .creationDateKey,
                .contentModificationDateKey
            ],
            options: [.skipsHiddenFiles]
        )

        // Filter to directories only
        let directories = contents.filter { url in
            (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true
        }

        let totalCount = Double(directories.count)
        var projects: [Project] = []

        for (index, directoryURL) in directories.enumerated() {
            let project = await scanProjectFolder(at: directoryURL)
            projects.append(project)

            // Report progress
            let progress = Double(index + 1) / totalCount
            progressHandler?(progress)
        }

        return projects
    }

    /// Extracts metadata from a single project folder
    private func scanProjectFolder(at url: URL) async -> Project {
        let fileManager = FileManager.default

        // Get file attributes
        let resourceValues = try? url.resourceValues(forKeys: [
            .creationDateKey,
            .contentModificationDateKey
        ])

        let creationDate = resourceValues?.creationDate ?? Date()
        let modificationDate = resourceValues?.contentModificationDate ?? Date()

        // Detect project type
        let projectType = await typeDetector.detectType(at: url)

        // Check for git and extract remote URL
        let gitPath = url.appendingPathComponent(".git")
        let hasGit = fileManager.fileExists(atPath: gitPath.path)
        let gitRemoteURL = hasGit ? await gitHelper.extractRemoteURL(from: url) : nil

        // Check for README and extract preview
        let readmePath = url.appendingPathComponent("README.md")
        let hasReadme = fileManager.fileExists(atPath: readmePath.path)
        let readmePreview = hasReadme ? await readmeExtractor.extractPreview(
            from: readmePath,
            maxLength: 300
        ) : nil

        return Project(
            name: url.lastPathComponent,
            path: url,
            creationDate: creationDate,
            modificationDate: modificationDate,
            projectType: projectType,
            gitRemoteURL: gitRemoteURL,
            readmePreview: readmePreview,
            hasGit: hasGit,
            hasReadme: hasReadme
        )
    }
}
