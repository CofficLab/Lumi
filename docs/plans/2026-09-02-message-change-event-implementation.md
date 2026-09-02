# Message Change Event Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Let the active chat timeline apply newly inserted messages from an in-memory event payload without immediately querying SwiftData.

**Architecture:** Add a typed, main-actor message-change observer alongside the existing `objectWillChange` publisher. `MessageManager` publishes `.inserted` after the pending buffer is updated; V2/V3 consume current-conversation insertions directly and use the existing tail refresh as a fallback for edits/deletes or missed events.

**Tech Stack:** Swift 6, SwiftUI, Combine, Swift Testing, MainActor-isolated Provider APIs, SwiftData write-behind persistence.

---

### Task 1: Add regression tests — completed

**Files:**
- Modify: `Packages/ProviderMessage/Tests/ProviderMessageTests/ProviderMessageTests.swift`
- Modify: `Packages/PluginMessageManager/Tests/PluginMessageManagerTests/MessageManagerTests.swift`

**Steps:**

1. Add a test that registers a typed observer, inserts a user message, and verifies the observer receives the exact message and conversation ID.
2. Add a test that cancels the typed observer and verifies no later event is delivered.
3. Add a manager-level test that verifies the typed event carries the message at insertion time. The test does not assert that the database is still empty because a fast background queue may legally finish before the assertion.
4. Add a list-level test covering direct insertion and the objectWillChange fallback for a later edit.

### Task 2: Add the typed message-change API — completed

**Files:**
- Modify: `Packages/ProviderMessage/Sources/ProviderMessage/MessageManaging.swift`
- Create or modify the provider message observer handle implementation in the same package.

**Steps:**

1. Define a `MessageChange` Sendable enum with at least `.inserted(Message, conversationID: UUID)`.
2. Define a cancellable `MessageChangeObserverHandle` protocol isolated to MainActor.
3. Add `addMessageChangeObserver(_:)` to `MessageManaging`.
4. Add a no-op default implementation for managers that do not support typed events yet.
5. Run ProviderMessage tests.

### Task 3: Publish insertion events from MessageManager — completed

**Files:**
- Modify: `Packages/PluginMessageManager/Sources/PluginMessageManager/Managers/MessageManager.swift`
- Modify: `Packages/PluginMessageManager/Tests/PluginMessageManagerTests/MessageManagerTests.swift`

**Steps:**

1. Store weak typed observer handles in `MessageManager`.
2. Publish `.inserted` after `pending.enqueue` and before asynchronous persistence.
3. Keep the existing `objectWillChange` and insertion observer behavior for compatibility.
4. Do not perform database reads or writes while publishing the event.
5. Run MessageManager tests, including write-behind tests.

### Task 4: Apply insertion events in V2/V3 — completed

**Files:**
- Modify: `Packages/PluginMessageList/Sources/PluginMessageList/ViewModels/ListV2ViewModel.swift`
- Modify: `Packages/PluginMessageList/Sources/PluginMessageList/ViewModels/ListV3ViewModel.swift`

**Steps:**

1. Subscribe each view model to the typed message-change observer.
2. For a current-conversation insertion, append/merge the message into the retained window without querying SwiftData.
3. Preserve chronological ordering and cap the retained window at its existing maximum.
4. For non-insertion changes, keep the existing `refreshTail()` fallback in the ViewModel.
5. Consume the matching `objectWillChange` fallback in the ViewModel so the View does not issue a duplicate tail refresh.
6. Keep streaming-row and activity-row behavior unchanged.
7. Run MessageList tests and compile the affected packages.

### Task 5: Verify and measure — completed

**Files:**
- Modify tests only if required by discovered behavior.

**Steps:**

1. Run ProviderMessage, PluginMessageManager, and PluginMessageList test suites; all passed.
2. Run the full relevant package test suite if the workspace build permits it.
3. Inspect the diff for accidental changes to persistence ordering or AgentLoop behavior.
4. Existing write-behind tests verify that user/assistant messages remain readable immediately and eventually persist; the new list test verifies immediate row application.
5. Record the remaining follow-up work: asynchronous pagination and removal of MainActor full-history reads.
