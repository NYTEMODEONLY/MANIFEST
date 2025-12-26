import SwiftUI

/// The detail pane showing selected project information
struct DetailView: View {
    @Environment(ProjectStore.self) private var store

    var body: some View {
        Group {
            if let project = store.selectedProject {
                ProjectDetailContent(project: project)
            } else {
                EmptyStateView(
                    icon: "sidebar.leading",
                    title: "No Selection",
                    message: "Select a project from the sidebar to view its details."
                )
            }
        }
        .frame(minWidth: 500)
    }
}

// MARK: - Detail Content

private struct ProjectDetailContent: View {
    @Environment(ProjectStore.self) private var store
    @Environment(GitHubAuth.self) private var gitHubAuth
    let project: Project

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Header
                headerSection

                Divider()

                // Metadata grid
                metadataSection

                // Git section (if available)
                if project.hasGit {
                    Divider()
                    gitSection
                }

                // README preview (if available)
                if let preview = project.readmePreview {
                    Divider()
                    readmeSection(preview: preview)
                }

                Spacer()
            }
            .padding(24)
        }
        .navigationTitle(project.name)
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                // Open on GitHub (if available)
                if let githubURL = project.gitHubURL {
                    Link(destination: githubURL) {
                        Image(systemName: "link")
                    }
                    .help("Open on GitHub")
                }

                // Open in Finder
                Button {
                    NSWorkspace.shared.open(project.path)
                } label: {
                    Image(systemName: "folder")
                }
                .help("Open in Finder")

                // Open in Terminal
                Button {
                    openInTerminal(project.path)
                } label: {
                    Image(systemName: "terminal")
                }
                .help("Open in Terminal")

                // Open in VS Code
                Button {
                    openInVSCode(project.path)
                } label: {
                    Image(systemName: "curlybraces")
                }
                .help("Open in VS Code")
            }
        }
        .task(id: project.id) {
            // Small delay to let view settle before making network call
            try? await Task.sleep(for: .milliseconds(100))
            // Pass auth state as values, not as object reference
            store.checkGitHubStatus(
                for: project,
                isAuthenticated: gitHubAuth.isAuthenticated,
                token: gitHubAuth.token
            )
        }
    }

    // MARK: - Sections

    private var headerSection: some View {
        HStack(spacing: 16) {
            // Large type icon
            Image(systemName: project.typeIcon)
                .font(.system(size: 48))
                .foregroundStyle(project.typeColor)

            VStack(alignment: .leading, spacing: 4) {
                Text(project.name)
                    .font(.largeTitle)
                    .fontWeight(.bold)

                HStack(spacing: 8) {
                    // Type badge
                    Text(project.projectType.rawValue)
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(project.typeColor.opacity(0.2))
                        .foregroundStyle(project.typeColor)
                        .clipShape(Capsule())

                    if project.hasGit {
                        HStack(spacing: 4) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                            Text("Git")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    if project.hasReadme {
                        HStack(spacing: 4) {
                            Image(systemName: "doc.text.fill")
                                .foregroundStyle(.blue)
                            Text("README")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }

            Spacer()
        }
    }

    private var metadataSection: some View {
        LazyVGrid(columns: [
            GridItem(.flexible()),
            GridItem(.flexible())
        ], spacing: 16) {
            MetadataCard(
                icon: "calendar",
                title: "Created",
                value: project.creationDate.formatted(date: .abbreviated, time: .omitted)
            )

            MetadataCard(
                icon: "clock",
                title: "Modified",
                value: project.modificationDate.formatted(date: .abbreviated, time: .shortened)
            )

            MetadataCard(
                icon: "folder",
                title: "Path",
                value: project.path.path(percentEncoded: false)
            )

            MetadataCard(
                icon: project.typeIcon,
                title: "Type",
                value: project.projectType.rawValue
            )
        }
    }

    @ViewBuilder
    private var gitSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Git Repository", systemImage: "arrow.triangle.branch")
                .font(.headline)

            if let remoteURL = project.gitRemoteURL,
               let githubURL = project.gitHubURL,
               let repoName = project.gitHubRepoName {
                // GitHub repository card (consolidated)
                GitHubRepoCard(
                    repoName: repoName,
                    remoteURL: remoteURL,
                    githubURL: githubURL,
                    status: store.gitHubStatus(for: project)
                )
            } else if project.gitRemoteURL != nil {
                // Non-GitHub remote
                HStack {
                    Image(systemName: "server.rack")
                        .foregroundStyle(.secondary)
                    Text(project.gitRemoteURL ?? "")
                        .font(.system(.body, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                    Spacer()
                    Button {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(project.gitRemoteURL ?? "", forType: .string)
                    } label: {
                        Image(systemName: "doc.on.doc")
                    }
                    .buttonStyle(.plain)
                    .help("Copy URL")
                }
                .padding(12)
                .background(.quaternary.opacity(0.5))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            } else {
                // Local only
                HStack {
                    Image(systemName: "internaldrive")
                        .foregroundStyle(.secondary)
                    Text("Local repository (no remote configured)")
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                .padding(12)
                .background(.quaternary.opacity(0.5))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
    }

    private func readmeSection(preview: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("README Preview", systemImage: "doc.text")
                .font(.headline)

            Text(preview)
                .font(.body)
                .foregroundStyle(.secondary)
                .lineLimit(6)
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.quaternary.opacity(0.5))
                .clipShape(RoundedRectangle(cornerRadius: 8))

            Button("View Full README") {
                let readmePath = project.path.appendingPathComponent("README.md")
                NSWorkspace.shared.open(readmePath)
            }
            .buttonStyle(.link)
        }
    }

    // MARK: - Actions

    private func openInTerminal(_ url: URL) {
        let script = """
        tell application "Terminal"
            activate
            do script "cd '\(url.path)'"
        end tell
        """

        if let appleScript = NSAppleScript(source: script) {
            var error: NSDictionary?
            appleScript.executeAndReturnError(&error)
        }
    }

    private func openInVSCode(_ url: URL) {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        task.arguments = ["-a", "Visual Studio Code", url.path]
        try? task.run()
    }
}

// MARK: - Metadata Card

private struct MetadataCard: View {
    let icon: String
    let title: String
    let value: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(.secondary)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.tertiary)

                Text(value)
                    .font(.callout)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            Spacer()
        }
        .padding(12)
        .background(.quaternary.opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

// MARK: - GitHub Repo Card

private struct GitHubRepoCard: View {
    let repoName: String
    let remoteURL: String
    let githubURL: URL
    let status: GitHubRepoStatus

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Top row: repo name and status
            HStack {
                Image(systemName: "link")
                    .foregroundColor(.blue)

                Text(repoName)
                    .font(.headline)

                Spacer()

                // Status badge - simplified
                HStack(spacing: 4) {
                    if status == .checking {
                        ProgressView()
                            .scaleEffect(0.6)
                            .frame(width: 12, height: 12)
                    } else {
                        Image(systemName: status.icon)
                            .font(.caption)
                    }
                    Text(status.label)
                        .font(.caption)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.gray.opacity(0.2))
                .clipShape(Capsule())

                // Open link button
                Link(destination: githubURL) {
                    Image(systemName: "arrow.up.right.square")
                }
                .buttonStyle(.plain)
            }

            // URL row
            HStack {
                Text(remoteURL)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundColor(.secondary)
                    .lineLimit(1)

                Spacer()

                Button {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(remoteURL, forType: .string)
                } label: {
                    Image(systemName: "doc.on.doc")
                        .font(.caption)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(12)
        .background(Color.gray.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

// MARK: - Sign In Prompt Card

private struct SignInPromptCard: View {
    let onSignIn: () -> Void

    var body: some View {
        HStack {
            Image(systemName: "person.crop.circle.badge.questionmark")
                .font(.title2)
                .foregroundStyle(.blue)

            VStack(alignment: .leading, spacing: 2) {
                Text("Sign in for accurate status")
                    .font(.subheadline)
                    .fontWeight(.medium)
                Text("Connect your GitHub account to see repo status")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button("Sign In", action: onSignIn)
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
        }
        .padding(12)
        .background(.blue.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

#Preview {
    NavigationSplitView {
        Text("Sidebar")
    } detail: {
        DetailView()
            .environment(ProjectStore())
            .environment(GitHubAuth())
    }
}
