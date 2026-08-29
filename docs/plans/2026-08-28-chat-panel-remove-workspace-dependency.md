# ChatPanel Remove Workspace Dependency Implementation Plan

> **For Codex:** Implement this plan task-by-task with verification checkpoints.

**Goal:** Remove `PluginChatPanel`'s direct dependency on `ProviderWorkspace` while preserving ActivityBar-driven ChatSection behavior.

**Architecture:** ChatPanel remains responsible for registering the ActivityBar entry and toggling ChatSection/Rail/ContentView state. The root host treats ChatSection visibility and injected content as valid renderable workbench content, so ChatPanel no longer needs to create a workspace container. The trailing pane observes ChatSection visibility to stay synchronized after ActivityBar switches.

**Tech Stack:** Swift 6, SwiftUI, Combine, Swift Package Manager, Swift Testing.

---

### Task 1: Remove the plugin dependency

**Files:**
- Modify: `Packages/PluginChatPanel/Sources/PluginChatPanel/ChatPanelPlugin.swift`
- Modify: `Packages/PluginChatPanel/Package.swift`

Remove the Workspace import, provider resolution, container registration/activation, shutdown cleanup, and SwiftPM package/product dependency. Keep ActivityBar, ChatSection, RailView, and ContentView behavior unchanged.

### Task 2: Preserve host rendering without workspace containers

**Files:**
- Modify: `Packages/ProviderRootView/Sources/ProviderRootView/RootViewProviding.swift`
- Modify: `Packages/ProviderRootView/Sources/ProviderRootView/DefaultRootViewProvider.swift`
- Modify: `Packages/ProviderRootView/Sources/ProviderRootView/Views/WorkbenchSplitView.swift`
- Modify: `Packages/ProviderRootView/Package.swift`
- Modify: `Packages/FactoryLumi/Sources/FactoryLumi/ViewFactory.swift`

Make `RootTrailingPane` observe `ChatSectionProviding.isVisible`, and let the root render when injected content or a visible trailing pane exists even if no Workspace container is registered.

### Task 3: Update verification

**Files:**
- Modify: `Packages/FactoryLumi/Tests/FactoryLumiTests/KernelFactoryInfrastructureTests.swift`

Replace the assertion that ChatPanel owns the active workspace container with assertions for the ActivityBar and ChatSection contract. Run the affected package tests, then the full relevant test suite and confirm no remaining ChatPanel source/manifest reference to `ProviderWorkspace`.
