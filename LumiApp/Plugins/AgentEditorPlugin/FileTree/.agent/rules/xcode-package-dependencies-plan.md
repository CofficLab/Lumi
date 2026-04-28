# Xcode-Style Package Dependencies in File Tree

## Implementation Plan

> **Goal**: Replicate Xcode's exact experience of showing Swift Package Dependencies at the bottom of the file tree.

---

## Phase 0: Architecture Overview

### Directory Structure (Target)
```
FileTree/
├── Models/
│   ├── FileTreeNode.swift
│   ├── PackageDependency.swift          ← NEW
│   ├── PackageDependencyNode.swift      ← NEW
│   └── PackageResolvedV2.swift          ← NEW
├── Services/
│   ├── ProjectTreeFileService.swift
│   ├── PackageResolver.swift            ← NEW
│   ├── PackageStateMonitor.swift        ← NEW
│   └── SPMIntegrationService.swift      ← NEW
├── Store/
│   ├── AgentFileTreePluginLocalStore.swift
│   └── PackageDependencyStore.swift     ← NEW
├── Views/
│   ├── ProjectTreeView.swift
│   ├── FileNodeView.swift
│   ├── PackageDependencySection.swift   ← NEW
│   ├── PackageDependencyRow.swift       ← NEW
│   ├── PackageDependencyDetailView.swift← NEW
│   └── PackageDependencyContextMenu.swift← NEW
└── ProjectTreePlugin.swift
```

---

## Phase 1: Data Models

### 1.1 PackageResolvedV2.swift
**Purpose**: Parse `Package.resolved` JSON (v2 format).

```swift
struct PackageResolvedV2: Codable {
    let version: Int
    let dependencies: [DependencyEntry]
    
    struct DependencyEntry: Codable {
        let identity: String           // e.g., "alamofire"
        let kind: String               // "remoteSourceControl" | "localSourceControl" | "registry" | "fileSystem"
        let location: String           // URL or local path
        let state: DependencyState
    }
    
    struct DependencyState: Codable {
        let revision: String?          // Git commit hash
        let version: String?           // Semantic version
        let branch: String?            // Branch name (if using branch)
    }
}
```

### 1.2 PackageDependency.swift
**Purpose**: Runtime model for UI display.

```swift
struct PackageDependency: Identifiable, Hashable {
    let id = UUID()
    let identity: String               // Normalized package name
    let displayName: String            // Human-readable name
    let location: URL
    let version: String?               // e.g., "5.8.1"
    let revision: String?              // Short commit hash
    let kind: PackageKind
    var status: PackageStatus          // resolved, unresolved, error, updating
    var sourcePackagesPath: URL?       // Actual checkout path
    var hasUnresolvedChanges: Bool
    
    enum PackageKind {
        case remote(URL)
        case local(URL)
        case fileSystem(URL)
        case registry(String)
    }
    
    enum PackageStatus {
        case resolved
        case unresolved
        case updating
        case error(String)
        case needsUpdate(String)        // Available version
    }
}
```

