# Risk Approval V1 Chat View Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Show pending high-risk tool approvals in a visible fixed chat area when the selected conversation uses V1/brief verbosity.

**Architecture:** Reuse the existing `ToolApprovalPendingView` and approval bridge for the interaction itself. Add a `ToolManagerEvent`-backed presentation model in `PluginMessageRenderer`, register a `bottomFixed` `ChatSectionItem` for V1, and keep the existing `ToolApprovalRowRenderer` as the V2/V3 path. The fixed item is visible only for the selected brief conversation and is removed after approval or rejection.

**Tech Stack:** Swift 6, SwiftUI, KernelCore providers, ProviderChatSection, ProviderConversation, ProviderToolManager, Swift Testing.

---

### Task 1: Add V1 approval presentation state

**Files:**
- Create: `Packages/PluginMessageRenderer/Sources/PluginMessageRenderer/RiskApprovalChatSection.swift`
- Modify: `Packages/PluginMessageRenderer/Sources/PluginMessageRenderer/ToolApprovalRowRenderer.swift`

**Steps:**
1. Add a main-actor observable model that stores pending approvals keyed by conversation and observes tool-manager authorization/completion events plus conversation selection and verbosity changes.
2. Add a pure visibility predicate covering brief verbosity, selected conversation matching, and a pending approval.
3. Reuse the existing approval request decoding and pending approval view from both the fixed V1 item and V2/V3 row renderer.

### Task 2: Register the V1 fixed chat item

**Files:**
- Modify: `Packages/PluginMessageRenderer/Package.swift`
- Modify: `Packages/PluginMessageRenderer/Sources/PluginMessageRenderer/MessageRendererPlugin.swift`

**Steps:**
1. Add the `ProviderChatSection` dependency.
2. Create and retain the approval chat view model during plugin boot.
3. Register a bottom-fixed item and remove it, canceling observers, during plugin shutdown.

### Task 3: Add regression coverage

**Files:**
- Modify: `Packages/PluginMessageRenderer/Tests/PluginMessageRendererTests/MessageRendererPluginTests.swift`

**Steps:**
1. Test V1 visibility and hiding for standard verbosity or another selected conversation.
2. Test authorization-required events create pending state and authorized completion clears it.
3. Test plugin boot registers and shutdown removes the fixed chat item.
4. Run focused package tests and then `git diff --check`.

The feature files can be committed independently; unrelated pre-existing worktree changes must remain unstaged.
