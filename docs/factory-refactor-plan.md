# Factory Package Refactor Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Replace the monolithic LumiFactory package with independent FactoryCore, FactoryLumi, and FactoryBookletMaker packages so BookletMaker only compiles its required plugins.

**Architecture:** FactoryCore owns shared UI, window, application bootstrap, and kernel lifecycle code but imports no concrete plugins. FactoryLumi and FactoryBookletMaker are host composition packages that each construct an explicit plugin catalog and delegate lifecycle/UI work to FactoryCore.

**Tech Stack:** Swift 6, Swift Package Manager, SwiftUI, AppKit, Xcode project package products, XCTest.

---

## Preconditions

- Preserve the user's existing changes under `Plugins/AppStoreConnectPlugin`.
- Capture `git status --short` before starting and compare it after every task.
- Do not commit generated `.build`, DerivedData, archive, DMG, or Xcode user-data files.
- Use a temporary derived-data directory for verification builds.

### Task 1: Add FactoryCore package skeleton and configuration tests

**Files:**

- Create: `Packages/FactoryCore/Package.swift`
- Create: `Packages/FactoryCore/Sources/FactoryCore/Bootstrap/FactoryConfiguration.swift`
- Create: `Packages/FactoryCore/Tests/FactoryCoreTests/FactoryConfigurationTests.swift`

**Step 1: Write failing tests**

Add tests for these invariants:

- A configuration accepts an explicit ordered plugin array.
- Duplicate plugin IDs are rejected.
- Every `enabledPluginID` must exist in the explicit plugin array.

Use a small test-only `LumiPlugin` implementation; do not import a concrete production plugin.

**Step 2: Run the tests and confirm failure**

```bash
swift test --package-path Packages/FactoryCore
```

Expected: compilation fails because FactoryConfiguration does not exist.

**Step 3: Implement the minimal Package manifest and configuration**

The manifest should directly depend only on:

- `../KernelLumi`
- `../LumiUI`
- `../LumiKitLocalization`
- `../KitSuperLog`
- `../EditorService`

Define `FactoryConfiguration` with `plugins`, `enabledPluginIDs`, `initialContainerID`, `showsStatusBar`, and `showsActivityBar`. Add a validation method or throwing initializer for the tested invariants.

**Step 4: Run tests**

```bash
swift test --package-path Packages/FactoryCore
```

Expected: all FactoryConfiguration tests pass.

**Step 5: Commit checkpoint**

```bash
git add Packages/FactoryCore
git commit -m "refactor(factory): add plugin-agnostic FactoryCore configuration"
```

### Task 2: Move shared LumiFactory implementation into FactoryCore

**Files:**

- Move: `Packages/LumiFactory/Sources/LumiFactory/Bootstrap/*` to `Packages/FactoryCore/Sources/FactoryCore/Bootstrap/`
- Move: `Packages/LumiFactory/Sources/LumiFactory/Views/*` to `Packages/FactoryCore/Sources/FactoryCore/Views/`
- Move: `Packages/LumiFactory/Sources/LumiFactory/Windows/*` to `Packages/FactoryCore/Sources/FactoryCore/Windows/`
- Move: `Packages/LumiFactory/Sources/LumiFactory/Resources/Localizable.xcstrings` to `Packages/FactoryCore/Sources/FactoryCore/Resources/Localizable.xcstrings`
- Create: `Packages/FactoryCore/Sources/FactoryCore/FactoryCore.swift`
- Modify: imports and comments in all moved Swift files
- Test: `Packages/FactoryCore/Tests/FactoryCoreTests/FactoryCoreLifecycleTests.swift`

**Step 1: Write failing lifecycle tests**

Test that `FactoryCore.destroyAllKernels()` clears the registry and that `FactoryCore.createKernel(configuration:)` uses only the plugins supplied in the configuration.

**Step 2: Move sources without PluginService**

Do not move `Services/PluginService.swift`. Copy the old `LumiFactory` lifecycle behavior into `FactoryCore`, then make these changes:

