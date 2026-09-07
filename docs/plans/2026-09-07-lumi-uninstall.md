# Lumi Uninstall Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add a safe, explicit Lumi uninstall flow under Settings > General that removes Lumi-owned application data, preferences, app-group data, and known credentials, then moves the running application bundle to the Trash.

**Architecture:** Add a small `ProviderUninstall` package containing the public scan/execute contract and a filesystem/keychain-backed implementation. `PluginSettingGeneral` only presents the scan result, requires a typed confirmation, and invokes the provider; the provider enforces path boundaries and reports partial failures. User project files and system-wide macOS logs remain out of scope.

**Tech Stack:** Swift 6, Swift Package Manager, SwiftUI/AppKit, Security Keychain APIs, Swift Testing.

---

### Task 1: Add uninstall provider contract and safe target discovery

**Files:**
- Create: `Packages/ProviderUninstall/Package.swift`
- Create: `Packages/ProviderUninstall/Sources/ProviderUninstall/UninstallProviding.swift`
- Create: `Packages/ProviderUninstall/Sources/ProviderUninstall/DefaultUninstallProvider.swift`
- Create: `Packages/ProviderUninstall/Tests/ProviderUninstallTests/UninstallProviderTests.swift`

**Verification:** Test discovery for release/debug/versioned roots, legacy directories, App Group identifiers, preference domains, and known Keychain services; test that unrelated paths are rejected.

### Task 2: Connect the provider to the general settings plugin

**Files:**
- Modify: `Packages/PluginSettingGeneral/Package.swift`
- Modify: `Packages/PluginSettingGeneral/Sources/PluginSettingGeneral/SettingGeneralPlugin.swift`
- Modify: `Packages/PluginSettingGeneral/Sources/PluginSettingGeneral/Views/GeneralSettingsDetailView.swift`

**Verification:** Build and test the package; confirm the General page has an uninstall row, displays a preflight summary, requires the exact confirmation phrase, and does not start cleanup before confirmation.

### Task 3: Add lifecycle-safe cleanup and application removal

**Files:**
- Modify: `Packages/ProviderUninstall/Sources/ProviderUninstall/DefaultUninstallProvider.swift`
- Modify: `Packages/PluginSettingGeneral/Sources/PluginSettingGeneral/Views/GeneralSettingsDetailView.swift`

**Verification:** Run provider tests with temporary directories, verify partial-failure reporting, and verify the app bundle is only trashed after data cleanup succeeds or the user explicitly accepts a partial result. Run the relevant Swift package tests and an Xcode build if available.

### Task 4: Review the final diff and preserve unrelated work

**Verification:** Inspect `git diff`, ensure no unrelated files are changed, and report any platform limitations such as macOS-managed metadata or SSD secure erase semantics.
