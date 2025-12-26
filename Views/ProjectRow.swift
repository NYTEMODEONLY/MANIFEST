import SwiftUI

/// A single row in the project sidebar list
struct ProjectRow: View {
    let project: Project

    var body: some View {
        HStack(spacing: 12) {
            // Project type icon
            Image(systemName: project.typeIcon)
                .font(.title2)
                .foregroundStyle(project.typeColor)
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 4) {
                // Project name
                Text(project.name)
                    .font(.headline)
                    .lineLimit(1)

                // Metadata row
                HStack(spacing: 8) {
                    // Project type badge
                    Text(project.projectType.rawValue)
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    // Git indicator
                    if project.hasGit {
                        Image(systemName: "arrow.triangle.branch")
                            .font(.caption)
                            .foregroundStyle(.green)
                    }

                    // README indicator
                    if project.hasReadme {
                        Image(systemName: "doc.text")
                            .font(.caption)
                            .foregroundStyle(.blue)
                    }

                    Spacer()

                    // Last modified
                    Text(project.formattedModificationDate)
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
    }
}

#Preview {
    List {
        ProjectRow(project: Project(
            name: "awesome-project",
            path: URL(fileURLWithPath: "/test"),
            creationDate: Date(),
            modificationDate: Date().addingTimeInterval(-86400 * 3),
            projectType: .nodejs,
            gitRemoteURL: "https://github.com/user/repo",
            readmePreview: "This is an awesome project",
            hasGit: true,
            hasReadme: true
        ))

        ProjectRow(project: Project(
            name: "python-script",
            path: URL(fileURLWithPath: "/test2"),
            creationDate: Date(),
            modificationDate: Date().addingTimeInterval(-86400 * 30),
            projectType: .python,
            hasGit: false,
            hasReadme: false
        ))
    }
    .frame(width: 300)
}
