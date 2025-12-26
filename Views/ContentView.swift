import SwiftUI

/// Main content view with NavigationSplitView
struct ContentView: View {
    @Environment(ProjectStore.self) private var store
    @Environment(GitHubAuth.self) private var gitHubAuth
    @State private var showingSettings = false

    var body: some View {
        @Bindable var store = store

        NavigationSplitView {
            SidebarView()
        } detail: {
            DetailView()
        }
        .navigationSplitViewStyle(.balanced)
        .toolbar {
            // GitHub account status (leading)
            ToolbarItem(placement: .navigation) {
                GitHubAccountButton {
                    showingSettings = true
                }
            }

            ToolbarItemGroup(placement: .primaryAction) {
                // Refresh button
                Button {
                    Task { await store.refresh() }
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .disabled(store.isScanning || !store.hasRootFolder)
                .help("Refresh projects (Cmd+R)")
                .keyboardShortcut("r", modifiers: .command)

                // Folder picker button
                Button {
                    store.selectFolder()
                } label: {
                    Image(systemName: "folder.badge.plus")
                }
                .help("Select projects folder (Cmd+O)")
                .keyboardShortcut("o", modifiers: .command)

                // Settings button
                Button {
                    showingSettings = true
                } label: {
                    Image(systemName: "gearshape")
                }
                .help("Settings")
                .keyboardShortcut(",", modifiers: .command)
            }
        }
        .sheet(isPresented: $showingSettings) {
            SettingsView()
        }
        .onAppear {
            // Restore previous session after view is ready
            store.restoreIfNeeded()
            // Restore GitHub auth session (async, won't block)
            gitHubAuth.restoreSession()
        }
        .overlay {
            // Scanning overlay
            if store.isScanning {
                ScanningOverlay(progress: store.scanProgress)
            }
        }
        .alert("Error", isPresented: .constant(store.errorMessage != nil)) {
            Button("OK") { store.clearError() }
        } message: {
            Text(store.errorMessage ?? "")
        }
    }
}

// MARK: - Scanning Overlay

private struct ScanningOverlay: View {
    let progress: Double

    var body: some View {
        ZStack {
            Color.black.opacity(0.4)
                .ignoresSafeArea()

            VStack(spacing: 20) {
                // Animated icon
                Image(systemName: "folder.fill.badge.gearshape")
                    .font(.system(size: 48))
                    .foregroundStyle(.blue)
                    .symbolEffect(.pulse, options: .repeating)

                Text("Scanning Projects")
                    .font(.title2)
                    .fontWeight(.semibold)

                // Progress bar
                VStack(spacing: 8) {
                    ProgressView(value: progress)
                        .progressViewStyle(.linear)
                        .frame(width: 200)

                    Text("\(Int(progress * 100))%")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
            }
            .padding(40)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20))
            .shadow(radius: 20)
        }
    }
}

// MARK: - GitHub Account Button

private struct GitHubAccountButton: View {
    @Environment(GitHubAuth.self) private var auth
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if auth.isAuthenticated {
                    // Show avatar or user icon
                    AsyncImage(url: auth.avatarURL) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } placeholder: {
                        Image(systemName: "person.circle.fill")
                            .foregroundStyle(.green)
                    }
                    .frame(width: 20, height: 20)
                    .clipShape(Circle())

                    Text(auth.username ?? "GitHub")
                        .font(.caption)
                } else if auth.isAuthenticating {
                    ProgressView()
                        .scaleEffect(0.6)
                    Text("Signing in...")
                        .font(.caption)
                } else {
                    Image(systemName: "person.crop.circle.badge.questionmark")
                        .foregroundStyle(.secondary)
                    Text("Sign in")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .buttonStyle(.plain)
        .help(auth.isAuthenticated ? "GitHub: \(auth.username ?? "Connected")" : "Sign in to GitHub")
    }
}

#Preview {
    ContentView()
        .environment(ProjectStore())
        .environment(GitHubAuth())
        .frame(width: 1000, height: 600)
}
