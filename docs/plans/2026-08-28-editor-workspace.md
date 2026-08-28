# Lumi Editor Workspace Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use executing-plans to implement this plan task-by-task.

**Goal:** Deliver a user-toggleable Lumi code workspace with Activity Bar entry, project file explorer, tabbed source editing, syntax highlighting, save/auto-save, restoration, and verified error handling.

**Architecture:** Keep `PluginEditorHost` as required editor infrastructure and add a disabled-by-default `PluginEditorWorkspace` for visible workbench contributions. Reuse `EditorService` as the source of truth for buffers and sessions, mirror session state through `ProjectProviding`, and register language grammars through a separate language-support target.

**Tech Stack:** Swift 6, SwiftUI/AppKit, KernelCore plugin lifecycle, ProviderActivityBar, ProviderRailView, ProviderContentView, ProviderProject, EditorService, EditorSource, EditorLanguageRuntime, Tree-sitter, Swift Testing/XCTest.

---

### Task 1: Restore the full Editor Host contract

**Files:**
- Modify: `Packages/PluginEditorHost/Package.swift`
- Modify: `Packages/PluginEditorHost/Sources/PluginEditorHost/EditorHostSuperPlugin.swift`
- Create: `Packages/PluginEditorHost/Sources/PluginEditorHost/EditorSurfaceView.swift`
- Test: `Packages/PluginEditorHost/Tests/PluginEditorHostTests/EditorHostSuperPluginTests.swift`

**Steps:**

1. Add failing tests asserting that boot registers `EditorService`, `EditorProvidingV2`, `EditorSurfaceProviding`, and `EditorEmbeddedEditorProviding` as the same host scope.
2. Run `swift test --package-path Packages/PluginEditorHost` and verify the new contract assertions fail.
3. Restore the standard `SourceEditor` surface and coordinators from the historical host implementation.
4. Construct `EditorContributionRegistry` and `EditorProvidingV2Adapter`, inject the surface factory, and register protocol-facing providers.
5. Keep registration idempotent and make unavailable-service states explicit.
6. Run the host tests and commit only host files.

### Task 2: Build the workspace state and project/session bridge

**Files:**
- Create: `Packages/PluginEditorWorkspace/Package.swift`
- Create: `Packages/PluginEditorWorkspace/Sources/PluginEditorWorkspace/EditorWorkspaceController.swift`
- Create: `Packages/PluginEditorWorkspace/Sources/PluginEditorWorkspace/EditorWorkspaceRuntime.swift`
- Test: `Packages/PluginEditorWorkspace/Tests/EditorWorkspaceControllerTests.swift`

**Steps:**

1. Write tests for project-root propagation, opening-file persistence, current-file synchronization, project switching, and observer cancellation.
2. Verify tests fail before implementation.
3. Implement a `@MainActor` controller observing `ProjectProviding.objectWillChange` and editor session state.
4. Normalize and deduplicate URLs before mirroring open tabs to the project provider.
5. Restore only files inside the active project and tolerate missing/deleted files.
6. Run the focused tests and commit the controller slice.

### Task 3: Implement a lazy project file explorer

**Files:**
- Create: `Packages/PluginEditorWorkspace/Sources/PluginEditorWorkspace/Explorer/EditorFileTreeNode.swift`
- Create: `Packages/PluginEditorWorkspace/Sources/PluginEditorWorkspace/Explorer/EditorFileTreeModel.swift`
- Create: `Packages/PluginEditorWorkspace/Sources/PluginEditorWorkspace/Explorer/EditorFileTreeView.swift`
- Create: `Packages/PluginEditorWorkspace/Sources/PluginEditorWorkspace/Explorer/EditorFileIcon.swift`
- Test: `Packages/PluginEditorWorkspace/Tests/EditorFileTreeModelTests.swift`

**Steps:**

1. Add temporary-directory tests for folder-first sorting, hidden/build exclusions, lazy loading, refresh, cancellation, inaccessible folders, symlinks, and stable identity.
2. Run tests and confirm the model is absent/failing.
3. Implement cancellable detached enumeration with results applied on the main actor.
4. Implement a hierarchical SwiftUI Rail view with expand/collapse, refresh, selected-file reveal, empty project, loading, and error states.
5. Open regular files through the workspace controller; never treat directories or packages as text files.
6. Run model and package tests, then commit the explorer slice.

### Task 4: Build the tabbed editor workbench

**Files:**
- Create: `Packages/PluginEditorWorkspace/Sources/PluginEditorWorkspace/Workbench/EditorWorkbenchView.swift`
- Create: `Packages/PluginEditorWorkspace/Sources/PluginEditorWorkspace/Workbench/EditorTabStripView.swift`
- Create: `Packages/PluginEditorWorkspace/Sources/PluginEditorWorkspace/Workbench/EditorBreadcrumbView.swift`
- Create: `Packages/PluginEditorWorkspace/Sources/PluginEditorWorkspace/Workbench/EditorStatusBarView.swift`
- Create: `Packages/PluginEditorWorkspace/Sources/PluginEditorWorkspace/Workbench/EditorEmptyStateView.swift`
- Test: `Packages/PluginEditorWorkspace/Tests/EditorWorkbenchModelTests.swift`