- Rename `LumiFactory` to `FactoryCore`.
- Delete `import GitPlugin`; it is unused by the current implementation.
- Remove `plugins(for:)` and all access to `PluginService.plugins`.
- Initialize exactly `configuration.plugins`.
- Rename `LumiHostConfiguration` to `FactoryConfiguration`.
- Replace internal `LumiFactory.mainKernel` references with `FactoryCore.mainKernel`.
- Change `AppCommands.swift` self-import from `LumiFactory` to `FactoryCore` or remove it when unnecessary.

**Step 3: Register resources in Package.swift**

Add `.process("Resources")` to the FactoryCore target.

**Step 4: Run tests**

```bash
swift test --package-path Packages/FactoryCore
```

Expected: configuration and lifecycle tests pass; no concrete plugin package is resolved.

**Step 5: Check the dependency boundary**

```bash
swift package describe --type json --package-path Packages/FactoryCore > /tmp/factory-core-package.json
rg 'Plugin' /tmp/factory-core-package.json
```

Expected: no concrete `*Plugin` dependency appears.

**Step 6: Commit checkpoint**

```bash
git add Packages/FactoryCore Packages/LumiFactory/Sources/LumiFactory
git commit -m "refactor(factory): move shared host engine into FactoryCore"
```

### Task 3: Create FactoryLumi with the complete plugin catalog

**Files:**

- Create: `Packages/FactoryLumi/Package.swift`
- Create: `Packages/FactoryLumi/Sources/FactoryLumi/LumiPluginCatalog.swift`
- Create: `Packages/FactoryLumi/Sources/FactoryLumi/FactoryLumi.swift`
- Create: `Packages/FactoryLumi/Tests/FactoryLumiTests/LumiPluginCatalogTests.swift`
- Source reference: `Packages/LumiFactory/Sources/LumiFactory/Services/PluginService.swift`
- Source reference: `Packages/LumiFactory/Package.swift`

**Step 1: Write failing catalog tests**

Test that:

- Plugin IDs are unique.
- The catalog preserves the current first-order bootstrap constraints: LLM provider manager, editor kernel, and editor provider precede dependent plugins.
- Representative core and feature plugin IDs are present.
- A compatibility selection function rejects unknown IDs.

**Step 2: Build the FactoryLumi manifest**

Move the current full concrete plugin dependency list from LumiFactory into FactoryLumi. Add FactoryCore as a local dependency. Keep AppUpdatePlugin and ProjectRAGPlugin outside this manifest because LumiApp injects them explicitly.

**Step 3: Move and rename the catalog**

Move `PluginService.plugins` to `LumiPluginCatalog.plugins` without changing construction order or conditional StoragePlugin handling.

**Step 4: Implement the facade**

FactoryLumi should build a `FactoryConfiguration` from its catalog and delegate main window, settings window, and commands creation to FactoryCore. Provide:

- Default full-Lumi configuration.
- `additionalPlugins` support.
- A clearly deprecated/transition-only ID selection API for AppIconDesigner, CADDesigner, and DatabaseManager.

Do not place ID selection in FactoryCore.

**Step 5: Run tests**

```bash
swift test --package-path Packages/FactoryLumi
```

Expected: catalog tests pass.

**Step 6: Commit checkpoint**

```bash
git add Packages/FactoryLumi Packages/LumiFactory
git commit -m "refactor(factory): move full plugin composition into FactoryLumi"
```

### Task 4: Create FactoryBookletMaker with a minimal plugin catalog

**Files:**

- Create: `Packages/FactoryBookletMaker/Package.swift`
- Create: `Packages/FactoryBookletMaker/Sources/FactoryBookletMaker/BookletMakerPluginCatalog.swift`
- Create: `Packages/FactoryBookletMaker/Sources/FactoryBookletMaker/FactoryBookletMaker.swift`
- Create: `Packages/FactoryBookletMaker/Tests/FactoryBookletMakerTests/BookletMakerPluginCatalogTests.swift`

