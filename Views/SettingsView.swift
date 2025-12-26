import SwiftUI

/// Settings view with GitHub authentication
struct SettingsView: View {
    @Environment(ProjectStore.self) private var store
    @Environment(GitHubAuth.self) private var gitHubAuth
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Settings")
                    .font(.title2)
                    .fontWeight(.semibold)
                Spacer()
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding()

            Divider()

            // Content
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // GitHub Section
                    gitHubSection
                }
                .padding()
            }
        }
        .frame(width: 450, height: 400)
    }

    @ViewBuilder
    private var gitHubSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label("GitHub Account", systemImage: "link")
                .font(.headline)

            if gitHubAuth.isAuthenticated {
                // Signed in state
                signedInView
            } else if gitHubAuth.isAuthenticating {
                // Authenticating state (show device code)
                authenticatingView
            } else {
                // Signed out state
                signedOutView
            }

            // Error message
            if let error = gitHubAuth.errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.quaternary.opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    @ViewBuilder
    private var signedInView: some View {
        HStack(spacing: 12) {
            // Avatar
            AsyncImage(url: gitHubAuth.avatarURL) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } placeholder: {
                Image(systemName: "person.circle.fill")
                    .font(.system(size: 40))
                    .foregroundStyle(.secondary)
            }
            .frame(width: 48, height: 48)
            .clipShape(Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text(gitHubAuth.username ?? "GitHub User")
                    .font(.headline)
                Text("Connected")
                    .font(.caption)
                    .foregroundStyle(.green)
            }

            Spacer()

            Button("Sign Out") {
                gitHubAuth.signOut()
                store.clearGitHubStatusCache()
            }
            .buttonStyle(.bordered)
        }

        Text("Your GitHub repos will show accurate public/private status.")
            .font(.caption)
            .foregroundStyle(.secondary)
    }

    @ViewBuilder
    private var authenticatingView: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                ProgressView()
                    .scaleEffect(0.8)
                Text("Waiting for authorization...")
                    .foregroundStyle(.secondary)
            }

            if let code = gitHubAuth.userCode {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Enter this code on GitHub:")
                        .font(.subheadline)

                    // Code display
                    HStack {
                        Text(code)
                            .font(.system(size: 28, weight: .bold, design: .monospaced))
                            .kerning(4)

                        Button {
                            NSPasteboard.general.clearContents()
                            NSPasteboard.general.setString(code, forType: .string)
                        } label: {
                            Image(systemName: "doc.on.doc")
                        }
                        .buttonStyle(.plain)
                        .help("Copy code")
                    }
                    .padding()
                    .background(.blue.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 8))

                    // Link to GitHub
                    if let urlString = gitHubAuth.verificationURL,
                       let url = URL(string: urlString) {
                        Link(destination: url) {
                            HStack {
                                Image(systemName: "arrow.up.right.square")
                                Text("Open github.com/login/device")
                            }
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
            }

            Button("Cancel") {
                gitHubAuth.cancelAuthentication()
            }
            .buttonStyle(.bordered)
        }
    }

    @ViewBuilder
    private var signedOutView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Sign in to GitHub to see accurate repo status (public/private) and sync information.")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Button {
                Task {
                    await gitHubAuth.startAuthentication()
                }
            } label: {
                HStack {
                    Image(systemName: "link.badge.plus")
                    Text("Sign in with GitHub")
                }
            }
            .buttonStyle(.borderedProminent)
        }

        // Setup instructions
        VStack(alignment: .leading, spacing: 8) {
            Text("First-time setup:")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)

            Text("1. Create a GitHub OAuth App at github.com/settings/developers")
                .font(.caption)
                .foregroundStyle(.secondary)

            Text("2. Enable 'Device Flow' in the app settings")
                .font(.caption)
                .foregroundStyle(.secondary)

            Text("3. Copy the Client ID to GitHubAuth.swift")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
        .background(.orange.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

#Preview {
    SettingsView()
        .environment(ProjectStore())
        .environment(GitHubAuth())
}