**Steps:**

1. Add tests for tab order, active tab, dirty marker, close behavior, missing file, read-only state, and status presentation.
2. Expose only testable presentation models outside SwiftUI views.
3. Compose tab strip, breadcrumb, host-provided editor surface, state banners, and status bar.
4. Wire Cmd-S, Cmd-W, Cmd-P, Cmd-F, and tab navigation to existing editor commands where supported.
5. Ensure unsaved close goes through the save/discard/cancel workflow.
6. Run focused tests and commit the workbench slice.

### Task 5: Implement plugin lifecycle and visible contributions

**Files:**
- Create: `Packages/PluginEditorWorkspace/Sources/PluginEditorWorkspace/EditorWorkspaceSuperPlugin.swift`
- Create: `Packages/PluginEditorWorkspace/Resources/Localizable.xcstrings`
- Test: `Packages/PluginEditorWorkspace/Tests/EditorWorkspaceSuperPluginTests.swift`

**Steps:**

1. Write a kernel integration test with default Activity Bar, Rail, Content, Project, and Editor Host providers.
2. Assert the disabled-by-default metadata and dependency on `com.coffic.lumi.plugin.editor-host`.
3. Implement `onBoot` to add one Activity Bar entry and one Explorer Rail tab; activate the editor content and Rail group from the entry callback.
4. Implement `onShutdown` to remove owned contributions, cancel observations, and avoid clearing another plugin's content.
5. Verify enable/disable/re-enable does not duplicate entries or observers.
6. Run integration tests and commit the plugin lifecycle slice.

### Task 6: Add built-in language support

**Files:**
- Create: `Packages/PluginEditorLanguages/Package.swift`
- Create: `Packages/PluginEditorLanguages/Sources/PluginEditorLanguages/EditorLanguagesSuperPlugin.swift`
- Create: `Packages/PluginEditorLanguages/Sources/PluginEditorLanguages/Languages/*.swift`
- Create: `Packages/PluginEditorLanguages/Sources/PluginEditorLanguages/Resources/tree-sitter-*/highlights.scm`
- Test: `Packages/PluginEditorLanguages/Tests/EditorLanguagesTests.swift`

**Steps:**

1. Select maintained SPM-compatible Tree-sitter grammar products for Swift, JavaScript/TypeScript, JSON, Markdown, Python, Bash, and YAML; pin versions or immutable revisions.
2. Add failing detection tests for representative extensions, filenames, shebangs, comments, and grammar availability.
3. Register descriptors and grammar providers atomically during boot and unregister them during shutdown.
4. Add SourceKit-LSP discovery for Swift without making the language plugin boot depend on its presence.
5. Verify each fixture produces non-empty highlight ranges and unknown files remain editable as plain text.
6. Run language/runtime/editor highlight tests and commit the language slice.

### Task 7: Wire plugins into the default Lumi factory

**Files:**
- Modify: `Packages/FactoryLumi/Package.swift`
- Modify: `Packages/FactoryLumi/Sources/FactoryLumi/PluginFactory.swift`
- Test: `Packages/FactoryLumi/Tests/FactoryLumiTests/EditorWorkspaceFactoryTests.swift`

**Steps:**

1. Add a failing factory test asserting host and language infrastructure are present and workspace metadata is disabled by default.
2. Add package dependencies and target products for all three editor plugins.
3. Insert host first, languages after host, and workspace after layout providers are available.
4. Run FactoryLumi tests and verify the editor remains absent from Activity Bar until explicitly enabled.
5. Enable the workspace in the test and verify Activity Bar/Rail/content contributions appear exactly once.
6. Commit factory wiring separately.

### Task 8: Repair service tests and verify the complete experience

**Files:**
- Modify: `Packages/EditorService/Tests/EditorContributionRegistryTests.swift`
- Modify: `Packages/EditorService/Tests/EditorProvidingV2AdapterCapabilityTests.swift`
- Create: `docs/testing/editor-workspace-smoke-test.md`

**Steps:**

1. Replace stale `KernelLumi` test imports with current `EditorContracts`/runtime types and run the full EditorService suite.
2. Run `swift test` for EditorLanguageRuntime, EditorSource, EditorKernel, EditorService, PluginEditorHost, PluginEditorLanguages, PluginEditorWorkspace, and FactoryLumi.
3. Build the Lumi Debug scheme with code signing disabled and treat warnings separately from errors.
4. Launch the app and execute the documented smoke flow: enable plugin, activate editor, open project, expand folders, open two language fixtures, edit, Cmd-S, verify disk, auto-save, external conflict, close/reopen, restore tabs.
5. Capture screenshots of Explorer, highlighted editor with dirty tab, and save/conflict state for visual review.
6. Fix all failures, rerun the relevant gate, and only then mark the editor goal complete.

