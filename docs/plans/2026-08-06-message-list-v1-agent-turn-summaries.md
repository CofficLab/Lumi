# Message List V1 AgentTurn Summaries Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Make the brief (V1) message list render one final user-facing response per AgentTurn while preserving live streaming and falling back safely for legacy conversations.

**Architecture:** Persist `turnID` with every message, then build a V1-only projection from paginated `AgentTurnRecord` values plus one batched conversation-message snapshot. Keep the existing message timeline view model for streaming and legacy fallback; V2/V3 remain unchanged.

**Tech Stack:** Swift 6, SwiftUI, SwiftData, Swift Testing, LumiKernel provider protocols.

---

### Task 1: Persist message-to-turn identity

**Files:**
- Modify: `Plugins/MessageManagerPlugin/Sources/Models/MessageModel.swift`
- Modify: `Plugins/MessageManagerPlugin/Sources/Managers/MessageManager.swift`
- Test: `Plugins/MessageManagerPlugin/Tests/MessageStorePaginationTests.swift`

**Steps:**
1. Add a round-trip test proving `LumiChatMessage.turnID` survives insertion and retrieval.
2. Run the focused test and confirm it fails.
3. Add nullable `turnId` storage and map it in both conversion directions.
4. Preserve `turnID` when MessageManager normalizes a mismatched conversation ID.
5. Run MessageManagerPlugin tests and confirm they pass.

### Task 2: Make AgentTurn aggregation efficient and correctly associate failures

**Files:**
- Modify: `Plugins/AgentTurnRunnerPlugin/Sources/AgentTurnRunnerPlugin/Services/AgentTurnRunner.swift`

**Steps:**
1. Load the conversation message snapshot once per turn page instead of once per record.
2. Pass the snapshot into record aggregation.
3. Assign the active `turnID` to provider error messages before persistence.
4. Build AgentTurnRunnerPlugin to verify the changes.

### Task 3: Add the V1 summary projection

**Files:**
- Create: `Plugins/MessageListPlugin/Sources/Models/AgentTurnSummaryItem.swift`
- Create: `Plugins/MessageListPlugin/Sources/Services/AgentTurnSummaryBuilder.swift`
- Create: `Plugins/MessageListPlugin/Sources/ViewModels/MessageListV1ViewModel.swift`
- Test: `Plugins/MessageListPlugin/Tests/MessageListPluginTests/AgentTurnSummaryBuilderTests.swift`

**Steps:**
1. Write tests for completed, tool-process, failed, and missing-message turns.
2. Run the focused tests and confirm they fail.
3. Implement selection precedence: completed final assistant without tool calls, then error, then latest visible assistant.
4. Implement cursor pagination over `AgentTurnManaging.turnRecords`, returning rows oldest-to-newest and using a single message snapshot per refresh.
5. Run MessageListPlugin tests and confirm they pass.

### Task 4: Route V1 rendering through AgentTurn summaries

**Files:**
- Modify: `Plugins/MessageListPlugin/Sources/Views/MessageListV1View.swift`

**Steps:**
1. Add the V1 summary view model alongside the existing timeline view model.
2. Render summary messages when Turn records are available.
3. Keep the existing streaming row as the live tail.
4. Use the existing message timeline when no persisted Turn projection exists.
5. Route “load earlier” through Turn pagination in summary mode.
6. Build and run MessageListPlugin tests.

### Task 5: Final verification

**Files:**
- Verify all modified files.

**Steps:**
1. Run `git diff --check`.
2. Run MessageManagerPlugin tests.
3. Run MessageListPlugin tests.
4. Build AgentTurnRunnerPlugin.
5. Review the final diff for unintended V2/V3 changes and report any unrelated warnings.
