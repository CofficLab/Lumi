# MessageList Plugin ViewModel Ownership Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Make `MessageListPlugin` the owner of MessageList ViewModels and all external observer registrations, with observer callbacks updating ViewModel state consumed by SwiftUI views.

**Architecture:** `MessageListPlugin.onBoot` creates and retains the root routing state, V1/V2/V3 list ViewModels, and guide state. The plugin registers provider observers directly and forwards typed events to ViewModel handler methods. Views receive already-created ViewModels as `@ObservedObject`; they do not create ViewModels or register external observers. Provider `objectWillChange` subscriptions used only as MessageList external-change fallbacks are replaced by typed observer APIs.

**Tech Stack:** Swift 6, SwiftUI, Combine, provider observer handles, Xcode/macOS build.

---

### Task 1: Add typed provider change channels needed by MessageList

**Files:**
- Modify: `Packages/ProviderMessage/Sources/ProviderMessage/MessageManaging.swift`
- Modify: `Packages/ProviderMessage/Sources/ProviderMessage/DefaultMessageManager.swift`
- Modify: `Packages/PluginMessageManager/Sources/PluginMessageManager/Managers/MessageManager.swift`
- Modify: `Packages/ProviderMessageStreaming/Sources/ProviderMessageStreaming/MessageStreamingProviding.swift`

Add update/delete/clear message events and a typed streaming observer API with no-op protocol defaults for existing test doubles. Emit those events from the concrete providers.

### Task 2: Create plugin-owned MessageList ViewModel container

**Files:**
- Create: `Packages/PluginMessageList/Sources/PluginMessageList/ViewModels/MessageListViewModels.swift`
- Modify: `Packages/PluginMessageList/Sources/PluginMessageList/Models/MessageListServices.swift`

Create and retain the root route ViewModel plus the V1/V2/V3 ViewModels and guide state in one plugin-owned container.

### Task 3: Move all MessageList observer registration into the plugin entry

**Files:**
- Modify: `Packages/PluginMessageList/Sources/PluginMessageList/MessageListPlugin.swift`
- Modify: `Packages/PluginMessageList/Sources/PluginMessageList/Observers/GuideObservers.swift`
- Modify: `Packages/PluginMessageList/Sources/PluginMessageList/Observers/NoConversationSelectedToolbarCoordinator.swift`
- Delete: `Packages/PluginMessageList/Sources/PluginMessageList/Observers/MessageListObserverHub.swift`
- Delete or simplify: `Packages/PluginMessageList/Sources/PluginMessageList/Observers/MessageListServicesObserver.swift`

Make the plugin explicitly own observer handles and route every callback to the plugin-owned ViewModels. Keep observer implementation types under `Observers` only where they wrap a platform/provider handle.

### Task 4: Convert MessageList views and ViewModels to injected state

**Files:**
- Modify: `Packages/PluginMessageList/Sources/PluginMessageList/Views/ListView.swift`
- Modify: `Packages/PluginMessageList/Sources/PluginMessageList/Views/V1/ListV1View.swift`
- Modify: `Packages/PluginMessageList/Sources/PluginMessageList/Views/V2/ListV2View.swift`
- Modify: `Packages/PluginMessageList/Sources/PluginMessageList/Views/V3/ListV3View.swift`
- Modify: `Packages/PluginMessageList/Sources/PluginMessageList/Views/V1/AgentTurnView.swift`
- Modify: `Packages/PluginMessageList/Sources/PluginMessageList/ViewModels/ListV1ViewModel.swift`
- Modify: `Packages/PluginMessageList/Sources/PluginMessageList/ViewModels/ListV2ViewModel.swift`
- Modify: `Packages/PluginMessageList/Sources/PluginMessageList/ViewModels/ListV3ViewModel.swift`
- Modify: `Packages/PluginMessageList/Sources/PluginMessageList/ViewModels/AgentTurnViewModel.swift`

Remove `@StateObject` construction and hub consumer registration from views/ViewModels. Add typed handler methods that update published presentation state when called by the plugin.

### Task 5: Verify ownership and behavior

Run targeted MessageList/provider tests, scan for direct external subscriptions in MessageList views/ViewModels, run `git diff --check`, and build the complete Lumi app with Xcode.
