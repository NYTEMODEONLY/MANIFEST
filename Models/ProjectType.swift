import Foundation
import SwiftUI

/// Detected project types based on configuration files
enum ProjectType: String, CaseIterable, Sendable, Identifiable {
    case nodejs = "Node.js"
    case python = "Python"
    case swift = "Swift"
    case rust = "Rust"
    case go = "Go"
    case flutter = "Flutter"
    case ruby = "Ruby"
    case java = "Java"
    case dotnet = ".NET"
    case unknown = "Unknown"

    var id: String { rawValue }

    /// SF Symbol icon for this project type
    var iconName: String {
        switch self {
        case .nodejs: return "shippingbox.fill"
        case .python: return "chevron.left.forwardslash.chevron.right"
        case .swift: return "swift"
        case .rust: return "gearshape.2.fill"
        case .go: return "arrow.right.circle.fill"
        case .flutter: return "app.dashed"
        case .ruby: return "diamond.fill"
        case .java: return "cup.and.saucer.fill"
        case .dotnet: return "square.stack.3d.up.fill"
        case .unknown: return "folder.fill"
        }
    }

    /// Color associated with this project type
    var color: Color {
        switch self {
        case .nodejs: return .green
        case .python: return .blue
        case .swift: return .orange
        case .rust: return .red
        case .go: return .cyan
        case .flutter: return .teal
        case .ruby: return .pink
        case .java: return .brown
        case .dotnet: return .purple
        case .unknown: return .gray
        }
    }
}
