# Provider Observation Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Make mutable kernel Provider state observable and add typed conversation domain events for consumers that need precise updates.

**Architecture:** State-oriented UI Providers will expose `ObservableObject` at the protocol boundary so existential consumers can observe changes. `ConversationManaging` will retain its existing selection observer and add a typed event stream for conversation lifecycle and preference changes, keeping event semantics separate from coarse UI invalidation.

**Tech Stack:** Swift 6, SwiftUI, Combine, local Swift packages, XCTest/Swift Testing.

---

### Task 1: Add typed conversation events

**Files:**
- Create: `Packages/ProviderConversation/Sources/ProviderConversation/ConversationObservation.swift`
- Modify: `Packages/ProviderConversation/Sources/ProviderConversation/ConversationManaging.swift`
- Modify: `Packages/ProviderConversation/Sources/ProviderConversation/DefaultConversationManager.swift`
- Test: `Packages/ProviderConversation/Tests/ProviderConversationTests/ProviderConversationTests.swift`

Add lifecycle, selection, activity, provider/model, and preference events with cancellable observer handles. Emit only after an effective state change, preserving existing selection observer behavior.

### Task 2: Expose observable state at UI Provider boundaries

**Files:**
- Modify: `ActivityBarProviding.swift`, `ChatSectionProviding.swift`, `ContentViewProviding.swift`, `DocsViewProviding.swift`, `RailViewProviding.swift`, `RootViewProviding.swift`, `SettingViewProviding.swift`, `ToolbarProviding.swift`
- Modify: corresponding default implementations, adding `ObservableObject` where the implementation currently has mutable state but does not publish it.

Require `ObjectWillChangePublisher == ObservableObjectPublisher` consistently so `any Provider` values can be observed by kernel consumers.

### Task 3: Verify package compatibility

Run focused tests/builds for `ProviderConversation` and all changed Provider packages, then run the repository-required `npm run build:mp-weixin` command and report its result.

### Task 4: Add runtime status observation

**Files:**
- Modify: `Packages/ProviderWebServer/Sources/ProviderWebServer/WebServerProviding.swift`
- Modify: `Packages/ProviderWebServer/Sources/ProviderWebServer/DefaultWebServerProviding.swift`
- Modify: `Packages/ProviderProjectRAG/Sources/ProviderProjectRAG/ProjectRAGProviding.swift`
- Modify: `Packages/PluginProjectRAG/Sources/PluginProjectRAG/ProjectRAGProvider.swift`
- Test: `Packages/ProviderWebServer/Tests/ProviderWebServerTests/DefaultWebServerProvidingTests.swift`

Expose cancellable typed events for server lifecycle/routes and RAG initialization/project/indexing lifecycle while preserving thread isolation.

### Task 5: Observe runtime renderer registration

**Files:**
- Modify: `Packages/ProviderMessageRendering/Sources/ProviderMessageRendering/MessageRenderingProviding.swift`
- Modify: `Packages/ProviderMessageRendering/Sources/ProviderMessageRendering/ToolCallRenderingProviding.swift`

Make message-level and ToolCall-level renderer registration observable so late plugin registration and removal can refresh consumers.
