# Context Compaction Timeline Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add a ChatToolbar compaction-history popover that persists the exact provider, model, context window, budget, estimates, and reason for each actual compaction.

**Architecture:** Keep one immutable compaction event as a special persisted `Message` per actual compression. Store provider/model in the message fields and compact diagnostic data in versioned metadata, then derive the selected conversation's timeline from those messages. Register the button from `PluginLLMContext`, use LumiUI theme/tokens for the popover, and keep background summary prewarm invisible.

**Tech Stack:** Swift 6, SwiftUI, SwiftPM, LumiUI, ProviderChatSection, ProviderMessage, existing MessageManager SQLite persistence, Swift Testing.

---

### Task 1: Extend the persisted event contract

**Files:**
- Modify: `Packages/ProviderMessage/Sources/ProviderMessage/MessageTimelineEvents.swift`
- Modify: `Packages/PluginLLMContext/Sources/PluginLLMContext/LLMContextProvider.swift`
- Test: `Packages/PluginLLMContext/Tests/PluginLLMContextTests/LLMContextPluginTests.swift`

Add stable metadata keys and a typed decoding helper for reason, provider, model, context window, effective window, input limit, estimate source, and before/after estimates. Put provider/model directly on the event `Message`; keep optional unknown values absent. Record a schema version and distinguish hard-threshold, emergency, and provider-context-limit retry reasons.

Add tests asserting the event survives the existing MessageManager persistence path and preserves the original model/context snapshot after a later model change.

### Task 2: Correct compaction timing and record reasons

**Files:**
- Modify: `Packages/PluginLLMContext/Sources/PluginLLMContext/LLMContextProvider.swift`
- Modify: `Packages/PluginLLMContext/Tests/PluginLLMContextTests/LLMContextPluginTests.swift`

Keep 70% as background prewarm only. Use an existing summary for normal requests only at the hard threshold, and use emergency mode for forced/context-limit retries. Pass the reason into event recording. Add boundary tests proving a ready summary does not create a timeline event below the hard threshold, while hard and emergency paths do.

### Task 3: Add the toolbar state and popover UI

**Files:**
- Modify: `Packages/PluginLLMContext/Package.swift`
- Modify: `Packages/PluginLLMContext/Sources/PluginLLMContext/LLMContextPlugin.swift`
- Create: `Packages/PluginLLMContext/Sources/PluginLLMContext/ContextCompactionToolbarView.swift`
- Create: `Packages/PluginLLMContext/Sources/PluginLLMContext/ContextCompactionPopover.swift`

Add `ProviderChatSection` and LumiUI dependencies. Register a small trailing ChatToolbar button after existing context metrics. Observe conversation selection and message changes, read only actual compaction events for the selected conversation, and refresh without changing message-list state.

Use LumiUI theme/tokens for the button and a 360–380 point popover. Render an empty state, loading state, and a scrollable vertical timeline. Each row shows time, provider/model, context window, input budget, before/after estimate, and localized reason. Unknown or legacy fields must render as unavailable instead of being inferred from the current model.

### Task 4: Verify integration

**Files:**
- Test: `Packages/PluginLLMContext/Tests/PluginLLMContextTests/LLMContextPluginTests.swift`
- Test: `Packages/PluginMessageListBrief/Tests/PluginMessageListBriefTests/*` if timeline filtering coverage is needed

Run focused PluginLLMContext tests, relevant message persistence tests, and package builds. Confirm unrelated existing worktree changes remain untouched. Manually inspect the toolbar/popover in the macOS app if the app target is available.