### 1.3 PackageDependencyNode.swift
**Purpose**: Tree node for expanded package contents (like Xcode's expandable packages).

```swift
struct PackageDependencyNode: Identifiable {
    let id = UUID()
    let name: String
    let url: URL
    let isDirectory: Bool
    var isExpanded: Bool
    var children: [PackageDependencyNode]?
    let parentPackage: String          // Which package this belongs to
    let depth: Int
}
```

---

## Phase 2: Core Services

### 2.1 PackageResolver.swift
**Purpose**: Parse and resolve package dependencies from project files.

#### Methods:
- `resolve(from projectPath: String) async throws -> [PackageDependency]`
  - Primary entry point
  - Locates `Package.resolved` in project root or `.swiftpm/`
  - Parses v2 JSON format
  - Resolves actual checkout paths

- `findPackageResolved(in projectPath: String) -> URL?`
  - Search order:
    1. `{projectPath}/Package.resolved`
    2. `{projectPath}/.swiftpm/Package.resolved`
    3. DerivedData path (if available)

- `resolveCheckoutPath(for package: PackageDependency, projectPath: String) -> URL?`
  - Look in `{projectPath}/.build/checkouts/`
  - Look in `~/Library/Developer/Xcode/DerivedData/.../SourcePackages/checkouts/`
  - Map identity to directory name

- `loadPackageManifest(from projectPath: String) async -> [PackageDependency]?`
  - Fallback: parse `Package.swift` if `Package.resolved` not found
  - Extract dependencies from `.package(url:..., from:...)` declarations

### 2.2 PackageStateMonitor.swift
**Purpose**: Watch for package changes and update state.

#### Features:
- File system watcher on `Package.resolved`
- File system watcher on `.build/checkouts/`
- Debounced updates (avoid rapid-fire notifications)
- State machine for package resolution status

#### Methods:
- `startMonitoring(projectPath: String)`
- `stopMonitoring()`
- `onPackageChange: (([PackageDependency]) -> Void)?`
- `onPackageError: ((String) -> Void)?`

### 2.3 SPMIntegrationService.swift
**Purpose**: Interface with Swift Package Manager CLI.

#### Methods:
- `executeResolve(in projectPath: String) async throws`
  - Run `swift package resolve`
  - Parse output for status/errors

- `executeUpdate(in projectPath: String) async throws`
  - Run `swift package update`
  - Report which packages were updated

- `checkStatus(in projectPath: String) async -> PackageStatusReport`
  - Run `swift package describe` or parse output
  - Check for unresolved dependencies

- `executeDumpCommands(in projectPath: String) async throws -> String`
  - Run `swift package dump-package` for manifest inspection

---

## Phase 3: Store Layer

### 3.1 PackageDependencyStore.swift
**Purpose**: Manage package dependency state across the app.

```swift
@MainActor
final class PackageDependencyStore: ObservableObject {
    @Published var packages: [PackageDependency] = []
    @Published var isLoading: Bool = false
    @Published var error: String?
    @Published var expandedPackages: Set<String> = []
    
    // Package-level expansion state
    func toggleExpansion(for identity: String)
    func isExpanded(_ identity: String) -> Bool
    
    // Package content caching
    private var packageContentsCache: [String: [PackageDependencyNode]] = [:]
    func loadPackageContents(for identity: String) async
    func clearCache(for identity: String)
    
    // Persistence
    func saveExpandedState()
    func restoreExpandedState()
    
    // Integration with ProjectVM
    func refresh(for projectPath: String) async
}
```

---

## Phase 4: UI Implementation

### 4.1 PackageDependencySection.swift
**Purpose**: Container view that appears at the bottom of the file tree.

#### Layout Structure:
```
┌─────────────────────────────┐
│  File Tree Content          │
│  ...                        │
│                             │
├─────────────────────────────┤ ← Divider (Xcode-style)
│ ▸ Swift Package Dependencies│ ← Header with chevron
│   └▸ Alamofire 5.8.1       │   ← Package rows
│   └▸ SwiftNIO 2.62.0       │
│   ...                       │
└─────────────────────────────┘
```

#### Features:
- Collapsible section header (chevron + "Swift Package Dependencies" label)
- Divider line matching Xcode's exact style
- Scroll area for packages (independent of file tree scroll)
- State handling: loading, empty, error
- Persistence of expansion state

### 4.2 PackageDependencyRow.swift
**Purpose**: Individual package row, matching Xcode's visual design.

#### Visual Elements:
- **Icon**: SF Symbol based on package kind
  - Remote: `cube.box`
  - Local: `folder`
  - File System: `doc`
  - Registry: `shippingbox`
- **Name**: Display name (truncated if long)
- **Version**: Right-aligned, monospaced font, secondary color
- **Status Indicator**: Small dot or icon for update/error states
- **Expansion Chevron**: For expandable packages

#### Row Layout (Xcode-accurate):
```
[v] [icon] Package Name          v1.2.3 [status]
     16px    12px font            10px    8px
     padding left: 16 + depth*8
```

#### Interactions:
- Click: Toggle expansion or navigate to package
- Double-click: Open in Finder
- Right-click: Context menu
- Hover: Background highlight (matching file tree style)

### 4.3 PackageDependencyDetailView.swift
**Purpose**: Expanded view showing package contents.

#### Features:
- Tree view of package directory structure
- Uses same `FileNodeView` styling for consistency
- Shows only relevant directories (Sources, Tests, etc.)
- Filters out build artifacts and hidden files
- Lazy loading of children (on-expand)

### 4.4 PackageDependencyContextMenu.swift
**Purpose**: Right-click menu for packages.

#### Menu Items:
- **Reveal in Finder** - Open package directory
- **Open in Editor** - Open main source file
- **Update Package** - Run `swift package update` for this package
- **Copy Package URL** - Copy remote URL to clipboard
- **Show Package Details** - Show metadata
- **Remove Package** - (If supported by project)

---

## Phase 5: Integration

### 5.1 ProjectTreeView Modification
**Changes to existing `ProjectTreeView`**:

```swift
var body: some View {
    VStack(spacing: 0) {
        if projectVM.currentProjectPath.isEmpty {
            FileTreeNoProjectView()
        } else {
            ScrollView {
                // Existing file tree
                FileNodeView(...)
            }
            
            // NEW: Package Dependencies Section
            PackageDependencySection(projectPath: projectVM.currentProjectPath)
                .frame(height: calculatePackageSectionHeight())
        }
    }
    // ... existing modifiers
}
```

### 5.2 Scroll Management
- File tree and package section share a single `ScrollView`
- Package section is always at bottom
- Section height is dynamic based on expansion state
- Smooth scrolling between file tree and packages

### 5.3 State Synchronization
- Package resolution triggered when:
  - Project path changes
  - `Package.resolved` file changes
  - Manual refresh requested
- Store updates flow to UI via `@Published`
- Expansion state persists across app launches

---

## Phase 6: Polish & Xcode-Exact Details

### 6.1 Visual Fidelity
- **Divider**: 1px line, matching Xcode's sidebar divider color
- **Header Font**: Same as file tree headers, system font at 11px
- **Row Height**: 22px (matching Xcode's row height)
- **Icon Size**: 16x16 SF Symbols
- **Colors**: Match Xcode's dark/light theme exactly
  - Text: `secondary` color system
  - Background: `systemFill` / `tertiarySystemFill`
  - Selection: `selectedContentBackgroundColor`

### 6.2 Animation
- Package expansion: Smooth 0.2s ease-out
- Section height change: Animated with spring
- Loading state: Subtle progress indicator
- Error state: Shake animation for attention

### 6.3 Accessibility
- VoiceOver labels for all interactive elements
- Keyboard navigation (arrow keys, space, return)
- Focus indicators matching system style
- Dynamic type support

---

## Phase 7: Edge Cases & Error Handling

### 7.1 No SPM Project
- Hide entire section if no `Package.swift` or `Package.resolved`
- No visual disruption to file tree

### 7.2 Unresolved Dependencies
- Show placeholder with "Resolve Packages" button
- Execute `swift package resolve` on button tap
- Show progress during resolution

### 7.3 Corrupted Package.resolved
- Show error message with "Reset" option
- Allow manual re-resolution
- Log error for debugging

### 7.4 Large Package Sets
- Virtualization for 50+ packages
- Lazy loading of expanded contents
- Performance monitoring and optimization

### 7.5 Multiple Package.resolved Locations
- Priority order documented in `PackageResolver`
- User notification if conflicting files found
- Option to choose which file to use

---

## Implementation Order

1. **Week 1**: Models + Basic Parser
   - `PackageResolvedV2.swift`
   - `PackageDependency.swift`
   - `PackageResolver.swift` (basic parsing)

2. **Week 2**: UI Foundation
   - `PackageDependencySection.swift`
   - `PackageDependencyRow.swift`
   - Integration into `ProjectTreeView`

3. **Week 3**: State & Monitoring
   - `PackageDependencyStore.swift`
   - `PackageStateMonitor.swift`
   - File system watching

4. **Week 4**: Interactions
   - Context menus
   - Package expansion
   - Detail views

5. **Week 5**: SPM Integration
   - `SPMIntegrationService.swift`
   - Update/resolve commands
   - Status reporting

6. **Week 6**: Polish
   - Visual fidelity
   - Animations
   - Edge cases
   - Testing

---

## Testing Strategy

### Unit Tests
- `PackageResolvedV2` parsing with various JSON formats
- `PackageResolver` path resolution logic
- `PackageDependency` model validation

### Integration Tests
- File system watcher accuracy
- Store state persistence
- SPM command execution

### UI Tests
- Row rendering with various states
- Expansion/collapse animations
- Context menu actions
- Scroll behavior

### Manual Testing
- Compare side-by-side with Xcode
- Test with real projects (various sizes)
- Test edge cases (no packages, many packages, errors)

---

## Dependencies & Requirements

### System Requirements
- macOS 13.0+ (existing requirement)
- Swift 5.9+ (existing requirement)
- Access to `swift` CLI (must be in PATH)

### External Dependencies
- None (all parsing is custom)
- Uses standard `Foundation` JSON decoding
- File system watching via `DispatchSource`

### Permissions
- File read access to project directory
- File read access to DerivedData (optional)
- Execution of `swift` CLI commands

---

## Risks & Mitigations

| Risk | Impact | Mitigation |
|------|--------|------------|
| `swift` CLI not available | High | Graceful degradation, show error |
| Package.resolved format changes | Medium | Version detection, fallback parsing |
| Large projects performance | Medium | Virtualization, lazy loading |
| DerivedData path complexity | Low | Multiple fallback strategies |
| SPM command timeouts | Low | Timeout handling, progress feedback |

---

## Success Criteria

- [ ] Packages appear at bottom of file tree
- [ ] Visual match with Xcode (pixel-level comparison)
- [ ] Click to expand shows package contents
- [ ] Context menu provides expected actions
- [ ] File changes trigger automatic refresh
- [ ] Manual resolve/update works correctly
- [ ] Error states handled gracefully
- [ ] Performance acceptable with 100+ packages
- [ ] Works with all Swift package kinds
- [ ] Expansion state persists across launches

---

## Future Enhancements (Post-MVP)

- Package version comparison and update prompts
- Dependency graph visualization
- Package size analysis
- Security vulnerability scanning integration
- Custom package registry support
- Package editing capabilities
- Diff viewer for package updates
