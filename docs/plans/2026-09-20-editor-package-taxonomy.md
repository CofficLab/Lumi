# Editor Package Taxonomy Implementation Plan

**Goal:** Put every editor package in the `Kit*`, `Provider*`, or `Plugin*` package family, with no standalone `Editor*` package exception.

**Architecture:** Keep editor contracts in `ProviderEditor`; classify reusable editor layers as `KitEditor*`; keep user-facing integrations in `Plugin*`. Absorb the concrete `EditorService` target, tests, and resources into `PluginCodeEditorHost`, so no separate service package or plugin-to-plugin dependency remains. Rename package directories, manifest package names, and local SwiftPM package identities; preserve existing library product and module names where practical to avoid unrelated import churn.

**Tech Stack:** Swift Package Manager, Swift 6, Bash boundary checks, repository architecture documentation.

**Implementation status:** Complete. All Editor package directories are now classified as `ProviderEditor`, `KitEditor*`, or `PluginCodeEditor*`; `EditorService` is an internal target of `PluginCodeEditorHost`.

---

### Task 1: Make the editor package taxonomy executable

**Files:**
- Modify: `Scripts/check-editor-provider-boundary.sh`
- Test: `Scripts/check-editor-provider-boundary.sh`

**Steps:**
1. Extend the boundary check to fail when any direct package directory under `Packages/` begins with `Editor`.
2. Add explicit checks that the editor contract package and four reusable implementation packages use their `ProviderEditor` / `KitEditor*` names, and that the service is hosted by `PluginCodeEditorHost` rather than a separate package.
3. Run the script and verify it fails against the current legacy package paths.

### Task 2: Reclassify provider and reusable implementation packages

**Files:**
- Move: `Packages/EditorContracts` → `Packages/ProviderEditor`
- Move: `Packages/EditorKernel` → `Packages/KitEditorKernel`
- Move: `Packages/EditorLanguageRuntime` → `Packages/KitEditorLanguageRuntime`
- Move: `Packages/EditorSource` → `Packages/KitEditorSource`
- Move: `Packages/EditorTextView` → `Packages/KitEditorTextView`
- Modify: the moved `Package.swift` files and local dependency paths/package identities throughout `Packages/`
- Modify: `Packages/ProviderEditor/README.md` and the moved Kit package READMEs

**Steps:**
1. Rename package directories and SwiftPM manifest package names to match their taxonomy prefixes; retain stable product/target/module names unless a package-name conflict requires a change.
2. Update every local path and SwiftPM package identity that refers to the old package directories; preserve source imports when products retain their current names.
3. Keep the Provider limited to contracts and Kit dependencies; keep the Kit layers independent of Provider and Plugin packages.
4. Resolve and test each moved package, then rerun the boundary check.

### Task 3: Merge EditorService into the Host plugin package

**Files:**
- Move: `Packages/EditorService/Sources` → `Packages/PluginCodeEditorHost/Sources/EditorService`
- Move: `Packages/EditorService/Tests` → `Packages/PluginCodeEditorHost/Tests/EditorServiceTests`
- Move: `Packages/EditorService/Resources` → `Packages/PluginCodeEditorHost/Sources/EditorService/Resources`
- Move/merge: `Packages/EditorService/README.md` into Host package documentation
- Modify: `Packages/PluginCodeEditorHost/Package.swift`
- Remove: standalone `Packages/EditorService/Package.swift` and the now-empty standalone package directory

**Steps:**
1. Add `EditorService` as a non-product internal target in the Host package, with its existing dependencies and resources.
2. Make the Host target and Host tests depend on that internal target.
3. Move service tests into the Host package and preserve their test target name where practical.
4. Remove the standalone EditorService package dependency and verify no other package depends on it.
5. Resolve and test `PluginCodeEditorHost`.

### Task 4: Synchronize architecture and package documentation

**Files:**
- Modify: `docs/plugin-first-architecture-sharing.md`
- Modify: `docs/editor-architecture.md`
- Modify: editor package READMEs and package-count references found during migration

**Steps:**
1. Remove `Editor*` as a package category and document the concrete mapping to `ProviderEditor`, `KitEditor*`, and `Plugin*`.
2. Update architecture diagrams, dependency paths, package tables, and command examples to match the new package layout.
3. State the no-exception rule and point to the automated boundary check.
4. Search repository docs and manifests for stale package paths and names; distinguish package names from legitimate domain/type names such as `EditorService`.

### Task 5: Verify the full migration

**Files:**
- Test: all renamed editor Swift packages and `Packages/PluginCodeEditorHost`
- Test: `Scripts/check-editor-provider-boundary.sh`
- Test: repository macOS app build

**Steps:**
1. Run focused `swift test --package-path ...` checks for `ProviderEditor`, each `KitEditor*` package, and `PluginCodeEditorHost`.
2. Run the editor dependency-boundary script and verify no direct `Packages/Editor*` directory or standalone `EditorService` package remains.
3. Run `git diff --check` and inspect the final changed-file list to ensure unrelated dirty work is untouched.
4. Run the Lumi macOS Debug build and report any unrelated pre-existing failures separately.

**Completion record:**
- `ProviderEditor`: 14 tests passed.
- `KitEditorKernel`: 318 tests passed.
- `KitEditorLanguageRuntime`: 17 tests passed.
- `KitEditorSource`: 68 tests passed.
- `KitEditorTextView`: 75 tests passed.
- `PluginCodeEditorHost`: 195 tests run, 3 skipped, 0 failures.
- `Scripts/check-editor-provider-boundary.sh` and `git diff --check` passed.
- Lumi macOS Debug Xcode build succeeded.
