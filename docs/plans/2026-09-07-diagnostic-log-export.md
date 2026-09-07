# Diagnostic Log Export Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Make Lumi reliably retain diagnostic logs under the file-log plugin ID and expose a user-facing export action in Settings → General.

**Architecture:** Add a small `ProviderDiagnostics` contract so the settings plugin depends only on an export capability. `PluginFileLog` implements that capability, owns the plugin-ID directory, migrates the legacy `FileLog` directory, captures all Lumi subsystem children, and creates a redacted ZIP diagnostic bundle. The General settings view presents a single export row and saves the bundle through an AppKit save panel.

**Tech Stack:** Swift 6, SwiftUI/AppKit, KernelCore providers, `OSLogStore`, Foundation `Process`/`ditto`, Swift Testing.

---

### Task 1: Add the diagnostics provider contract

**Files:**
- Create: `Packages/ProviderDiagnostics/Package.swift`
- Create: `Packages/ProviderDiagnostics/Sources/ProviderDiagnostics/DiagnosticsProviding.swift`
- Test: `Packages/ProviderDiagnostics/Tests/ProviderDiagnosticsTests/DiagnosticsProvidingTests.swift`

Define a main-actor `DiagnosticsProviding` protocol with a stable logs directory URL and an async method that creates a diagnostic archive. Keep the result as a `URL` plus filename so the UI can present a save panel without knowing the implementation.

### Task 2: Make file-log storage complete and plugin-ID based

**Files:**
- Modify: `Packages/PluginFileLog/Package.swift`
- Modify: `Packages/PluginFileLog/Sources/PluginFileLog/FileLogPlugin.swift`
- Modify: `Packages/PluginFileLog/Sources/PluginFileLog/FileLogCoordinator.swift`
- Test: `Packages/PluginFileLog/Tests/PluginFileLogTests/FileLogCoordinatorTests.swift`

Make the coordinator implement `DiagnosticsProviding`, use `com.coffic.lumi.plugin.file-log` as its storage directory name, migrate the old `FileLog` directory when possible, and filter `com.coffic.lumi` plus child subsystems. Start it at an early plugin order so bootstrap failures are retained. Preserve rotation and retention, add a total directory-size cap, and expose deterministic helper methods for tests.

### Task 3: Implement diagnostic archive creation

**Files:**
- Modify: `Packages/PluginFileLog/Sources/PluginFileLog/FileLogCoordinator.swift`
- Test: `Packages/PluginFileLog/Tests/PluginFileLogTests/FileLogCoordinatorTests.swift`

Create a temporary bundle containing recent Lumi log files and a metadata manifest with version/build, OS version, architecture, export time, process ID, and storage path relative to the bundle. Use `ditto` to create a ZIP on macOS, wait for pending writes before collecting, and remove temporary staging data on failure or after the archive is saved. Never include arbitrary application data or crash reports automatically.

### Task 4: Connect the provider to the General settings page

**Files:**
- Modify: `Packages/PluginSettingGeneral/Package.swift`
- Modify: `Packages/PluginSettingGeneral/Sources/PluginSettingGeneral/SettingGeneralPlugin.swift`
- Modify: `Packages/PluginSettingGeneral/Sources/PluginSettingGeneral/Views/GeneralSettingsDetailView.swift`
- Modify: `Packages/PluginSettingGeneral/Resources/Localizable.xcstrings`
- Test: `Packages/PluginSettingGeneral/Tests/PluginSettingGeneralTests/...`

Resolve `DiagnosticsProviding` during boot, pass it into the detail view, and add a “诊断日志 / 导出” row under General. Use a save panel so the user explicitly chooses where to save the ZIP. Show progress and success/failure feedback without blocking the main actor.

### Task 5: Wire package dependencies and verify the application

**Files:**
- Modify: `Packages/FactoryLumi/Package.swift`
- Modify: `Packages/FactoryLumi/Sources/FactoryLumi/PluginFactory.swift`
- Modify: `Packages/FactoryLumi/Tests/FactoryLumiTests/...`
- Modify: `Lumi.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved` only if Xcode updates it

Add the new provider package to the package graph, register the provider through `FileLogPlugin`, and verify plugin ordering and selected settings behavior.

Run the provider, file-log, setting-general, and FactoryLumi tests, then run the full arm64 Lumi Debug build. Confirm `git diff --check`, the new plugin-ID directory behavior, archive contents, and a clean working tree apart from intentional commits.
