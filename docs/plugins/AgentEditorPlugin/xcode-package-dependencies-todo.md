# Xcode Package Dependencies TODO

## Goal

在 `EditorRailFileTreePlugin` 的文件树底部显示类似 Xcode 的 Swift Package Dependencies 列表。

MVP 目标是先准确显示当前 Xcode 工程的直接 Swift Package 依赖，并能展示版本 / branch / revision。后续再做 checkout 内容展开、resolve/update 命令和更多交互。

## Current Code Targets

- File tree plugin: `LumiApp/Plugins/EditorRailFileTreePlugin/`
- Main view: `Views/EditorFileTreeView.swift`
- Node view: `Views/EditorFileTreeNodeView.swift`
- Store: `Services/EditorFileTreeStore.swift`
- Refresh coordinator: `Services/EditorFileTreeRefreshCoordinator.swift`
- Watcher: `Services/EditorFileTreeWatcher.swift`

## Key Technical Decisions

- For `.xcodeproj`, use `project.pbxproj` package references as the source of direct dependencies.
- Use `Package.resolved` only to enrich direct dependencies with resolved version, branch, and revision.
- Support both Xcode resolved format and SwiftPM resolved format.
- For Xcode projects, package resolve/update commands must use `xcodebuild -resolvePackageDependencies`, not `swift package resolve`.
- For pure SwiftPM projects, use `Package.swift` / `Package.resolved` and `swift package` commands.
- MVP should append the package section inside the existing `EditorFileTreeView` `ScrollView`.

## Phase 1: MVP Data Model And Parser

- [ ] Add `EditorPackageDependency.swift`
  - [ ] Fields: `identity`, `displayName`, `location`, `kind`, `version`, `branch`, `revision`, `requirement`, `checkoutURL`, `status`
  - [ ] Support remote and local package kinds first
  - [ ] Make identity stable and deterministic, not UUID-based

- [ ] Add `EditorPackageResolved.swift`
  - [ ] Decode Xcode v1 format: `object.pins[].package`, `repositoryURL`, `state`
  - [ ] Decode SwiftPM v2 format: `pins[].identity`, `kind`, `location`, `state`
  - [ ] Normalize repository URLs for matching
  - [ ] Unit test both formats with fixtures

- [ ] Add `EditorXcodePackageReferenceParser.swift`
  - [ ] Parse `XCRemoteSwiftPackageReference` entries from `project.pbxproj`
  - [ ] Parse `XCLocalSwiftPackageReference` entries from `project.pbxproj`
  - [ ] Extract display name from comments where available
  - [ ] Extract `repositoryURL`, `relativePath`, and `requirement`
  - [ ] Preserve the direct dependency ordering from `packageReferences`
  - [ ] Unit test with a trimmed `project.pbxproj` fixture

- [ ] Add `EditorPackageDependencyResolver.swift`
  - [ ] Detect project type: `.xcodeproj`, `.xcworkspace`, pure SwiftPM, or plain folder
  - [ ] For `.xcodeproj`, locate `project.pbxproj`
  - [ ] For `.xcodeproj`, locate resolved file at `project.xcworkspace/xcshareddata/swiftpm/Package.resolved`
  - [ ] Fallback resolved search paths:
    - [ ] `{root}/Package.resolved`
    - [ ] `{root}/.swiftpm/Package.resolved`
    - [ ] `{root}/Package.swift` parent package paths
  - [ ] Merge direct references with resolved pins
  - [ ] Do not show transitive resolved pins in MVP
  - [ ] Resolve local package URLs relative to project root
  - [ ] Resolve remote checkout URLs from `.build/checkouts` and `DerivedData/SourcePackages/checkouts` where feasible

## Phase 2: Store And Refresh

- [ ] Add `EditorPackageDependencyStore.swift`
  - [ ] `@Published var packages`
  - [ ] `@Published var isLoading`
  - [ ] `@Published var error`
  - [ ] `@Published var isSectionExpanded`
  - [ ] `func refresh(projectRootPath:) async`
  - [ ] Cancel in-flight refresh when project changes

- [ ] Extend `EditorFileTreeStore.swift`
  - [ ] Persist package section expanded/collapsed state per project
  - [ ] Persist expanded package identities for later phases

- [ ] Refresh triggers
  - [ ] Refresh packages on project path change
  - [ ] Refresh packages on view appear
  - [ ] Refresh packages when `project.pbxproj` changes
  - [ ] Refresh packages when `Package.resolved` changes
  - [ ] Reuse existing watcher/coordinator if practical; otherwise keep package watcher small and isolated

