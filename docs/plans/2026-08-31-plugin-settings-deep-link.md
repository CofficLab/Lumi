# Plugin Settings Deep Link Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Make the home-screen “浏览插件” suggestion open the plugin-management settings entry instead of the default “通用” entry.

**Architecture:** Preserve the existing notification-based window opening, but include the requested settings entry ID in the notification payload. Promote settings selection to the `SettingViewProviding` contract, make both settings view implementations render from the provider’s live selection, and use the canonical `plugin-manager` entry ID at the source.

**Tech Stack:** Swift 6, SwiftUI, Swift Package Manager, XCTest/Swift Testing.

---

### Task 1: Define the settings-navigation contract

**Files:**
- Modify: `Packages/ProviderSettingView/Sources/ProviderSettingView/SettingViewProviding.swift`
- Modify: `Packages/ProviderPromptSuggestion/Package.swift`
- Modify: `Packages/ProviderPromptSuggestion/Sources/ProviderPromptSuggestion/DefaultPromptSuggestionExecutor.swift`

**Steps:**

1. Add a shared notification name and user-info key for selecting a settings entry.
2. Make `selectedEntryID` and `selectEntry(id:)` first-class protocol requirements with default implementations.
3. In the `.openSettingsTab` executor branch, preserve the associated tab ID in the notification payload.

### Task 2: Fix plugin-manager routing and live settings selection

**Files:**
- Modify: `Packages/PluginPluginManager/Sources/PluginPluginManager/PluginPluginManager.swift`
- Modify: `Packages/PluginSettingView/Sources/PluginSettingView/Managers/SettingViewManager.swift`
- Modify: `Packages/PluginSettingView/Sources/PluginSettingView/Views/SettingView.swift`
- Modify: `Packages/ProviderSettingView/Sources/ProviderSettingView/Views/SettingView.swift`
- Modify: `LumiApp/LumiApp.swift`

**Steps:**

1. Pass `plugin-manager`, the actual `SettingEntryItem` ID, from the “浏览插件” suggestion.
2. Have the app consume the optional target ID and select it before opening the settings window.
3. Remove stale local selection caches from both settings view implementations so provider changes are rendered immediately.
4. Keep generic settings-button behavior unchanged when no target ID is supplied.

### Task 3: Add regression coverage and verify

**Files:**
- Modify: `Packages/ProviderPromptSuggestion/Tests/ProviderPromptSuggestionTests/PromptSuggestionExecutorTests.swift`
- Modify: `Packages/PluginPluginManager/Tests/PluginPluginManagerTests/PluginPluginManagerTests.swift`
- Modify: `Packages/PluginSettingView/Tests/PluginSettingViewTests/SettingViewManagerTests.swift`

**Steps:**

1. Assert that `.openSettingsTab` publishes the requested entry ID.
2. Assert that the plugin-manager suggestion targets `plugin-manager`.
3. Assert that the settings manager consumes the navigation request and changes selection.
4. Run the focused Swift package tests, then build the Lumi target if the environment supports Xcode.