**Step 1: Write failing exact-set tests**

Assert that the catalog contains exactly the approved plugin IDs corresponding to:

```text
StoragePlugin, ProjectsPlugin, WorkspacePlugin, CommandPlugin,
MessageSenderPlugin, LLMProviderManagerPlugin, AgentTurnRunnerPlugin,
EditorKernelPlugin, EditorProviderPlugin, ToolManagerPlugin,
SettingsPlugin, LogoPlugin, ThemeManagerPlugin, ThemeLumiPlugin,
MessageRendererPlugin, BookletMakerPlugin
```

Also assert unique IDs and required bootstrap order.

**Step 2: Create the minimal manifest**

Declare only FactoryCore and the 16 approved plugin packages. Do not copy the FactoryLumi manifest wholesale.

**Step 3: Implement the fixed catalog and facade**

Construct plugins in dependency-safe order. Set:

- `enabledPluginIDs` to the BookletMaker plugin ID.
- `initialContainerID` to the BookletMaker plugin ID.
- `showsStatusBar` to false.
- `showsActivityBar` to false.

Do not expose a general allowlist API.

**Step 4: Run tests and dependency checks**

```bash
swift test --package-path Packages/FactoryBookletMaker
swift package describe --type json --package-path Packages/FactoryBookletMaker > /tmp/factory-booklet-package.json
rg 'LLMProviderMLXPlugin|DatabaseManagerPlugin|Postgres|MySQL' /tmp/factory-booklet-package.json
```

Expected: tests pass and the forbidden-dependency search returns no matches.

**Step 5: Commit checkpoint**

```bash
git add Packages/FactoryBookletMaker
git commit -m "refactor(factory): add minimal BookletMaker composition"
```

### Task 5: Update Xcode local package references and products

**Files:**

- Modify: `Lumi.xcodeproj/project.pbxproj`

**Step 1: Add three local package references**

Replace `Packages/LumiFactory` with:

- `Packages/FactoryCore`
- `Packages/FactoryLumi`
- `Packages/FactoryBookletMaker`

**Step 2: Assign products per target**

- Lumi: FactoryCore + FactoryLumi.
- BookletMaker: FactoryCore + FactoryBookletMaker.
- AppIconDesigner, CADDesigner, DatabaseManager: FactoryCore + FactoryLumi for transitional compatibility.

Keep unrelated products such as AppUpdatePlugin and ProjectRAGPlugin unchanged.

**Step 3: Validate project syntax and schemes**

```bash
plutil -lint Lumi.xcodeproj/project.pbxproj
xcodebuild -project Lumi.xcodeproj -list
```

Expected: project parses and all existing schemes are listed.

**Step 4: Commit checkpoint**

```bash
git add Lumi.xcodeproj/project.pbxproj
git commit -m "build(factory): link app targets to host-specific factories"
```

### Task 6: Migrate application entry points

**Files:**

- Modify: `LumiApp/LumiApp.swift`
- Modify: `BookletMakerApp/BookletMakerApp.swift`
- Modify: `AppIconDesignerApp/AppIconDesignerApp.swift`
- Modify: `CADDesignerApp/CADDesignerApp.swift`
- Modify: `DatabaseManagerApp/DatabaseManagerApp.swift`

**Step 1: Migrate LumiApp**

Import FactoryCore and FactoryLumi. Replace LumiFactory calls with FactoryLumi calls. Preserve explicit `AppUpdatePlugin()` and `ProjectRAGPlugin()` injection.

**Step 2: Migrate BookletMakerApp**

Import FactoryCore and FactoryBookletMaker. Delete the local allowlist configuration. Use FactoryBookletMaker for main window, settings, and commands.

**Step 3: Migrate transitional apps**

Import FactoryCore and FactoryLumi, translate each existing allowlist into the FactoryLumi transition-only ID selection API, and preserve window presentation settings.

**Step 4: Check for old imports**

```bash
rg 'import LumiFactory|LumiFactory\.' --glob '*.swift' .
```

