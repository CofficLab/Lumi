# Agent Loop Tool-Call Recovery Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Prevent malformed or truncated streaming tool calls from terminating an Agent Loop, and make the loop retry or pause with recoverable state.

**Architecture:** Harden the OpenCode Go streaming accumulator so it buffers tool-call deltas, propagates parser errors, and rejects streams without an explicit terminator. Add a recoverable tool-call validation path in AgentLoop that feeds a structured correction back to the model with a bounded retry budget instead of transitioning directly to failed. Preserve existing successful tool execution and authorization behavior.

**Tech Stack:** Swift 6, Swift Testing, Swift Package Manager, KitLLM, PluginAgentLoop, PluginLLMProviderOpenCode.

---

### Task 1: Add regression coverage for incomplete OpenCode streams

**Files:**
- Modify: `Packages/PluginLLMProviderOpenCode/Tests/PluginLLMProviderOpenCodeTests/OpenCodeProviderPluginTests.swift`
- Modify: `Packages/PluginLLMProviderOpenCode/Sources/PluginLLMProviderOpenCode/Providers/GoProvider.swift` only if test visibility requires it

**Steps:**
1. Add a test fixture that emits fragmented OpenAI-compatible SSE tool-call chunks without a terminal event.
2. Assert the provider reports an incomplete-stream error rather than returning malformed tool arguments.
3. Add a fixture with an explicit finish event and fragmented arguments; assert the final tool call is reconstructed.
4. Run the focused OpenCode provider tests and confirm the new incomplete-stream test fails before implementation.

### Task 2: Harden the OpenCode Go streaming path

**Files:**
- Modify: `Packages/PluginLLMProviderOpenCode/Sources/PluginLLMProviderOpenCode/Providers/GoProvider.swift`
- Test: `Packages/PluginLLMProviderOpenCode/Tests/PluginLLMProviderOpenCodeTests/OpenCodeProviderPluginTests.swift`

**Steps:**
1. Replace the private Go accumulator behavior with the same completion invariants as the shared KitLLM accumulator.
2. Track explicit completion, parser failure, stop reason, and raw stream termination.
3. Propagate parse errors from the SSE callback instead of returning an apparently successful partial response.
4. Never treat the initial empty `arguments` delta as an executable call.
5. Validate reconstructed tool-call arguments before returning the response.
6. Run focused provider tests and verify malformed/incomplete streams fail safely.

### Task 3: Add recoverable tool-call failure to AgentLoop

**Files:**
- Modify: `Packages/PluginAgentLoop/Sources/PluginAgentLoop/AgentTurnFSM.swift`
- Modify: `Packages/PluginAgentLoop/Sources/PluginAgentLoop/Managers/AgentLoopProvider+Tool.swift`
- Modify: `Packages/PluginAgentLoop/Sources/PluginAgentLoop/Managers/AgentLoopProvider+Turn.swift`
- Test: `Packages/PluginAgentLoop/Tests/PluginAgentLoopTests/PluginAgentLoopTests.swift`

**Steps:**
1. Add a bounded per-turn recovery counter/state for recoverable LLM tool-call failures.
2. Classify malformed arguments and incomplete streams as retryable protocol failures.
3. Append a provider-compatible correction message without persisting malformed assistant tool calls.
4. Re-enter the requesting-LLM phase for the same turn and continue the existing wait/notification path.
5. After the retry budget is exhausted, transition to a recoverable paused/failed state with an actionable error, without leaving a dangling task or continuation.
6. Add reducer and manager tests covering first retry, retry limit, and normal successful completion.
7. Run focused AgentLoop tests.

### Task 4: Verify integration and operational safety

**Files:**
- Modify: `Packages/KitLLM/Tests/KitLLMTests/KitLLMTests.swift` only if shared behavior needs coverage
- Modify: relevant logging code only if required to redact credentials

**Steps:**
1. Run all affected Swift package tests.
2. Build the Lumi macOS target or the existing project build command.
3. Verify no malformed assistant tool call is written to conversation history.
4. Verify a tool-call stream error is visible as recoverable progress rather than an immediate terminal failure.
5. Review logs for API credential redaction and document any remaining configuration recommendation.
