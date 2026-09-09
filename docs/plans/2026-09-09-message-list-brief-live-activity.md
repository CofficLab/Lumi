# Message List Brief Live Activity Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Refactor Brief agent turns into a collapsed process section plus a dedicated live activity view that reports the current LLM or tool action without exposing full reasoning or raw tool output.

**Architecture:** Keep the existing `AgentTurnMessageProjection` for user message, process messages, and terminal reply. Replace the synthetic status `Message` used for live activity with a typed `AgentActivityProjection`, derived from streaming stage and `ConversationStateSnapshot`. Register the Brief plugin for conversation-state changes so tool-job lifecycle updates reach the active turn immediately. Render the projection with a dedicated SwiftUI activity component at the conversation tail.

**Tech Stack:** Swift 6, SwiftUI, ProviderMessageStreaming, ProviderConversationState, ProviderToolManager, Swift Testing.

---

### Task 1: Add typed activity projection and pure mapping tests

**Files:**
- Create: `Packages/PluginMessageListBrief/Sources/PluginMessageListBrief/Models/AgentActivityProjection.swift`
- Modify: `Packages/PluginMessageListBrief/Sources/PluginMessageListBrief/ViewModels/AgentTurnViewModel.swift`
- Test: `Packages/PluginMessageListBrief/Tests/PluginMessageListBriefTests/AgentActivityProjectionTests.swift`

1. Define the small UI-facing phase model: sending, thinking, generating, executing tool, waiting for user.
2. Map `ConversationStateSnapshot` first for tool/waiting phases, then fall back to `MessageStreamingStage` for LLM phases.
3. Include a stable title and optional detail, but no reasoning content or tool output.
4. Write tests for thinking, generation, a concrete tool description, multiple running jobs, waiting for user, and idle.
5. Run `swift test --package-path Packages/PluginMessageListBrief` and expect the new mapping tests to pass.

### Task 2: Wire Brief to conversation-state updates

**Files:**
- Modify: `Packages/PluginMessageListBrief/Sources/PluginMessageListBrief/PluginMessageListBriefPlugin.swift`
- Modify: `Packages/PluginMessageListBrief/Sources/PluginMessageListBrief/ViewModels/ListV1ViewModel.swift`
- Modify: `Packages/PluginMessageListBrief/Sources/PluginMessageListBrief/ViewModels/AgentTurnViewModel.swift`

1. Retain a `ConversationStateObserverHandle` in the plugin.
2. Forward updates for the selected conversation to `ListV1ViewModel`.
3. Refresh only the active turn view model for activity-only changes, while preserving the existing message and pagination behavior.
4. Make the per-turn projection read the conversation state and typed activity projection.
5. Add/update tests so a state change updates the activity projection without adding a status message to the process section.

### Task 3: Replace the generic status row with a dedicated activity view

**Files:**
- Create: `Packages/PluginMessageListBrief/Sources/PluginMessageListBrief/Views/AgentActivityView.swift`
- Modify: `Packages/PluginMessageListBrief/Sources/PluginMessageListBrief/Views/AgentTurnView.swift`
- Modify: `Packages/PluginMessageListBrief/Sources/PluginMessageListBrief/Views/ListV1View.swift` only if layout integration requires it

1. Render a compact special view with an activity icon, animated progress indicator, title, optional detail, and elapsed time where applicable.
2. Keep the process disclosure above it and default the disclosure to collapsed.
3. Show the activity view only for the current live turn; remove the generic status-message path.
4. Keep the existing stop action for an active turn, and do not add controls for raw output or reasoning.
5. Build the package and manually inspect the SwiftUI layout through the app if available.

### Task 4: Verify lifecycle and regressions

**Files:**
- Modify: `Packages/PluginMessageListBrief/Tests/PluginMessageListBriefTests/AgentTurnViewModelTests.swift` if needed
- Modify: `docs/plans/2026-09-09-message-list-brief-live-activity.md` only for implementation deviations

1. Run `swift test --package-path Packages/PluginMessageListBrief`.
2. Run `swift test --package-path Packages/ProviderConversationState` and `swift test --package-path Packages/ProviderMessageStreaming` if affected by compile changes.
3. Run `git diff --check`.
4. Build the Lumi Debug scheme when package tests are clean.
5. Confirm the final behavior: process summaries/tool calls remain folded, live status updates through thinking/tool/waiting/generating, and no reasoning body or raw tool output is rendered in Brief.