Expected: no matches.

**Step 5: Commit checkpoint**

```bash
git add LumiApp BookletMakerApp AppIconDesignerApp CADDesignerApp DatabaseManagerApp
git commit -m "refactor(factory): migrate app entry points"
```

### Task 7: Remove the legacy package and update documentation

**Files:**

- Delete: `Packages/LumiFactory/`
- Modify: comments mentioning `LumiFactory` under `Packages/KernelLumi` and `Plugins/GitPlugin`
- Modify: any README or developer documentation found by search

**Step 1: Find remaining references**

```bash
rg 'LumiFactory|Packages/LumiFactory' --glob '!docs/factory-*.md' .
```

Classify every result as code, documentation, generated output, or intentional history.

**Step 2: Delete the legacy package**

Remove only `Packages/LumiFactory`; do not delete the new packages or generated user data outside the repository.

**Step 3: Update current comments and docs**

Use `FactoryCore` when referring to lifecycle ownership and the appropriate host Factory when referring to plugin composition.

**Step 4: Commit checkpoint**

```bash
git add -A Packages/LumiFactory Packages/FactoryCore Packages/FactoryLumi Packages/FactoryBookletMaker Packages/KernelLumi Plugins/GitPlugin docs
git commit -m "refactor(factory): remove legacy LumiFactory package"
```

### Task 8: Build, test, and measure

**Files:**

- No source changes expected unless verification exposes a defect.
- Create temporary reports outside the repository under `/tmp/lumi-factory-verification`.

**Step 1: Run package tests**

```bash
swift test --package-path Packages/FactoryCore
swift test --package-path Packages/FactoryBookletMaker
swift test --package-path Packages/FactoryLumi
```

Expected: all tests pass.

**Step 2: Build the two primary app targets**

```bash
xcodebuild build -project Lumi.xcodeproj -scheme Lumi -configuration Debug -derivedDataPath /tmp/lumi-factory-verification/lumi CODE_SIGNING_ALLOWED=NO
xcodebuild build -project Lumi.xcodeproj -scheme BookletMaker -configuration Debug -derivedDataPath /tmp/lumi-factory-verification/booklet CODE_SIGNING_ALLOWED=NO
```

Expected: both builds succeed.

**Step 3: Build transitional app targets**

Run Debug builds for AppIconDesigner, CADDesigner, and DatabaseManager with signing disabled.

Expected: all builds succeed and their initial container IDs resolve.

**Step 4: Archive arm64 Release builds**

Archive Lumi and BookletMaker separately with `ARCHS=arm64`, `ONLY_ACTIVE_ARCH=NO`, and signing disabled into `/tmp/lumi-factory-verification`.

Expected: both archives succeed.

**Step 5: Produce a size report**

For each archived app, record:

```bash
du -sh <app>
du -sh <app>/Contents/MacOS/*
du -sh <app>/Contents/Resources
find <app>/Contents -type f -print0 | xargs -0 du -k | sort -nr | head -30
```

Confirm that the BookletMaker artifact contains no MLX, database, or unrelated plugin resource bundles.

**Step 6: Run smoke tests**

- Lumi: launch, open settings, verify complete plugin list, exercise AppUpdate and ProjectRAG availability.
- BookletMaker: launch, open a project, open settings, generate a booklet.
- Other apps: launch and confirm their initial container.

**Step 7: Final repository audit**

```bash
git status --short
rg 'import LumiFactory|LumiFactory\.' --glob '*.swift' .
```

Expected: only intended changes plus the user's pre-existing AppStoreConnectPlugin work are present; no old code imports remain.

**Step 8: Final commit**

```bash
git add Packages/FactoryCore Packages/FactoryLumi Packages/FactoryBookletMaker Lumi.xcodeproj LumiApp BookletMakerApp AppIconDesignerApp CADDesignerApp DatabaseManagerApp Packages/KernelLumi Plugins/GitPlugin docs
git commit -m "refactor(factory): split host composition by application"
```