## Phase 3: MVP UI

- [ ] Add `EditorPackageDependencySection.swift`
  - [ ] Header row: chevron + package icon + `Swift Package Dependencies`
  - [ ] Show loading state
  - [ ] Show compact error state
  - [ ] Hide section when no package references exist
  - [ ] Append section at the bottom of the existing `EditorFileTreeView` `ScrollView`

- [ ] Add `EditorPackageDependencyRow.swift`
  - [ ] Match existing file tree row height and typography
  - [ ] Use current theme colors from `ThemeVM`
  - [ ] Remote icon: `cube.box`
  - [ ] Local icon: `folder`
  - [ ] Show package display name
  - [ ] Show version, branch, or short revision as trailing secondary text
  - [ ] Add hover background matching `EditorFileTreeNodeView`
  - [ ] Single click opens local package path or checkout path when available

- [ ] Integrate into `EditorFileTreeView.swift`
  - [ ] Add `@StateObject` package store
  - [ ] Pass `projectVM.currentProjectPath`
  - [ ] Trigger package refresh alongside file tree refresh
  - [ ] Keep package UI inside the same scroll flow as file tree content

## Phase 4: Basic Interactions

- [ ] Add package row context menu
  - [ ] Reveal in Finder
  - [ ] Copy package URL/path
  - [ ] Open in Terminal when path is available
  - [ ] Add to Conversation when path is available

- [ ] Add error affordances
  - [ ] Retry refresh
  - [ ] Copy diagnostic text

## Phase 5: Expand Package Contents

- [ ] Add `EditorPackageDependencyNode.swift`
  - [ ] Model directory/file entries under a package checkout or local package path
  - [ ] Stable IDs based on URL path

- [ ] Add package content loading
  - [ ] Lazy-load package children on expand
  - [ ] Filter hidden files and build artifacts
  - [ ] Prefer showing `Package.swift`, `Sources`, `Tests`, `README*`, `LICENSE*`
  - [ ] Cache package contents per package identity

- [ ] Add expandable package rows
  - [ ] Expand/collapse package contents
  - [ ] Persist expanded package identities
  - [ ] Reuse visual style from `EditorFileTreeNodeView`

## Phase 6: Resolve And Update Commands

- [ ] Add `EditorPackageCommandService.swift`
  - [ ] For `.xcodeproj`: run `/usr/bin/xcodebuild -resolvePackageDependencies -project <project>`
  - [ ] For `.xcworkspace`: run `/usr/bin/xcodebuild -resolvePackageDependencies -workspace <workspace>`
  - [ ] For pure SwiftPM: run `swift package resolve`
  - [ ] Add timeout and cancellation
  - [ ] Capture stdout/stderr for diagnostics

- [ ] Add UI actions
  - [ ] Resolve Packages
  - [ ] Update Packages, only after confirming scope
  - [ ] Disable commands while one is already running
  - [ ] Refresh dependencies after command completion

## Phase 7: Tests

- [ ] Parser tests
  - [ ] Xcode v1 `Package.resolved`
  - [ ] SwiftPM v2 `Package.resolved`
  - [ ] Remote package references in `project.pbxproj`
  - [ ] Local package references in `project.pbxproj`
  - [ ] Direct references merged with resolved pins

- [ ] Resolver tests
  - [ ] `.xcodeproj` resolved path discovery
  - [ ] Local package path resolution
  - [ ] Remote checkout path lookup
  - [ ] No transitive pins shown in MVP

- [ ] UI verification
  - [ ] No package project hides section
  - [ ] Loading state renders
  - [ ] Error state renders
  - [ ] Long package names truncate cleanly
  - [ ] Light and dark theme rows remain readable

## Phase 8: Later Enhancements

- [ ] Version update checking
- [ ] Dependency graph view
- [ ] Package size analysis
- [ ] Registry package support
- [ ] Package editing support
- [ ] Per-package update action
- [ ] Security advisory integration

## Initial Acceptance Criteria

- [ ] Opening this repo shows direct package dependencies from `Lumi.xcodeproj/project.pbxproj`
- [ ] Remote packages show resolved version, branch, or short revision from `Package.resolved`
- [ ] Local packages under `Packages/` appear as local dependencies
- [ ] Transitive packages from `Package.resolved` do not appear in the MVP list unless also directly referenced
- [ ] The package section appears at the bottom of the file tree and matches the existing file tree visual style
- [ ] Package parsing failures do not break the normal file tree
