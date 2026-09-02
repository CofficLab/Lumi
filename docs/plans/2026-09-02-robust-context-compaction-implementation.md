# Robust Context Compaction Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Replace fixed message-count compaction with a model-aware, token-budgeted context preparation flow that prewarms safely, compacts before overflow, supports rolling summaries, and degrades deterministically.

**Architecture:** Extend `ProviderLLMContext` with a request containing resolved provider/model and request budget. `PluginLLMContext` owns estimation, threshold policy, per-conversation summary state, rolling summary generation, and fallback truncation. `PluginAgentLoop` resolves tools before context preparation and reports actual usage/context-limit failures.

**Tech Stack:** Swift 6 SwiftPM, SwiftUI-independent provider contracts, Swift Testing, existing `KernelCore`, `ProviderMessage`, `ProviderConversation`, `ProviderLLMManager`, and `KitLLM` models.

---

### Task 1: Add context budget and estimator contracts

**Files:**
- Modify: `Packages/ProviderLLMContext/Sources/ProviderLLMContext/LLMContextProviding.swift`
- Create: `Packages/ProviderLLMContext/Sources/ProviderLLMContext/LLMContextBudget.swift`
- Test: `Packages/ProviderLLMContext/Tests/ProviderLLMContextTests/ProviderLLMContextTests.swift`

Define request mode, budget, preparation request/result metadata, and a conservative token estimator protocol. Preserve the old protocol method as a compatibility path for existing test providers.

### Task 2: Reorder AgentLoop context preparation

**Files:**
- Modify: `Packages/PluginAgentLoop/Sources/PluginAgentLoop/Managers/AgentLoopProvider+Tool.swift`
- Modify: `Packages/ProviderLLMContext/Sources/ProviderLLMContext/LLMContextProviding.swift`
- Test: `Packages/PluginAgentLoop/Tests/PluginAgentLoopTests/*`

Resolve conversation provider/model and tool schemas before context preparation, pass their token reserve into the context provider, and expose a bounded context-limit recovery callback without changing normal request behavior.

### Task 3: Implement budget-based policy and rolling compaction

**Files:**
- Modify: `Packages/PluginLLMContext/Sources/PluginLLMContext/LLMContextProvider.swift`
- Modify: `Packages/PluginLLMContext/Sources/PluginLLMContext/LLMContextPlugin.swift`
- Modify: `Packages/PluginLLMContext/Sources/PluginLLMContext/ContextSummaryStore.swift`
- Test: `Packages/PluginLLMContext/Tests/PluginLLMContextTests/LLMContextPluginTests.swift`

Replace the 40-message hard gate with soft/hard/emergency thresholds, bind state to conversation revision/provider/model, generate rolling summaries, await compaction at the hard threshold, and use deterministic token-bounded truncation when summarization fails.

### Task 4: Add usage calibration and recovery reporting

**Files:**
- Modify: `Packages/PluginAgentLoop/Sources/PluginAgentLoop/Managers/AgentLoopProvider+Tool.swift`
- Modify: `Packages/PluginLLMContext/Sources/PluginLLMContext/LLMContextProvider.swift`
- Test: `Packages/PluginLLMContext/Tests/PluginLLMContextTests/LLMContextPluginTests.swift`

Feed successful `inputTokenCount` values back into the estimator calibration and handle one context-limit recovery attempt after emergency compaction.

### Task 5: Verify integration and user-visible timeline behavior

**Files:**
- Modify: `Packages/PluginMessageList/Tests/PluginMessageListTests/*` only if coverage is missing

Run package tests for `ProviderLLMContext`, `PluginLLMContext`, `PluginAgentLoop`, `PluginMessageList`, and `FactoryLumi`. Confirm existing user localization changes remain unstaged and unrelated.
