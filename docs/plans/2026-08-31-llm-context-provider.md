# LLM Context Provider Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Introduce a provider capability that owns preparation of messages sent to the LLM, then implement background conversation compaction behind that capability without changing persisted chat history.

**Architecture:** `ProviderLLMContext` defines the neutral `LLMContextProviding` contract. `PluginLLMContext` owns context selection, summary persistence, background refresh, and fallback behavior. `PluginAgentLoop` depends only on the provider contract and never decides whether history is complete or compressed. `MessageManaging` remains the source of truth for the complete conversation.

**Tech Stack:** Swift 6, Swift Package Manager, SwiftData, KernelCore providers, ProviderLifecycleHooks, KitLLM.

---

### Task 1: Add the context-provider contract

**Files:**
- Create: `Packages/ProviderLLMContext/Package.swift`
- Create: `Packages/ProviderLLMContext/Sources/ProviderLLMContext/LLMContextProviding.swift`
- Create: `Packages/ProviderLLMContext/Tests/ProviderLLMContextTests/LLMContextProvidingTests.swift`

**Steps:**
1. Define a `@MainActor` `LLMContextProviding` protocol with one request-facing method that returns `[Message]` for a conversation.
2. Add a minimal pass-through implementation for tests and degraded operation.
3. Add protocol tests that verify the pass-through preserves message order and content.
4. Run `swift test --package-path Packages/ProviderLLMContext`.
5. Commit with `feat(context): add llm context provider contract`.

### Task 2: Route AgentLoop through the provider

**Files:**
- Modify: `Packages/PluginAgentLoop/Package.swift`
- Modify: `Packages/PluginAgentLoop/Sources/PluginAgentLoop/PluginAgentLoop.swift`
- Modify: `Packages/PluginAgentLoop/Sources/PluginAgentLoop/Managers/AgentLoopManager.swift`
- Modify: `Packages/PluginAgentLoop/Sources/PluginAgentLoop/Managers/AgentLoopProvider+Tool.swift`
- Modify: `Packages/PluginAgentLoop/Tests/PluginAgentLoopTests/PluginAgentLoopTests.swift`

**Steps:**
1. Add the provider package dependency and inject an optional/provider-backed context capability into `AgentLoopManager`.
2. Replace the direct LLM history read in `performLLMRequest` with the provider call.
3. Keep a pass-through fallback only at composition/test boundaries, not as context policy in the request path.
4. Add a test double that proves AgentLoop asks the provider for request messages.
5. Run `swift test --package-path Packages/PluginAgentLoop` and commit.

### Task 3: Create the dedicated context plugin

**Files:**
- Create: `Packages/PluginLLMContext/Package.swift`
- Create: `Packages/PluginLLMContext/Sources/PluginLLMContext/LLMContextPlugin.swift`
- Create: `Packages/PluginLLMContext/Sources/PluginLLMContext/LLMContextProvider.swift`
- Create: `Packages/PluginLLMContext/Tests/PluginLLMContextTests/...`
- Modify: `Packages/FactoryLumi/Package.swift`
- Modify: `Packages/FactoryLumi/Sources/FactoryLumi/PluginFactory.swift`

**Steps:**
1. Register the implementation as `LLMContextProviding` from an always-on plugin.
2. Resolve message, conversation, LLM, storage, and lifecycle providers in the plugin.
3. Subscribe to completed turns and schedule coalesced utility-priority background work.
4. Ensure shutdown cancels all scheduled work and unregisters the provider.
5. Add lifecycle and fallback tests, then run the package and app build.

### Task 4: Persist and use rolling summaries

**Files:**
- Create: `Packages/PluginLLMContext/Sources/PluginLLMContext/ContextSummaryModel.swift`
- Create: `Packages/PluginLLMContext/Sources/PluginLLMContext/ContextSummaryStore.swift`
- Modify: `Packages/PluginLLMContext/Sources/PluginLLMContext/LLMContextProvider.swift`
- Modify: `Packages/PluginLLMContext/Tests/PluginLLMContextTests/...`

**Steps:**
1. Store summary text, covered-through message ID, source model/provider, and update time in a plugin-owned SwiftData database.
2. Use the full history only for short conversations or background summary generation; use summary plus a bounded recent tail for long conversations.
3. Preserve complete tool-call turns in the recent tail and never split an active tool exchange.
4. Discard stale background results when newer messages exist.
5. Verify persistence, summary reuse, model changes, failure fallback, and concurrent refresh coalescing.

### Task 5: Reuse the capability from Conversation Fork

**Files:**
- Modify: `Packages/PluginConversationFork/Package.swift`
- Modify: `Packages/PluginConversationFork/Sources/PluginConversationFork/ConversationForkButton.swift`
- Remove or move: `Packages/PluginConversationFork/Sources/PluginConversationFork/ConversationSummarizer.swift`
- Modify: related tests

**Steps:**
1. Route manual conversation fork summarization through the context capability.
2. Preserve the current user-visible fork behavior and local fallback.
3. Remove duplicate summarizer logic only after tests cover both automatic compaction and fork.
4. Run affected package tests and the full Debug app build.

### Verification checklist

- Short conversations still send the same complete messages.
- Long conversations send summary plus recent messages without deleting stored messages.
- Pressing send never waits for a new summary generation request.
- Summary failure never blocks or fails the foreground chat request.
- Tool-call protocol messages remain valid across compaction boundaries.
- Existing unrelated changes in `ProviderContentView` remain untouched.
