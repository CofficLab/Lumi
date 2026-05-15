# File Tree Icon Theme TODO

Goal: let a Lumi theme plugin configure file tree icons by following one theme contribution contract. Plugin authors should not need to understand or register a separate "color theme" vs "file icon theme"; a single `LumiThemeContribution` should carry app colors, editor syntax colors, and file tree icon rules.

## Current State

- `LumiThemeContribution` only carries `appTheme`, `editorThemeId`, and `editorThemeContributor`.
- `ThemeVM.activeAppTheme` drives file tree colors, but not file tree icons.
- `EditorFileTreeNodeView` caches `fileIconName` during init using `EditorFileTreeService.getFileIcon(fileExtension:)`.
- `EditorFileTreeService.getFileIcon(fileExtension:)` hard-codes extension-to-SF-Symbol mappings.
- File tree rendering currently assumes `Image(systemName:)`, so it cannot represent bundled symbol assets or image assets from a theme plugin.

## Design Requirements

- [x] A theme plugin implements one theme contribution path only: `addThemeContributions() -> [LumiThemeContribution]`.
- [x] Theme plugins should not expose a separate plugin-level file icon registration API.
- [x] `LumiThemeContribution` should accept an optional file tree icon contributor beside `appTheme` and `editorThemeContributor`.
- [x] If a theme does not provide file icon rules, Lumi must fall back to the current built-in icon behavior.
- [x] The file tree icon resolver must support at least:
  - exact file names, such as `.gitignore`, `Package.swift`, `package.json`
  - exact folder names, such as `.github`, `Sources`, `Tests`
  - file extensions, such as `swift`, `json`, `md`
  - directory open/closed state
  - default file icon
  - default folder icon
- [x] The API should support SF Symbols first and allow bundled image/symbol assets later.
- [x] Icon lookup must not add file-system I/O during SwiftUI body evaluation.
- [x] Theme switching should update file tree icons without requiring app restart.

## Proposed API

- [x] Add a file tree icon model in core theme code, for example `LumiApp/Core/Theme/LumiFileIconTheme.swift`.

```swift
struct LumiFileIconContext: Equatable {
    let url: URL
    let fileName: String
    let fileExtension: String
    let isDirectory: Bool
    let isExpanded: Bool
    let projectRootPath: String
}

enum LumiFileIcon: Equatable {
    case systemImage(String)
    case assetImage(name: String, bundle: Bundle?)
}

@MainActor
protocol LumiFileIconThemeContributor: AnyObject {
    var id: String { get }
    var displayName: String { get }

    func icon(for context: LumiFileIconContext) -> LumiFileIcon?
    func defaultFileIcon() -> LumiFileIcon
    func defaultFolderIcon(isExpanded: Bool) -> LumiFileIcon
}
```

- [x] Extend `LumiThemeContribution`:

```swift
let fileIconThemeContributor: AnyObject?

init(
    appTheme: any SuperTheme,
    editorThemeId: String,
    editorThemeContributor: AnyObject? = nil,
    fileIconThemeContributor: AnyObject? = nil,
    order: Int = 0
)
```

- [x] Add a convenience accessor to `ThemeVM`:

```swift
var activeFileIconTheme: (any LumiFileIconThemeContributor)? {
    currentTheme?.fileIconThemeContributor as? any LumiFileIconThemeContributor
}
```

## Built-In Resolver

- [x] Move the current hard-coded mapping out of `EditorFileTreeService` into a default file icon theme contributor, for example:
  - `DefaultLumiFileIconThemeContributor`
  - `VscodeLikeFileIconThemeContributor`
- [x] Keep `EditorFileTreeService.getFileIcon(fileExtension:)` temporarily as a compatibility wrapper.
- [x] Define lookup priority:
  1. exact folder name
  2. exact file name
  3. file extension
  4. contributor default folder/file icon
  5. current built-in fallback
- [x] Normalize names before matching:
  - file names lowercased where appropriate
  - extensions lowercased
  - folders compared by `lastPathComponent`

## File Tree Integration

- [x] Replace `EditorFileTreeNodeView.fileIconName` with a lightweight cached file metadata struct:

```swift
private struct FileTreeIconMetadata: Equatable {
    let fileName: String
    let fileExtension: String
    let isDirectory: Bool
}
```

- [x] Build `LumiFileIconContext` from cached metadata and `isExpanded`.
- [x] Resolve icons through `themeVM.activeFileIconTheme`.
- [x] Fall back to the default contributor when the active theme has no icon contributor or returns `nil`.
- [x] Replace direct `Image(systemName: iconName)` with a small renderer:

```swift
@ViewBuilder
private func fileIconView(_ icon: LumiFileIcon) -> some View {
    switch icon {
    case .systemImage(let name):
        Image(systemName: name)
    case .assetImage(let name, let bundle):
        Image(name, bundle: bundle)
    }
}
```

- [x] Ensure folder icons respond to `isExpanded`.
- [x] Add `themeVM.currentThemeId` as an icon resolution dependency so SwiftUI refreshes when the theme changes.
- [x] Keep row colors driven by `activeAppTheme`.

## Theme Plugin Work

Every current theme plugin must provide a file icon theme contributor through its existing `LumiThemeContribution`. The implementation can share common base mappings, but each plugin should have a named contributor so the contribution is explicit and testable.

- [x] `ThemeAuroraPlugin`
- [x] `ThemeAutumnPlugin`
- [x] `ThemeDraculaPlugin`
- [x] `ThemeGithubPlugin`
- [x] `ThemeMidnightPlugin`
- [x] `ThemeMountainPlugin`
- [x] `ThemeNebulaPlugin`
- [x] `ThemeOneDarkPlugin`
- [x] `ThemeOrchardPlugin`
- [x] `ThemeRiverPlugin`
- [x] `ThemeSpringPlugin`
- [x] `ThemeSummerPlugin`
- [x] `ThemeVoidPlugin`
- [x] `ThemeVscodeDarkPlugin`
- [x] `ThemeVscodeLightPlugin`
- [x] `ThemeWinterPlugin`

Suggested first pass:

- [x] Add one reusable base class or struct for common Lumi file icon mappings.
- [x] Let each theme contributor customize only color-independent symbol choices initially.
- [x] Use the same icon set for all themes in the first implementation if needed, but still wire each theme through `fileIconThemeContributor`.
- [ ] Later, theme-specific variants can override mappings for product identity, such as VS Code, GitHub, Dracula, One Dark, or seasonal themes.

## Tests

- [ ] Add unit tests for exact file name lookup.
- [ ] Add unit tests for extension lookup.
- [ ] Add unit tests for folder open/closed icon lookup.
- [ ] Add unit tests proving fallback behavior matches the current `EditorFileTreeService` mappings.
- [ ] Add a `ThemeVM` test proving the active theme exposes its file icon contributor.
- [ ] Add a file tree view-level smoke test if existing SwiftUI tests can host `EditorFileTreeNodeView`.

## Migration Plan

- [x] Introduce the new model and protocol without changing behavior.
- [x] Add the default contributor that mirrors current hard-coded mappings.
- [x] Wire `LumiThemeContribution` and `ThemeVM`.
- [x] Update `EditorFileTreeNodeView` to resolve through the active theme.
- [x] Update all theme plugins to pass a file icon contributor.
- [x] Keep `EditorFileTreeService.getFileIcon(fileExtension:)` as a compatibility shim for one release.
- [ ] Remove or deprecate direct file icon mapping from `EditorFileTreeService` after all call sites move to the resolver.

## Acceptance Criteria

- [x] A theme plugin can set the file tree icon for `.gitignore` without touching `EditorRailFileTreePlugin`.
- [x] A theme plugin can set a different icon for `Package.swift` than for other `.swift` files.
- [x] A theme plugin can set different folder icons for expanded and collapsed folders.
- [x] Switching Lumi themes changes file tree icon rules immediately.
- [x] Disabling or removing a theme icon contributor falls back to current icon behavior.
- [x] All existing theme plugins compile and provide a file icon contributor.

## Verification Notes

- [x] `xcodebuild -scheme Lumi -destination 'platform=macOS' build` completed successfully on 2026-05-15.
