import SwiftUI

/// A reusable empty state view with icon, title, message, and optional actions
struct EmptyStateView<Actions: View>: View {
    let icon: String
    let title: String
    let message: String
    let actions: Actions

    init(
        icon: String,
        title: String,
        message: String,
        @ViewBuilder actions: () -> Actions = { EmptyView() }
    ) {
        self.icon = icon
        self.title = title
        self.message = message
        self.actions = actions()
    }

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 48))
                .foregroundStyle(.secondary)

            Text(title)
                .font(.title2)
                .fontWeight(.semibold)

            Text(message)
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 300)

            actions
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview {
    EmptyStateView(
        icon: "folder.badge.plus",
        title: "Select a Folder",
        message: "Choose a folder containing your projects to get started."
    ) {
        Button("Select Folder") {}
            .buttonStyle(.borderedProminent)
    }
}
