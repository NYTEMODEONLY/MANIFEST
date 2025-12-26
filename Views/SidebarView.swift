import SwiftUI

/// The sidebar containing the searchable project list
struct SidebarView: View {
    @Environment(ProjectStore.self) private var store

    var body: some View {
        Group {
            if store.hasProjects {
                ProjectListView()
            } else if store.hasRootFolder {
                EmptyStateView(
                    icon: "folder.badge.questionmark",
                    title: "No Projects Found",
                    message: "The selected folder doesn't contain any project subfolders."
                )
            } else {
                EmptyStateView(
                    icon: "folder.badge.plus",
                    title: "Select a Folder",
                    message: "Choose a folder containing your projects to get started."
                ) {
                    Button("Select Folder") {
                        store.selectFolder()
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
        }
        .navigationTitle("Projects")
    }
}

/// Separate view for the project list to isolate @Bindable usage
private struct ProjectListView: View {
    @Environment(ProjectStore.self) private var store

    var body: some View {
        @Bindable var store = store

        List(selection: $store.selectedProject) {
            // Stats header
            Section {
                HStack(spacing: 16) {
                    StatBadge(
                        icon: "folder.fill",
                        value: store.projectCount,
                        label: "Projects"
                    )
                    StatBadge(
                        icon: "arrow.triangle.branch",
                        value: store.gitProjectCount,
                        label: "Git"
                    )
                    StatBadge(
                        icon: "doc.text.fill",
                        value: store.readmeProjectCount,
                        label: "Docs"
                    )
                }
                .padding(.vertical, 4)
            }

            // Sort picker
            Section {
                Picker("Sort by", selection: $store.sortOption) {
                    ForEach(SortOption.allCases) { option in
                        Label(option.rawValue, systemImage: option.icon)
                            .tag(option)
                    }
                }
                .pickerStyle(.menu)
                .labelsHidden()
            }

            // Project list
            Section {
                ForEach(store.displayedProjects) { project in
                    ProjectRow(project: project)
                        .tag(project)
                }
            }
        }
        .listStyle(.sidebar)
        .searchable(text: $store.searchText, prompt: "Search projects")
    }
}

/// A small stat badge for the sidebar header
private struct StatBadge: View {
    let icon: String
    let value: Int
    let label: String

    var body: some View {
        VStack(spacing: 2) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.caption)
                Text("\(value)")
                    .font(.headline)
            }
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

#Preview {
    NavigationSplitView {
        SidebarView()
            .environment(ProjectStore())
    } detail: {
        Text("Detail")
    }
}
