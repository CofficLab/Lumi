# Ask User V1 Chat View Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Show the pending `ask_user` question and answer controls in the chat area when the selected conversation uses V1/brief verbosity.

**Architecture:** `PluginAskUser` owns a small observable presentation model that listens to agent-loop suspension events and conversation selection/verbosity changes. It registers a `ChatSectionItem` in the fixed chat area and renders the existing ask-user interaction UI from the suspension payload. The existing tool-call row renderer remains responsible for V2/V3, while the V1 chat item is empty unless a matching `userInput` suspension is active.

**Tech Stack:** Swift 6, SwiftUI, KernelCore providers, ProviderAgentLoop, ProviderChatSection, Swift Testing.

---

### Task 1: Add the ask-user chat presentation state and view

**Files:**
- Create: `Packages/PluginAskUser/Sources/PluginAskUser/AskUserChatSection.swift`
- Modify: `Packages/PluginAskUser/Sources/PluginAskUser/AskUserRowRenderer.swift`

**Step 1: Write the failing tests**

Add pure presentation tests for decoding a `userInput` suspension payload and for hiding the view when the suspension kind is not `userInput`.

**Step 2: Run the focused tests**

Run: `swift test --package-path Packages/PluginAskUser --filter AskUserPluginTests`

Expected: FAIL because the V1 chat presentation state does not exist yet.

**Step 3: Implement the minimal state/view**

Create an `@MainActor` observable model that stores the selected conversation, current verbosity, and decoded pending response. Add synchronization from `AgentLoopProviding.suspension(for:)`, selected-conversation events, verbosity events, and agent-loop events. Register a bottom-fixed `ChatSectionItem` from `AskUserPlugin`, returning an empty view unless verbosity is `.brief` and the suspension is a `userInput` suspension. Extract the current private interaction view into a reusable plugin-local view so both V1 chat content and the V2/V3 row renderer share the same submit behavior.

**Step 4: Run the focused tests**

Run: `swift test --package-path Packages/PluginAskUser --filter AskUserPluginTests`

Expected: PASS.

### Task 2: Wire lifecycle and dependencies

**Files:**
- Modify: `Packages/PluginAskUser/Package.swift`
- Modify: `Packages/PluginAskUser/Sources/PluginAskUser/AskUserPlugin.swift`

**Step 1: Add ProviderChatSection dependency**

Add the local package and product dependency needed to register a chat item.

**Step 2: Wire plugin boot/shutdown**

Resolve `ChatSectionProviding`, `ConversationManaging`, and `AgentLoopProviding`; create and retain the presentation model; register the chat item and all observers on boot; cancel observers and remove the item on shutdown.

**Step 3: Verify package compilation**

Run: `swift build --package-path Packages/PluginAskUser`

Expected: BUILD SUCCEEDED.

### Task 3: Verify behavior and regression coverage

**Files:**
- Modify: `Packages/PluginAskUser/Tests/PluginAskUserTests/PluginAskUserTests.swift`

**Step 1: Add lifecycle/state regression tests**

Cover V1 visibility, V2/V3 invisibility, suspension payload decoding, and clearing after completed/cancelled agent-loop events. Preserve existing tool execution and resume tests.

**Step 2: Run focused package tests**

Run: `swift test --package-path Packages/PluginAskUser`

Expected: PASS.

**Step 3: Run the related renderer/list tests**

Run: `swift test --package-path Packages/PluginMessageRenderer` and `swift test --package-path Packages/PluginMessageListBrief`

Expected: PASS, confirming V1 message folding and V2/V3 custom rendering remain unchanged.

**Step 4: Inspect the final diff**

Run: `git diff --check` and `git status --short`

Expected: no whitespace errors; only the ask-user implementation and plan changes are introduced on top of the pre-existing worktree changes.
