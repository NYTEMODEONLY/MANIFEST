import SwiftUI

@main
struct MANIFESTApp: App {
    @State private var projectStore = ProjectStore()
    @State private var gitHubAuth = GitHubAuth()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(projectStore)
                .environment(gitHubAuth)
                .preferredColorScheme(.dark) // Default to dark mode ("Nyte Mode")
        }
        .windowStyle(.automatic)
        .defaultSize(width: 1200, height: 800)
        .commands {
            // Replace New menu item with Open Folder
            CommandGroup(replacing: .newItem) {
                Button("Open Folder...") {
                    projectStore.selectFolder()
                }
                .keyboardShortcut("o", modifiers: .command)
            }

            // Add Refresh command
            CommandGroup(after: .toolbar) {
                Button("Refresh Projects") {
                    Task { await projectStore.refresh() }
                }
                .keyboardShortcut("r", modifiers: .command)
                .disabled(!projectStore.hasRootFolder)
            }
        }
    }
}
