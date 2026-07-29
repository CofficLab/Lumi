# Sub-Agent Delegation MVP Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Restore production registration of `delegate_*` tools, prevent recursive delegation, and add a read-only `explore` sub-agent.

**Architecture:** `BuiltinPluginManager` first registers ordinary plugin tools, snapshots them, then wraps each enabled plugin sub-agent in `SubAgentDelegateTool`. Delegates receive the ordinary-tool snapshot, while `ToolManaging` keeps a separate sub-agent definition registry for UI/debugging and rebuild cleanup.

**Tech Stack:** Swift 6, Swift Package Manager, LumiKernel plugin/tool protocols, Swift Testing.

---

### Task 1: Restore delegate registration

**Files:**
- Modify: `Packages/LumiKernel/Sources/LumiKernel/Managers/BuiltinPluginManager.swift`
- Modify: `Packages/LumiKernel/Sources/LumiKernel/Providers/ToolManaging.swift`
- Modify: `Plugins/ToolManagerPlugin/Sources/ToolManagerPlugin/Services/ToolManagerService.swift`
- Modify: `Packages/LumiKernel/Sources/LumiKernel/Services/ToolService.swift`

Register ordinary tools first, capture them as the delegate snapshot, register definitions, then add one `SubAgentDelegateTool` per enabled definition. Clear definitions during contribution rebuilds.

### Task 2: Add `explore`

**Files:**
- Create: `Plugins/LLMProviderStepFunPlugin/Sources/SubAgents/ExploreAgent.swift`
- Modify: `Plugins/LLMProviderStepFunPlugin/Sources/StepFunPlugin.swift`

Add a read-only StepFun definition with 15 turns and a final response contract containing Summary, Evidence, Findings, and Recommended Next Step.

### Task 3: Verify behavior

**Files:**
- Modify or add tests under `Packages/LumiKernel/Tests/LumiKernelTests/` as needed.
- Modify: `Packages/LumiKernel/Sources/LumiKernel/Types/SubAgentDelegateTool.swift`

Filter every `delegate_*` tool before tag filtering and verify registry persistence plus non-recursive snapshots. Run the relevant Swift package tests and inspect the final diff.
