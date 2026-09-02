# Async Message Snapshot Migration Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Move full-conversation message materialization off the MainActor so history-heavy reads cannot block message sending and list rendering.

**Architecture:** Add a generic `messagesSnapshot(in:) async` read API to `MessageManaging`. The production manager performs the disk read and pending-buffer merge in a detached background task; the existing synchronous `messages(for:)` API remains for compatibility and is migrated call-site by call-site. Async UI, title/statistics, and agent-loop paths use the new API while pagination continues to use bounded pages.

**Tech Stack:** Swift 6, Swift Concurrency, SwiftUI, SwiftData-backed `MessageStore`, Swift Testing.

---

### Task 1: Add the async snapshot contract — completed

**Files:**
- Modify: `Packages/ProviderMessage/Sources/ProviderMessage/MessageManaging.swift`
- Modify: `Packages/ProviderMessage/Sources/ProviderMessage/DefaultMessageManager.swift`
- Modify: `Packages/PluginMessageManager/Sources/PluginMessageManager/Managers/MessageManager.swift`
- Modify: `Packages/ProviderMessage/Tests/ProviderMessageTests/ProviderMessageTests.swift`
- Modify: `Packages/PluginMessageManager/Tests/PluginMessageManagerTests/MessageManagerTests.swift`

Add `messagesSnapshot(in:) async` and verify it includes pending messages and eventually reflects persisted messages without changing the synchronous compatibility API.

### Task 2: Migrate chat list reads — completed

**Files:**
- Modify: `Packages/PluginMessageList/Sources/PluginMessageList/ViewModels/ListV1ViewModel.swift`
- Modify: `Packages/PluginMessageList/Sources/PluginMessageList/ViewModels/AgentTurnViewModel.swift`

Use the async snapshot in activation, refresh, pagination, and turn projection paths. Keep bounded V2/V3 page reads unchanged.

### Task 3: Migrate auxiliary UI reads — completed

**Files:**
- Modify: `Packages/PluginConversationTitle/Sources/PluginConversationTitle/Services/TitleService.swift`
- Modify: `Packages/PluginConversationContextSize/Sources/PluginConversationContextSize/ContextSizeToolbarView.swift`
- Modify: `Packages/PluginConversationCacheHitRate/Sources/PluginConversationCacheHitRate/CacheHitRateToolbarView.swift`
- Modify: `Packages/PluginConversationSpeed/Sources/PluginConversationSpeed/Observers/SpeedConversationObserver.swift`
- Modify: `Packages/PluginConversationSpeed/Sources/PluginConversationSpeed/Observers/SpeedMessageObserver.swift`
- Modify: `Packages/PluginConversationFork/Sources/PluginConversationFork/ConversationForkButton.swift`
- Modify: `Packages/PluginConversationFork/Sources/PluginConversationFork/ConversationSummarizer.swift`

Ensure utility/status UI work awaits the background snapshot rather than executing a synchronous full read on MainActor.

### Task 4: Migrate AgentLoop reads — completed

**Files:**
- Modify: `Packages/PluginAgentLoop/Sources/PluginAgentLoop/Observers/MessageObserver.swift`
- Modify: `Packages/PluginAgentLoop/Sources/PluginAgentLoop/Managers/AgentLoopProvider+Message.swift`
- Modify: `Packages/PluginAgentLoop/Sources/PluginAgentLoop/Managers/AgentLoopProvider+Turn.swift`
- Modify: `Packages/PluginAgentLoop/Sources/PluginAgentLoop/Managers/AgentLoopProvider+Tool.swift`
- Modify: `Packages/ProviderAgentLoop/Sources/ProviderAgentLoop/DefaultAgentLoopProvider.swift`

Convert async recovery/request paths to await the snapshot. Where a synchronous provider callback needs a read, schedule a MainActor task and preserve event ordering/state guards.

### Task 5: Verify and document remaining synchronous boundaries — completed

Affected production packages build successfully, and the ProviderMessage, PluginMessageManager, PluginMessageList, and PluginAgentLoop test suites pass. The remaining `messages(for:)` calls are confined to tests; the synchronous API remains as a compatibility boundary for callers that cannot yet become async. ProviderAgentLoop production code also builds successfully, while its test target currently has a pre-existing fixture/configuration issue: several `Lumi*` test-only types are unavailable during test compilation.

The next optimization boundary is bounded pagination: introduce an async page API for the remaining synchronous `messagePage` reads if profiling shows they still compete with send/render work.
