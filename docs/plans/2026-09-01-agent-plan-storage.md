# Agent Plan Storage Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add a native Lumi plugin that gives the Agent dedicated persistent plan-file tools and periodically removes plans older than the retention period.

**Architecture:** Create a sibling Swift Package named `PluginAgentPlanStorage`. Its `SuperPlugin` resolves the shared `StorageProviding` directory, owns an actor-isolated file service, registers four low-risk `SuperAgentTool` implementations with `ToolManagerProviding`, and starts a cancellable background cleanup task. Plan filenames are relative to the plugin-owned `plans` directory and are validated against path traversal before every filesystem operation.

**Tech Stack:** Swift 6, Swift Package Manager, Foundation/FileManager, `KernelCore`, `KitAgentTool`, `ProviderStorage`, `ProviderToolManager`, Swift Testing.

---

### Task 1: Create the package and storage service

**Files:**
- Create: `Packages/PluginAgentPlanStorage/Package.swift`
- Create: `Packages/PluginAgentPlanStorage/Sources/PluginAgentPlanStorage/AgentPlanStoragePlugin.swift`
- Create: `Packages/PluginAgentPlanStorage/Sources/PluginAgentPlanStorage/Services/PlanFileStorageService.swift`
- Create: `Packages/PluginAgentPlanStorage/Sources/PluginAgentPlanStorage/Store/AgentPlanStoragePluginLocalStore.swift`

**Step 1: Define the package.**

Use the same local dependencies as `PluginAgentTempStorage`, expose a `PluginAgentPlanStorage` library, and target macOS 14.

**Step 2: Implement storage boundaries.**

Resolve the plugin directory through `StorageProviding.pluginDataDirectory(for: "AgentPlanStorage")`, use a `plans` child directory, create it on initialization, and reject empty, absolute, `..`, and escaping paths. Read/write UTF-8 text atomically. Expose file metadata and a cleanup method to the tools.

**Step 3: Implement retention configuration.**

Use a UserDefaults-backed retention value with a positive default of 30 days. Cleanup compares each regular file's content modification date with the retention cutoff and ignores directories.

### Task 2: Register Agent tools and lifecycle cleanup

**Files:**
- Create: `Packages/PluginAgentPlanStorage/Sources/PluginAgentPlanStorage/Tools/WritePlanTool.swift`
- Create: `Packages/PluginAgentPlanStorage/Sources/PluginAgentPlanStorage/Tools/ReadPlanTool.swift`
- Create: `Packages/PluginAgentPlanStorage/Sources/PluginAgentPlanStorage/Tools/ListPlansTool.swift`
- Create: `Packages/PluginAgentPlanStorage/Sources/PluginAgentPlanStorage/Tools/DeletePlanTool.swift`

**Step 1: Implement tool schemas.**

Register `write_plan`, `read_plan`, `list_plans`, and `delete_plan`. All tools are low risk and only accept plan-relative names; no tool accepts an arbitrary filesystem path.

**Step 2: Wire plugin lifecycle.**

In `onBoot`, resolve the plugin-owned directory, construct the service, register all tools, run one cleanup, and start a cancellable periodic task. In `onShutdown`, cancel the task, remove the tools, and release the service.

### Task 3: Integrate the plugin into Lumi

**Files:**
- Modify: `Packages/FactoryLumi/Package.swift`
- Modify: `Packages/FactoryLumi/Sources/FactoryLumi/PluginFactory.swift`

Add the local package dependency/product, import `PluginAgentPlanStorage`, and add `AgentPlanStoragePlugin()` near `AgentTempStoragePlugin()` in the default plugin list so the existing tool manager can discover its tools.

### Task 4: Test behavior and integration

**Files:**
- Create: `Packages/PluginAgentPlanStorage/Tests/PluginAgentPlanStorageTests/PluginAgentPlanStorageTests.swift`
- Modify: `Packages/FactoryLumi/Tests/FactoryLumiTests/FactoryLumiTests.swift` only if an explicit factory assertion is needed.

Test stable metadata, exact tool names, low-risk classification, read/write/list/delete behavior in a temporary directory, path traversal rejection, retention cleanup, and default-factory inclusion. Run:

```bash
swift test --package-path Packages/PluginAgentPlanStorage
swift test --package-path Packages/FactoryLumi
```

Expected result: both commands pass without modifying or relying on the user's real plan directory.
