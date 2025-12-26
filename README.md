# MANIFEST

A native macOS app for browsing and managing your project folders. Built with SwiftUI for macOS 14+.

![macOS](https://img.shields.io/badge/macOS-14.0+-blue)
![Swift](https://img.shields.io/badge/Swift-5.9+-orange)
![SwiftUI](https://img.shields.io/badge/SwiftUI-Native-green)

## Features

- **Project Discovery**: Automatically scans and catalogs project folders
- **Smart Type Detection**: Identifies project types (Node.js, Python, Swift, Rust, Go, Flutter, Ruby, Java, .NET)
- **Git Integration**: Detects Git repositories and displays remote URLs
- **README Preview**: Shows first 300 characters of README.md files
- **Quick Actions**: Open projects in Finder, Terminal, or VS Code
- **Search & Sort**: Filter projects by name, sort by date or type
- **Dark Mode**: Native dark mode support (default)
- **GitHub OAuth**: Sign in with GitHub using Device Flow authentication

## Screenshots

The app features a clean split-view interface:
- **Sidebar**: Searchable project list with type icons and metadata
- **Detail View**: Full project information including Git details and README preview

## Requirements

- macOS 14.0 (Sonoma) or later
- Xcode 15+ (for building from source)

## Installation

### From Source

1. Clone the repository:
   ```bash
   git clone https://github.com/NYTEMODEONLY/MANIFEST.git
   ```

2. Open in Xcode:
   ```bash
   cd MANIFEST
   open MANIFEST.xcodeproj
   ```

3. Build and run (Cmd+R)

### First Launch

1. Click "Select Folder" or use Cmd+O
2. Choose your projects directory (e.g., `~/Projects` or `~/Developer`)
3. The app will scan and display all project subfolders

## Project Structure

```
MANIFEST/
├── MANIFESTApp.swift           # App entry point
├── MANIFEST.entitlements       # Sandbox permissions
│
├── Models/
│   ├── Project.swift           # Project data model
│   └── ProjectType.swift       # Project type enum with icons/colors
│
├── Services/
│   ├── ProjectStore.swift      # Main state management (@Observable)
│   ├── ProjectScanner.swift    # Async folder scanning
│   ├── GitHelper.swift         # Git config parsing
│   ├── TypeDetector.swift      # Project type detection
│   ├── ReadmeExtractor.swift   # README.md preview extraction
│   ├── BookmarkManager.swift   # Security-scoped bookmark persistence
│   ├── GitHubAuth.swift        # GitHub OAuth Device Flow
│   └── GitHubChecker.swift     # GitHub API status checking
│
└── Views/
    ├── ContentView.swift       # Main NavigationSplitView
    ├── SidebarView.swift       # Project list sidebar
    ├── ProjectRow.swift        # Individual project row
    ├── DetailView.swift        # Project detail pane
    ├── SettingsView.swift      # Settings sheet
    └── EmptyStateView.swift    # Placeholder views
```

## Type Detection

Projects are identified by their configuration files:

| Type | Detection Files |
|------|-----------------|
| Swift | `Package.swift` |
| Node.js | `package.json` |
| Rust | `Cargo.toml` |
| Go | `go.mod` |
| Flutter | `pubspec.yaml` |
| Python | `pyproject.toml`, `requirements.txt`, `setup.py` |
| Ruby | `Gemfile` |
| Java | `pom.xml`, `build.gradle` |
| .NET | `*.csproj`, `*.sln` |

## Keyboard Shortcuts

| Action | Shortcut |
|--------|----------|
| Open Folder | Cmd+O |
| Refresh Projects | Cmd+R |
| Settings | Cmd+, |
| Search | Cmd+F (in sidebar) |

## Technical Notes

### SwiftUI @Observable Architecture

This app uses Swift's modern `@Observable` macro (iOS 17+/macOS 14+) for state management. Key architectural decisions:

1. **Environment Objects**: `ProjectStore` and `GitHubAuth` are injected via `.environment()`
2. **Observation Isolation**: Views only observe what they need to prevent cascade re-renders
3. **Toolbar Caution**: Computed properties in toolbars can cause performance issues - use cached values instead

### Sandbox & Bookmarks

The app runs in the macOS sandbox with:
- `com.apple.security.files.user-selected.read-only` - Access user-selected folders
- `com.apple.security.files.bookmarks.app-scope` - Persist folder access across launches

### GitHub OAuth

Uses GitHub's Device Flow for authentication:
1. App requests device code from GitHub
2. User enters code at github.com/login/device
3. App polls for access token
4. Token stored securely in Keychain

## Known Limitations

- GitHub status checking is currently disabled (pending optimization)
- Only scans immediate subdirectories (not recursive)
- Large folders (500+ projects) may have slower initial scan

## Contributing

Contributions welcome! Please open an issue first to discuss proposed changes.

## License

MIT License - See LICENSE file for details.

---

Built with SwiftUI for macOS by NYTEMODEONLY
