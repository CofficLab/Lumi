# Tool Call ID Collision Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Prevent provider-reused tool-call IDs from leaving an AgentLoop waiting forever for a result that was attached to an earlier call.

**Architecture:** Normalize tool-call IDs at the AgentLoop boundary, after the provider response is received and before the response is validated, persisted, reduced by the turn FSM, or published to the ToolManager. Existing IDs remain unchanged unless they collide with IDs already present in the prepared conversation history or earlier calls in the same response; collisions receive a generated Lumi-unique ID. Raw provider response fields remain untouched for diagnostics.

**Tech Stack:** Swift 5.9, Swift Testing, `KitLLM`, `PluginAgentLoop`.

---

### Task 1: Add the ID normalization utility and regression tests

**Files:**
- Create: `Packages/PluginAgentLoop/Sources/PluginAgentLoop/Managers/ToolCallIdentityNormalizer.swift`
- Test: `Packages/PluginAgentLoop/Tests/PluginAgentLoopTests/PluginAgentLoopTests.swift`

**Step 1: Write tests**

Cover preserving unique IDs, replacing an ID reused from conversation history, and replacing duplicates within one response while preserving tool names and arguments.

**Step 2: Implement the minimal utility**

Add a pure helper that rebuilds `LLMResponse` with collision-free `LLMToolCall` values while preserving all other response metadata, including raw response data.

**Step 3: Run the focused tests**

Run `swift test --package-path Packages/PluginAgentLoop --filter ToolCallIdentityNormalizer` and expect all normalization tests to pass.

### Task 2: Apply normalization to the active AgentLoop

**Files:**
- Modify: `Packages/PluginAgentLoop/Sources/PluginAgentLoop/Managers/AgentLoopProvider+Tool.swift`

**Step 1: Collect IDs already present in the outgoing history**

Use the persisted `llmHistory` before lifecycle hooks rewrite the request so tool-call and tool-result IDs from the conversation remain part of collision detection.

**Step 2: Normalize the provider response**

Rename the raw streaming result and pass it through the utility before validation, message persistence, lifecycle notification, and return to the turn driver.

**Step 3: Run package tests**

Run `swift test --package-path Packages/PluginAgentLoop` and verify the package passes.

### Task 3: Verify adjacent tool behavior

**Files:**
- No additional source changes expected.

**Step 1: Run ToolManager tests**

Run `swift test --package-path Packages/PluginToolManager` and verify existing same-turn idempotency and cross-turn independence tests remain green.

**Step 2: Inspect the final diff**

Confirm the unrelated `PluginModelSelector` working-tree change is not included and no database files are modified.
