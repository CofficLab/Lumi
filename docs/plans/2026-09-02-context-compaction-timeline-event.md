# Context Compaction Timeline Event Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** 在 Lumi 的消息列表中持久化展示“对话已压缩”次要事件，同时保证事件本身不进入 LLM 上下文。

**Architecture:** 复用现有 `Message` 持久化与消息列表刷新链路，新增带 `renderKind == "context-compaction"` 的系统时间线事件。`PluginLLMContext` 仅在摘要成功保存后写入事件，并在准备 LLM 历史时过滤事件；`PluginMessageRenderer` 提供低强调样式，V1 额外把无 turnID 的事件合并到独立列表行，V2/V3 沿用普通历史行分发。

**Tech Stack:** Swift 6、SwiftUI、SwiftPM、SwiftData、KernelCore SuperPlugin、ProviderMessage、ProviderMessageRendering。

---

### Task 1: Add the persisted event contract

**Files:**
- Modify: `Packages/PluginLLMContext/Sources/PluginLLMContext/LLMContextProvider.swift`
- Test: `Packages/PluginLLMContext/Tests/PluginLLMContextTests/LLMContextPluginTests.swift`

1. Add stable event metadata/render-kind constants and a predicate for identifying timeline events.
2. Filter context events before threshold checks, summary generation, and latest-message validation.
3. After a summary is successfully saved, insert one persisted system event with the current timestamp and compaction metadata.
4. Test that the event is inserted after successful compaction and excluded from the next LLM history.

### Task 2: Render the event as a secondary message

**Files:**
- Create: `Packages/PluginMessageRenderer/Sources/PluginMessageRenderer/Renderers/ContextCompactionMessageView.swift`
- Modify: `Packages/PluginMessageRenderer/Sources/PluginMessageRenderer/MessageRendererPlugin.swift`
- Test: `Packages/PluginMessageRenderer/Tests/PluginMessageRendererTests/MessageRendererPluginTests.swift`

1. Register a renderer for `context-compaction` before the normal system renderer.
2. Use a compact, low-contrast timeline presentation with an icon and secondary typography.
3. Register/unregister the renderer with the existing plugin lifecycle.
4. Test routing for the new render kind.

### Task 3: Support the event in V1's turn-aggregated list

**Files:**
- Modify: `Packages/PluginMessageList/Sources/PluginMessageList/Models/ListV1Presentation.swift`
- Modify: `Packages/PluginMessageList/Sources/PluginMessageList/ViewModels/ListV1ViewModel.swift`
- Modify: `Packages/PluginMessageList/Sources/PluginMessageList/Views/V1/ListV1View.swift`
- Test: `Packages/PluginMessageList/Tests/PluginMessageListTests/*`

1. Add a presentation-row enum that can represent either an AgentTurn or a standalone timeline event.
2. Merge event rows with turns by creation time while retaining existing turn accessors and behavior.
3. Render event rows through `MessageRowView` so all verbosity modes share the same renderer.
4. Include event rows in visible-content and scroll fingerprints.

### Task 4: Verify

Run:

```bash
swift test --package-path Packages/PluginLLMContext
swift test --package-path Packages/PluginMessageRenderer
swift test --package-path Packages/PluginMessageList
```

Then inspect the diff for unrelated changes and run the relevant Factory build/test if package tests pass.
