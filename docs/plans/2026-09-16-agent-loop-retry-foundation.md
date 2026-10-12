# Agent Loop Retry Foundation Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** 为未来的 AgentLoop 自动重试插件建立结构化失败、并发安全的重试入口和可持久化时间线事件基础。

**Architecture:** 保留现有 `AgentLoopEvent.failed` 以兼容已有消费者，在 `AgentLoopProviding` 增加失败详情查询和带失败回合 ID 校验的 `retryTurn` 接口。时间线消息继续由 `Message` 表示，但由 `MessageTimelineEvent` 统一声明并在 LLM 上下文层过滤，确保 UI 可见、模型不可见。

**Tech Stack:** Swift 6、Swift Concurrency、KernelCore、ProviderAgentLoop、ProviderMessage、ProviderLLMContext、Swift Testing。

---

### Task 1: 建立结构化失败模型

**Files:**
- Create: `Packages/ProviderAgentLoop/Sources/ProviderAgentLoop/AgentLoopFailure.swift`
- Modify: `Packages/ProviderAgentLoop/Sources/ProviderAgentLoop/AgentLoopProviding.swift`
- Test: `Packages/ProviderAgentLoop/Tests/ProviderAgentLoopTests/ProviderAgentLoopTests.swift`

**Steps:**

1. 为网络、限流、服务端、流中断、解析、鉴权、配置、上下文超限和未知错误定义稳定分类。
2. 保存原始可读原因、供应商、模型和 HTTP 状态码，并提供 `isRetryable`。
3. 从 `KitLLM.VendorAPIError` 映射结构化失败；未知错误默认不可重试。
4. 为映射和重试判定补充测试。

### Task 2: 增加安全的 AgentLoop 失败查询与重试入口

**Files:**
- Modify: `Packages/ProviderAgentLoop/Sources/ProviderAgentLoop/AgentLoopProviding.swift`
- Modify: `Packages/PluginAgentLoop/Sources/PluginAgentLoop/AgentTurnFSM.swift`
- Modify: `Packages/PluginAgentLoop/Sources/PluginAgentLoop/Managers/AgentLoopManager.swift`
- Modify: `Packages/PluginAgentLoop/Sources/PluginAgentLoop/Managers/AgentLoopProvider+Turn.swift`
- Modify: `Packages/ProviderAgentLoop/Sources/ProviderAgentLoop/DefaultAgentLoopProvider.swift`
- Test: `Packages/PluginAgentLoop/Tests/PluginAgentLoopTests/PluginAgentLoopTests.swift`

**Steps:**

1. 为 `AgentLoopProviding` 增加默认兼容的 `lastFailure(for:)` 和 `retryTurn(in:after:)`。
2. 让 `TurnRuntime` 保留最近一次结构化失败，并在新回合开始时清除。
3. 让真实 `AgentLoopManager` 只接受仍处于失败终态、且失败回合 ID 匹配的重试请求。
4. 在最终 LLM 失败时保存结构化失败详情，同时保持现有错误消息和 `.failed` 事件不变。
5. 测试成功重试、旧回合 ID 被拒绝、正在运行时被拒绝和失败详情可查询。

### Task 3: 建立通用 AgentLoop 重试时间线事件

**Files:**
- Modify: `Packages/ProviderMessage/Sources/ProviderMessage/MessageTimelineEvents.swift`
- Modify: `Packages/PluginLLMContext/Sources/PluginLLMContext/LLMContextProvider.swift`
- Create: `Packages/PluginMessageRenderer/Sources/PluginMessageRenderer/Renderers/AgentLoopRetryMessageView.swift`
- Modify: `Packages/PluginMessageRenderer/Sources/PluginMessageRenderer/MessageRendererPlugin.swift`
- Test: `Packages/ProviderMessage/Tests/ProviderMessageTests/ProviderMessageTests.swift`
- Test: `Packages/PluginLLMContext/Tests/PluginLLMContextTests/LLMContextPluginTests.swift`
- Test: `Packages/PluginMessageRenderer/Tests/PluginMessageRendererTests/MessageRendererPluginTests.swift`

**Steps:**

1. 增加 `agent-loop-retry` 事件标识和 attempt、max attempts、reason、provider、model、HTTP 状态码等元数据键。
2. 增加通用的 `isTimelineEvent` 判断，保留现有上下文压缩兼容行为。
3. 修改 LLM 历史筛选，让所有仅用于 UI 时间线的消息都不会进入模型上下文。
4. 增加与上下文压缩一致的低干扰时间线渲染器。
5. 测试新事件可识别、可渲染，且不会污染发送给 LLM 的历史。

### Task 4: 验证基础层

**Steps:**

1. 运行 `swift test --package-path Packages/ProviderAgentLoop`。
2. 运行 `swift test --package-path Packages/PluginAgentLoop`。
3. 运行 `swift test --package-path Packages/ProviderMessage`。
4. 运行 `swift test --package-path Packages/PluginLLMContext`。
5. 运行 `swift test --package-path Packages/FactoryLumi`，确认生产装配未改变。
6. 执行 `git diff --check`。
