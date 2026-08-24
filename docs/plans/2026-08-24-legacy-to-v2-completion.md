# Lumi Legacy-to-V2 Completion Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Replace every production Lumi legacy capability with a verified KernelCore/FactoryLumi implementation, then remove the legacy architecture without any user-visible regression or data loss.

**Architecture:** `FactoryLumi` remains the only production composition root. Each old `LumiPlugin` becomes a `Plugin*` package that consumes Provider contracts and preserves its stable plugin ID, data location, commands, menu entries, and user-facing surfaces. Cross-plugin behavior belongs in providers or integration packages; legacy packages remain until their replacement passes all gates.

**Tech Stack:** Swift 6, SwiftUI/AppKit, Swift Package Manager, Xcode, KernelCore, Provider packages, FactoryLumi, Swift Testing.

---

## Baseline and deletion gate

- Production baseline is `LumiApp` + `FactoryLumi` + `KernelLumi` plus the two host-injected packages (`AppUpdatePlugin`, `ProjectRAGPlugin`).
- Current authoritative inventory is [lumi-v2-plugin-migration-ledger.json](../lumi-v2-plugin-migration-ledger.json); it must be refreshed from source before deletion because its `generatedAt` is 2026-08-16 and the implementation has moved since then.
- `FactoryLumi` currently instantiates 137 production plugin types. `FactoryLumi` currently instantiates 88 V2 plugin types, including the recently migrated `ProjectRAGSuperPlugin`.
- A legacy package is eligible for deletion only when its V2 replacement has: matching stable ID and data keys; feature/interaction tests; package and integration builds; UI/accessibility comparison for visible surfaces; and an entry in the migration ledger with evidence.
- `FactoryLumi`, `FactoryCore`, and `KernelLumi` are deleted only after all production consumers (including the specialist apps) use V2 composition roots and a clean `rg` finds no production imports or Xcode package references.

### Task 1: Refresh the machine-readable migration ledger

**Files:**
- Modify: `docs/lumi-v2-plugin-migration-ledger.json`
- Test: source-derived inventory command

**Step 1:** Extract current `FactoryLumi` instantiated plugin types and `FactoryLumi` instantiated `SuperPlugin` types.

**Step 2:** For every production legacy package, record one of: `replaced`, `merged`, `host-owned`, or `missing`; do not mark a package complete merely because a similarly named V2 package exists.

**Step 3:** Record stable plugin ID, storage/UserDefaults/Keychain keys, commands, menus, settings, tools, background work, UI surfaces, and provider dependencies.

**Step 4:** Add a testable deletion-gate evidence object for every `replaced` or `merged` package.

### Task 2: Remove the direct old AppUpdatePlugin dependency

**Files:**
- Create: `Packages/PluginAppUpdate/Package.swift`
- Create: `Packages/PluginAppUpdate/Sources/PluginAppUpdate/*`
- Create: `Packages/PluginAppUpdate/Tests/PluginAppUpdateTests/*`
- Modify: `LumiApp/LumiApp.swift`
- Modify: `Lumi.xcodeproj/project.pbxproj`
- Test: `swift test --package-path Packages/PluginAppUpdate`

**Step 1:** Port the Sparkle service, feed detector, notification bridge, and state machine without changing feed URLs or notification raw values.

**Step 2:** Replace the old `KernelLumi.NetworkProviding` dependency with `ProviderNetwork.NetworkProviding` and preserve the background reachability probe behavior.

**Step 3:** Update `LumiMinimalApp` imports and Xcode package product references to the V2 package.

**Step 4:** Verify that update checks remain reachable from the application menu and menu-bar popover, then remove `Plugins/AppUpdatePlugin` only after all consumers have moved.

### Task 3: Complete core chat, workspace, and editor migration waves

**Files:**
- Modify/Create: `Packages/ProviderWorkspace`, `Packages/ProviderMessageStreaming`, `Packages/ProviderMessageRendering`, `Packages/ProviderConversationInput`, `Packages/ProviderAgentLoop`
- Create/Modify: corresponding `Packages/Plugin*` packages

**Step 1:** Migrate user-visible main-window surfaces before deleting `EditorHostPlugin`, `EditorPanelPlugin`, `ProjectFilesPlugin`, `ProjectFileTreePlugin`, `TerminalPlugin`, or `WorkspacePlugin`.

**Step 2:** Migrate the full message lifecycle (attachments, streaming, tools, errors, reasoning, resend) before deleting old conversation/message plugins.

**Step 3:** Add fixture-based UI, accessibility, and persistence migration tests for each surface.

### Task 4: Complete product feature and system integration waves

**Files:**
- Create/Modify: V2 packages for remaining P5/P6/P7 plugins and provider/integration contracts as needed

**Step 1:** Migrate LLM providers and their persisted credentials/configuration.

**Step 2:** Migrate developer tools, project utilities, designer apps, system integrations, and menu/status-bar contributions.

**Step 3:** Convert specialist apps (`AppIconDesignerApp`, `CADDesignerApp`, `DatabaseManagerApp`) from `FactoryLumi.configuration(...)` to V2-specific composition roots.

### Task 5: Final compatibility and deletion

**Files:**
- Remove: `LumiApp/LumiApp.swift`, `Packages/FactoryLumi`, `Packages/FactoryCore`, `Packages/KernelLumi`, verified legacy `Plugins/*`
- Modify: `Lumi.xcodeproj/project.pbxproj`, documentation, package references

**Step 1:** Run the ledger deletion gate for every old package and resolve every missing evidence item.

**Step 2:** Run clean Debug and Release `xcodebuild` builds and the V2 package test suite.

**Step 3:** Search for legacy imports/references, then delete only explicit verified targets and rebuild from a clean package graph.

**Step 4:** Compare the old/new UI fixtures, data migration fixtures, commands, and external-open flows; document the final evidence before removing the legacy source tree.
