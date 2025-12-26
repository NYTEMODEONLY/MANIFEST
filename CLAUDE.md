# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build Commands

```bash
# Build from command line
xcodebuild -scheme MANIFEST -destination 'platform=macOS' build

# Run tests
xcodebuild -scheme MANIFEST -destination 'platform=macOS' test

# Or open in Xcode and use Cmd+B (build) / Cmd+R (run) / Cmd+U (test)
open MANIFEST.xcodeproj
```

## Architecture

This is a native macOS SwiftUI app (macOS 14+) using the modern `@Observable` macro for state management.

### State Management Pattern

Two `@Observable` classes are injected as environment objects at the app root (`MANIFESTApp.swift`):
- **ProjectStore**: Main app state - projects list, scanning status, search/sort, folder bookmarks
- **GitHubAuth**: GitHub OAuth state - authentication, token management, keychain storage

Views access these via `@Environment(ProjectStore.self)` or `@Environment(GitHubAuth.self)`.

### Critical Performance Rules

**NEVER do these in SwiftUI with @Observable:**

1. **No computed properties in toolbars** - Toolbars re-evaluate frequently. Calling computed properties (like `project.gitHubURL`) causes repeated string parsing and high CPU. Use pre-cached values instead.

2. **No @Observable-observing views in toolbars** - Views with `@Environment(SomeObservable.self)` in toolbar items cause parent view invalidation cascades.

3. **Remove unused @Environment declarations** - Even if a view declares `@Environment(GitHubAuth.self)` but never accesses it in the body, it can cause observation issues. Only declare what you use.

4. **Avoid @Bindable when not needed** - Only use `@Bindable var store = store` when you actually need `$store` bindings. Read-only access doesn't need it.

5. **Keychain operations off main actor** - Use `Task.detached` with a separate helper (like `KeychainHelper` enum) to avoid actor isolation issues with @Observable.

### Services Layer

All services in `/Services` use Swift actors for thread safety:
- **ProjectScanner**: Async folder scanning with progress callback
- **GitHelper**: Parses `.git/config` for remote URLs
- **TypeDetector**: Identifies project type from config files
- **BookmarkManager**: Security-scoped bookmark persistence for sandbox
- **GitHubAuth**: OAuth Device Flow (keychain ops via non-actor `KeychainHelper`)

### Data Flow

1. User selects folder → `ProjectStore.selectFolder()` → saves security-scoped bookmark
2. `ProjectScanner` async scans subdirectories → creates `[Project]` array
3. Views observe `ProjectStore.displayedProjects` (filtered/sorted computed property)
4. Selection stored in `ProjectStore.selectedProject` → `DetailView` shows details

### Known Disabled Features

GitHub status checking (`checkGitHubStatus`) is disabled - the `DispatchQueue.main.async` pattern conflicts with @Observable. Status shows as "Unchecked". To re-enable, refactor to use pre-fetched cached values instead of on-demand dictionary access during render.
