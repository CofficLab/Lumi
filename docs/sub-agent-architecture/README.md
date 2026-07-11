# 内核级子 Agent 架构

> 日期：2026-05-24（初稿） / 2026-07-11（方案确认，待实现）
> 状态：方案已确认，待实现
> 涉及范围：LumiCoreKit + LumiPluginRegistry + LumiApp + Plugins

## 背景与动机

### 问题

主 Agent 在执行复杂任务时需要调用多个工具（如 `git_status` → `git_diff` → `git_add` → `git_commit`），每次工具调用都会在对话上下文中增加至少 2 条消息（tool_call + tool_result）。这导致：

1. **上下文窗口膨胀**：10+ 条工具消息消耗大量 token，主 Agent 的可用上下文迅速减少
2. **请求成本增加**：每次 LLM 请求都要携带完整的工具历史，token 成本线性增长
3. **响应变慢**：长上下文导致 LLM 推理时间增加
4. **工具集过大**：主 Agent 拥有所有工具，容易误调用不相关工具

### 现状：MultiAgentPlugin（即将删除）

现有 `MultiAgentPlugin`（`Plugins/MultiAgentPlugin/`）通过 `spawn_agent` + `collect_agents` 两个工具允许主 Agent 在运行时创建子 Agent。它存在多个问题：

- **执行引擎未接线**：`SubAgentRunner.spawn()` 直接把状态置为 `.failed`，写死占位结果 `"Sub-agent execution is not yet wired to the new Lumi chat runtime."`，根本没有真正调用 LLM。
- **默认禁用**：`policy = .disabled`，`PluginService` 初始化时被过滤，工具不会注册。
- **子 Agent 无工具隔离**：设计上暴露 `provider_id`/`model_id` 给 LLM 自由填写，子 Agent 使用所有全局工具。
- **主 Agent 需自行管理 agent_id**：异步 spawn + collect 的两步式 API 增加了编排负担。

**决策：删除 MultiAgentPlugin**，用协议层声明式贡献点替代。

### 目标

将子 Agent 能力从**插件工具**升级为**协议层基础设施**：

| 维度 | 改进目标 |
|------|---------|
| 上下文 | 主 Agent 上下文只增加 2 条消息（delegate 工具调用 + 结果摘要），而非 10+ 条工具调用 |
| 工具隔离 | 每个子 Agent 只能使用其定义中声明的工具子集（`allowedToolNames`） |
| 易用性 | 主 Agent 只需调用 `delegate_<id>` 工具并传入 task，无需配置 provider/model |
| 结果回传 | 子 Agent 的中间 tool_use/tool_result 不进主上下文，只回传最终文本结论 |
| 可扩展 | 任何插件可注册自己的子 Agent（尤其 LLM Provider 插件可注册绑定到自家模型的子 Agent） |

---

## 架构设计

### 对标 Claude Code

本方案参考了 Claude Code（`/Users/angel/Code/Coffic/claude-code-sourcemap`）的子 Agent 设计，其核心原则：

1. **复用同一个推理循环**：子 Agent 跑的是与主 Agent 相同的 `query()` 循环，隔离靠的是隔离的上下文 + 工具白名单 + 独立系统提示，而非另造一套 agent 逻辑。
2. **声明式注册**：插件/用户通过声明式定义（Claude Code 用 `.claude/agents/*.md` 的 YAML frontmatter，我们用 `subAgents(context:)` 贡献点）注册子 Agent。
3. **三层工具控制**：架构性黑名单（防递归）→ 子 Agent 自身 `tools`/`disallowedTools` 声明 → 异步白名单。
4. **只回传文本结论**：子 Agent 的中间 tool_use/tool_result 不进主 Agent 上下文，只有最终 assistant text 回传——这就是上下文压缩的核心机制。

我们的实现与之对应：**声明式贡献点 + 工具白名单 + 自包含 agent loop + 只回传最终文本**。

### 分层

```
┌─────────────────────────────────────────────────────┐
│                    内核层 (LumiCoreKit)               │
│                                                      │
│  1. LumiSubAgentDefinition（子 Agent 定义类型）        │
│  2. SubAgentLoopRunner（自包含 agent loop 引擎）       │
│  3. SubAgentDelegateTool（把定义自动包装成工具）        │
│  4. LumiPlugin.subAgents(context:) 协议贡献点          │
└──────────────────────┬──────────────────────────────┘
                       ↓
┌─────────────────────────────────────────────────────┐
│                    聚合与注册 (LumiApp)                │
│                                                      │
│  PluginService.subAgents(context:)                   │
│  RootContainer.reloadChatPluginContributions()       │
│    → 聚合所有子 Agent 定义                            │
│    → 包装成 SubAgentDelegateTool                      │
│    → 注入到 toolService                               │
└──────────────────────┬──────────────────────────────┘
                       ↓
┌─────────────────────────────────────────────────────┐
│                    插件层 (Plugins)                    │
│                                                      │
│  StepFunPlugin:                                      │
│    subAgents(context:) → git-commit-writer           │
│    (providerID: "stepfun", modelID: "step-3.7-flash")│
│                                                      │
│  其它 LLM Provider 插件可同理注册绑定到自家模型的子 Agent│
└─────────────────────────────────────────────────────┘
```

### 核心组件

#### 1. LumiSubAgentDefinition

子 Agent 的声明式定义，放在 `LumiCoreKit/Sources/SubAgent/`：

```swift
public struct LumiSubAgentDefinition: Sendable, Identifiable {
    /// 全局唯一标识，如 "git-commit-writer"。工具名会变成 "delegate_git-commit-writer"。
    public let id: String

    /// 显示名称，用于 UI/日志
    public let displayName: String

    /// 暴露给主 LLM 的工具描述（告诉主 Agent 何时该调用这个子 Agent）
    public let description: String

    /// 绑定的 LLM provider id（如 "stepfun"）。子 Agent 用这个 provider 推理。
    public let providerID: String

    /// 绑定的模型 id（如 "step-3.7-flash"）。由该 provider 自己决定最合适的模型。
    public let modelID: String

    /// 子 Agent 的 system prompt，引导其行为。
    public let systemPrompt: String

    /// 工具白名单。运行时从全局 toolService.tools 按 name 过滤。
    /// - `["*"]` = 全部工具
    /// - `[]`    = 零工具（纯单次推理）
    /// - 显式列表 = 只保留交集
    public let allowedToolNames: [String]

    /// 最大推理轮数，防失控。默认 10。
    public let maxTurns: Int

    /// 可选图标名
    public let iconName: String?

    public init(
        id: String,
        displayName: String,
        description: String,
        providerID: String,
        modelID: String,
        systemPrompt: String,
        allowedToolNames: [String],
        maxTurns: Int = 10,
        iconName: String? = nil
    ) { ... }
}
```

#### 2. LumiPlugin 协议扩展

在 `LumiPlugin` 协议中新增贡献点，与 `llmProviders(context:)` / `agentTools(context:)` 完全对称：

```swift
public protocol LumiPlugin {
    // ... 现有贡献方法 ...

    /// 插件提供的子 Agent 定义列表。
    ///
    /// 内核会聚合所有插件注册的子 Agent 定义，自动包装成 `delegate_<id>` 工具。
    /// 主 Agent 调用该工具时，内核用定义绑定的 provider+model+systemPrompt
    /// 启动隔离的 agent loop。
    /// 返回空数组表示该插件不提供子 Agent。
    @MainActor
    static func subAgents(context: LumiPluginContext) -> [LumiSubAgentDefinition]
}

extension LumiPlugin {
    @MainActor
    public static func subAgents(context: LumiPluginContext) -> [LumiSubAgentDefinition] { [] }
}
```

#### 3. SubAgentLoopRunner（自包含 agent loop 引擎）

放在 `LumiCoreKit/Sources/SubAgent/`。这是核心——一个**不依赖 ChatService 会话状态**的 agent loop，参照 `ChatService.runAgentTurn` 的三阶段结构（LLM 调用 → turn check → 工具执行），剥离所有 UI/持久化/审批耦合：

```swift
public struct SubAgentLoopResult: Sendable {
    public enum Status: Sendable {
        case completed        // 子 Agent 产出最终文本（无更多工具调用）
        case failed           // LLM 调用出错
        case maxTurnsReached  // 达到最大轮数
    }
    public let content: String   // 最终 assistant 文本（失败时为错误信息）
    public let status: Status
    public let duration: Double
    public let error: String?
}

public actor SubAgentLoopRunner {
    public init() {}

    /// 执行隔离的子 Agent 推理循环。
    ///
    /// - Parameters:
    ///   - provider: 子 Agent 绑定的 LLM provider 实例
    ///   - model: 模型 id
    ///   - systemPrompt: 子 Agent 的系统提示
    ///   - task: 主 Agent 传入的任务描述
    ///   - tools: 已按 allowedToolNames 过滤的工具子集
    ///   - toolService: 工具执行服务（复用主会话的，继承路径白名单/取消机制）
    ///   - conversationID: 复用主会话 ID（工具执行时传入）
    ///   - maxTurns: 最大推理轮数
    /// - Returns: 子 Agent 的最终文本结论
    public func run(
        provider: any LumiLLMProvider,
        model: String,
        systemPrompt: String,
        task: String,
        tools: [any LumiAgentTool],
        toolService: any LumiToolServicing,
        conversationID: UUID,
        maxTurns: Int = 10
    ) async -> SubAgentLoopResult
}
```

**循环逻辑**：

```swift
var messages: [LumiChatMessage] = [
    LumiChatMessage(conversationID: conversationID, role: .system, content: systemPrompt),
    LumiChatMessage(conversationID: conversationID, role: .user, content: task)
]

for iteration in 0..<maxTurns {
    try? Task.checkCancellation()

    // Phase 1: 调 LLM（子 Agent 无 UI，onChunk 丢弃）
    let request = LumiLLMRequest(messages: messages, model: model, tools: tools)
    let assistant: LumiChatMessage
    do {
        assistant = try await provider.sendStreaming(request) { _ in }
    } catch {
        return .failed(error: error.localizedDescription)
    }
    messages.append(assistant)

    // Phase 2: 无工具调用 → 收尾，返回最终文本
    guard let toolCalls = assistant.toolCalls, !toolCalls.isEmpty else {
        return .completed(content: assistant.content)
    }

    // Phase 3: 逐个执行工具，结果回环到局部 messages（不写主上下文）
    for toolCall in toolCalls {
        try? Task.checkCancellation()
        let result = await toolService.execute(toolCall, conversationID: conversationID)
        messages.append(LumiChatMessage(
            conversationID: conversationID,
            role: .tool,
            content: result.content,
            toolCallID: toolCall.id
        ))
    }
}

return .maxTurnsReached(content: messages.last(where: { $0.role == .assistant })?.content ?? "")
```

**V1 简化（有意不支持）**：

| 能力 | V1 处理 | 说明 |
|------|---------|------|
| UI 状态更新（statusState/revision） | 丢弃 | 子 Agent 无界面 |
| 消息持久化 | 不写 ChatStore | 子 Agent 消息只存内存局部数组 |
| 工具审批门（requestToolApproval） | 不触发 | 子 Agent 以 `.auto` 自动执行 |
| 交互式 AskUser 暂停 | 当普通结果文本处理 | 遇到 AskUser marker 不暂停循环 |
| 空响应重试 | 简化 | 首版可不实现，后续按需补 |

#### 4. SubAgentDelegateTool（工具包装器）

放在 `LumiCoreKit/Sources/SubAgent/`。把每个 `LumiSubAgentDefinition` 自动包装成一个 `LumiAgentTool`，对主 LLM 完全透明：

```swift
public struct SubAgentDelegateTool: LumiAgentTool {
    public static let info = LumiAgentToolInfo(
        id: "delegate_subagent",  // 通用占位；实例级 name 覆盖
        displayName: "Delegate Sub-Agent",
        description: "Delegate a task to a registered sub-agent"
    )

    private let definition: LumiSubAgentDefinition
    private let chatService: any LumiChatServicing
    private let toolService: any LumiToolServicing

    public init(definition: LumiSubAgentDefinition,
                chatService: any LumiChatServicing,
                toolService: any LumiToolServicing) { ... }

    // 实例级覆盖协议默认实现
    public var name: String { "delegate_\(definition.id)" }
    public var toolDescription: String { definition.description }

    public var inputSchema: LumiJSONValue {
        .object([
            "type": .string("object"),
            "properties": .object([
                "task": .object([
                    "type": .string("string"),
                    "description": .string("The task for the sub-agent to perform")
                ])
            ]),
            "required": .array([.string("task")])
        ])
    }

    public func riskLevel(...) -> LumiCommandRiskLevel { .low }

    @MainActor
    public func execute(arguments: [String: LumiJSONValue], context: LumiToolExecutionContext) async throws -> String {
        try context.checkCancellation()

        guard let task = arguments["task"]?.stringValue, !task.isEmpty else {
            throw SubAgentError.missingArgument("task")
        }

        // 动态解析 provider（每次取最新，避免插件 reload 后实例过期）
        guard let provider = chatService.provider(forID: definition.providerID) else {
            return "Error: Provider '\(definition.providerID)' not available for sub-agent '\(definition.id)'."
        }

        // 工具白名单过滤
        let tools = resolveTools()

        let runner = SubAgentLoopRunner()
        let result = await runner.run(
            provider: provider,
            model: definition.modelID,
            systemPrompt: definition.systemPrompt,
            task: task,
            tools: tools,
            toolService: toolService,
            conversationID: context.conversationID,
            maxTurns: definition.maxTurns
        )

        return formatResult(result)
    }

    private func resolveTools() -> [any LumiAgentTool] {
        let allTools = toolService.tools
        if definition.allowedToolNames == ["*"] { return allTools }
        if definition.allowedToolNames.isEmpty { return [] }
        let allowed = Set(definition.allowedToolNames)
        return allTools.filter { allowed.contains($0.name) }
    }
}
```

---

## 数据流

```
┌──────────────────────────────────────────────────────────┐
│                    插件注册阶段                            │
│                                                          │
│  StepFunPlugin.subAgents(context:)                       │
│    → [LumiSubAgentDefinition(id: "git-commit-writer",    │
│        providerID: "stepfun", modelID: "step-3.7-flash", │
│        allowedToolNames: ["git_status","git_diff",...])] │
│                                                          │
│  PluginService.subAgents(context:)                       │
│    → enabledPlugins.flatMap { $0.subAgents(context:) }   │
└──────────────┬───────────────────────────────────────────┘
               ↓
┌──────────────────────────────────────────────────────────┐
│              RootContainer.reloadChatPluginContributions  │
│                                                          │
│  每个 definition + chatService + toolService             │
│    → SubAgentDelegateTool(definition:, ...)              │
│  合并到 agentTools → toolService.registerTools(allTools)  │
│                                                          │
│  工具名 "delegate_git-commit-writer" 对主 LLM 可见        │
└──────────────┬───────────────────────────────────────────┘
               ↓
┌──────────────────────────────────────────────────────────┐
│                    运行时：主 Agent 调用                   │
│                                                          │
│  主 Agent LLM: "帮我提交当前变更"                         │
│    → tool_call: delegate_git-commit-writer(task: "...")  │
└──────────────┬───────────────────────────────────────────┘
               ↓
┌──────────────────────────────────────────────────────────┐
│              SubAgentDelegateTool.execute                 │
│                                                          │
│  1. chatService.provider(forID: "stepfun")               │
│       → StepFunProvider 实例                             │
│  2. tools = toolService.tools                            │
│       .filter { allowedToolNames.contains($0.name) }     │
│       → [git_status, git_diff, git_add, git_commit]      │
│  3. SubAgentLoopRunner.run(provider, model, systemPrompt,│
│       task, tools, toolService, conversationID, maxTurns)│
└──────────────┬───────────────────────────────────────────┘
               ↓
┌──────────────────────────────────────────────────────────┐
│         子 Agent（隔离上下文，主 Agent 不可见）             │
│                                                          │
│  System: "你是 Git 提交助手..."                           │
│  User:   "提交当前变更"                                   │
│    ↓                                                     │
│  LLM → tool_call: git_status  → ✅ 有变更（结果回环）      │
│  LLM → tool_call: git_diff    → ✅ 了解内容（结果回环）    │
│  LLM → tool_call: git_add     → ✅ 已暂存（结果回环）      │
│  LLM → tool_call: git_commit  → ✅ abc1234（结果回环）     │
│  LLM → 最终文本: "已成功提交 abc1234"（无 tool_call → 收尾）│
│                                                          │
│  ★ 中间的 4 组 tool_use/tool_result 全在局部数组，        │
│    不进入主 Agent 上下文                                  │
└──────────────┬───────────────────────────────────────────┘
               ↓
┌──────────────────────────────────────────────────────────┐
│              返回主 Agent                                 │
│                                                          │
│  工具结果（delegate_git-commit-writer 的返回值）:         │
│    "已成功提交 abc1234，提交信息: fix: ..."               │
│    ↓                                                     │
│  主 Agent LLM: "已完成提交，hash 是 abc1234"              │
│                                                          │
│  ★ 主上下文只增加了 2 条消息（tool_call + tool_result）    │
│    而非 10+ 条                                           │
└──────────────────────────────────────────────────────────┘
```

---

## 可行性评估：runAgentTurn 的耦合分析

`SubAgentLoopRunner` 的设计基于对 `ChatService.runAgentTurn`（`Packages/LumiChatKit/Sources/ChatService.swift:622-790`）的耦合点分析。该方法共 16 个与 ChatService 状态的接触面，按可剥离性分类：

### 核心循环逻辑（3 个，必须保留）

| # | 触点 | 说明 |
|---|------|------|
| 1 | `messagesByExpandingToolResults`（静态函数） | 消息展开，纯函数，可直接复用 |
| 2 | `turnChecks` + `LumiAgentTurnContext` | turn check 协议，已 Sendable，无 ChatService 耦合 |
| 3 | `toolService.execute(toolCall, conversationID:)` | 工具执行，已注入式 |

### 可剥离的会话/UI 状态（12 个）

| # | 触点 | V1 处理 |
|---|------|---------|
| 4 | `messages(for:)` → `messagesByConversationID` | 改为局部数组 |
| 5 | `prepareSendContext` + `messagesWithConversationPreferences` | 子 Agent 直接用传入的 systemPrompt |
| 6 | `makeAssistantMessage` 中的 provider/model 解析 | 子 Agent 由调用方直接传入 provider+model |
| 7 | `sendStreaming` 的 `onChunk` 回调（驱动 UI） | 丢弃（`{ _ in }`） |
| 8 | `append(...)`（消息存储+持久化） | 改为局部数组 append |
| 9 | `statusState`（UI 状态） | 丢弃 |
| 10 | `incrementRevision()`（SwiftUI 重绘） | 丢弃 |
| 11 | `automationLevel(for:).allowsTools` | 子 Agent 总是允许工具 |
| 12 | `updateToolCallDisplayName/Result`（修改历史消息） | 改为局部数组 append tool 消息 |
| 13 | `requestToolApproval`（审批门） | 不支持，自动执行 |
| 14 | `progressTask`（每秒心跳 UI） | 丢弃 |
| 15 | `LumiAskUserMarkers.isPendingResponse` → `.awaitingUserResponse` | 当普通结果处理 |
| 16 | `language(for:)`（空响应回退） | 简化或跳过 |

### 结论

**核心循环可干净提取**。16 个接触面中 12 个是会话/UI/审批状态，可剥离；3 个是核心逻辑，直接复用。`SubAgentLoopRunner` 维护自己的局部 `[LumiChatMessage]` 数组，从 system+user 播种，append assistant 消息和 tool 结果，最终返回 assistant 文本。

**工作量**：中等。提取 `SubAgentLoopRunner` 本身约 1-2 天（核心循环结构清晰）；完整实现含测试、StepFun PoC、MultiAgentPlugin 删除约 2-3 天。

---

## 改动清单

### 删除：MultiAgentPlugin

| 文件 | 操作 |
|------|------|
| `Plugins/MultiAgentPlugin/`（整个目录） | 删除 |
| `Packages/LumiPluginRegistry/Sources/LumiPluginRegistry.swift:88` | 删 `import MultiAgentPlugin` |
| `Packages/LumiPluginRegistry/Sources/LumiPluginRegistry.swift:299` | 删 `MultiAgentPlugin.self,` |
| `Packages/LumiPluginRegistry/Package.swift:122` | 删 `.package(path: "../../Plugins/MultiAgentPlugin"),` |
| `Packages/LumiPluginRegistry/Package.swift:309` | 删 `.product(name: "MultiAgentPlugin", package: "MultiAgentPlugin"),` |

### 新建：内核基础设施（LumiCoreKit）

| 文件 | 说明 |
|------|------|
| `Packages/LumiCoreKit/Sources/SubAgent/LumiSubAgentDefinition.swift` | 子 Agent 定义类型 |
| `Packages/LumiCoreKit/Sources/SubAgent/SubAgentLoopRunner.swift` | 自包含 agent loop 引擎（actor） |
| `Packages/LumiCoreKit/Sources/SubAgent/SubAgentDelegateTool.swift` | 工具包装器 |
| `Packages/LumiCoreKit/Tests/LumiCoreKitTests/SubAgentDelegateToolTests.swift` | 工具契约 + 工具过滤测试 |
| `Packages/LumiCoreKit/Tests/LumiCoreKitTests/SubAgentLoopRunnerTests.swift` | 循环逻辑测试（maxTurns 截断、无工具调用收尾、工具结果回环） |

### 修改：协议与聚合

| 文件 | 改动 |
|------|------|
| `Packages/LumiCoreKit/Sources/Plugin/LumiPlugin.swift` | 新增 `subAgents(context:)` 协议方法 + 默认空实现 |
| `Packages/LumiCoreKit/Sources/Chat/LumiChatServicing.swift` | 新增 `func provider(forID id: String) -> (any LumiLLMProvider)?` 协议声明（`ChatService` 已实现，仅补协议） |
| `LumiApp/Services/PluginService.swift` | 新增 `func subAgents(context:) -> [LumiSubAgentDefinition]`（flatMap 聚合） |
| `LumiApp/Bootstrap/RootContainer.swift` | `reloadChatPluginContributions()` 中聚合 subAgents，包装为 SubAgentDelegateTool，合并到 agentTools 注册 |

### 修改：StepFun PoC

| 文件 | 改动 |
|------|------|
| `Plugins/LLMProviderStepFunPlugin/Sources/StepFunPlugin.swift` | 新增 `subAgents(context:)`，注册 `git-commit-writer` 子 Agent（无需改 Package.swift） |

StepFun 子 Agent 定义示例：

```swift
@MainActor
public static func subAgents(context: LumiPluginContext) -> [LumiSubAgentDefinition] {
    [
        LumiSubAgentDefinition(
            id: "git-commit-writer",
            displayName: "Git Commit Writer",
            description: "Analyze git changes and create a commit. Pass what you want committed as the task.",
            providerID: "stepfun",
            modelID: "step-3.7-flash",
            systemPrompt: """
                You are a git commit assistant. Steps:
                1. Call git_status to check working tree state.
                2. Call git_diff to review changes.
                3. Generate a Conventional Commits message.
                4. Call git_add to stage, then git_commit to commit.
                If nothing to commit, say so. Don't retry more than twice on failure.
                """,
            allowedToolNames: ["git_status", "git_diff", "git_add", "git_commit"],
            maxTurns: 8,
            iconName: "checkmark.seal"
        )
    ]
}
```

> **注**：`allowedToolNames` 是字符串白名单，StepFun 插件不依赖 GitPlugin——运行时从全局工具池按 name 过滤。若 GitPlugin 未启用，子 Agent 拿不到工具，仍可降级为纯推理。

---

## 关键约束

1. **工具名隔离**：子 Agent `id` 必须全局唯一且符合工具名约束（`a-zA-Z0-9_-`），工具名加 `delegate_` 前缀。`ToolService.registerTools` 重名会 `FatalError`，前缀隔离避免与普通 agentTools 冲突。

2. **provider 动态解析**：每次 `execute` 时通过 `chatService.provider(forID:)` 取最新 provider 实例，避免插件 reload 后实例过期。

3. **conversationID 复用**：子 Agent 工具执行复用主会话的 `conversationID`，继承路径白名单（`allowedDirectories`）和取消机制（`checkCancellation`）。

4. **V1 不支持的能力**：UI 状态更新、消息持久化、工具审批门、交互式 AskUser 暂停（详见可行性评估表）。

5. **协议方法约束**：`subAgents(context:)` 是 `@MainActor static func`，与所有其它 `LumiPlugin` 贡献方法一致。

---

## 与 Claude Code 的设计对应

| Claude Code | Lumi 实现 |
|-------------|-----------|
| `BaseAgentDefinition`（agentType, tools, disallowedTools, model, systemPrompt...） | `LumiSubAgentDefinition`（id, allowedToolNames, providerID, modelID, systemPrompt...） |
| `.claude/agents/*.md` frontmatter 注册 | `LumiPlugin.subAgents(context:)` 协议贡献点 |
| `Agent` / `Task` 工具（主 Agent 调用入口） | `SubAgentDelegateTool`（工具名 `delegate_<id>`） |
| `resolveAgentTools` + `filterToolsForAgent` | `SubAgentDelegateTool.resolveTools()`（按 allowedToolNames 过滤） |
| 复用 `query()` 循环 + `createSubagentContext` 隔离 | `SubAgentLoopRunner`（自包含循环 + 局部 messages 数组） |
| `finalizeAgentTool` 只取最终文本 | `SubAgentLoopRunner` 返回 `SubAgentLoopResult.content` |
| `maxTurns` 防失控 | `LumiSubAgentDefinition.maxTurns`（默认 10） |

**关键差异**：Claude Code 复用主 Agent 的 `query()` 循环（通过构造隔离的 ToolUseContext）；Lumi 的 `ChatService.runAgentTurn` 与会话状态深度耦合，因此提取独立的 `SubAgentLoopRunner` 而非直接复用。两者效果一致：子 Agent 的中间步骤不进主上下文。

---

## 优势总结

| 维度 | 改进 |
|------|------|
| **主上下文 token 消耗** | 减少 80%+（10 条工具调用 → 2 条摘要） |
| **安全性** | 子 Agent 只能用预定义的工具子集（`allowedToolNames`） |
| **可靠性** | 专属 system prompt 保证执行顺序和错误处理 |
| **易用性** | 主 Agent 只需调用 `delegate_<id>` 工具，不需要配置 provider/model |
| **可扩展** | 任何插件都可注册子 Agent；LLM Provider 插件可绑定自家模型 |
| **模型灵活性** | 子 Agent 可用与主 Agent 不同的 provider 和 model（如 StepFun 的 step-3.7-flash 适合 commit message） |

---

## 后续思考（不在本次范围）

- 子 Agent 能否调用其他子 Agent？（嵌套，需防递归）
- 子 Agent 结果能否作为主 Agent 上下文的一部分持久化？
- 是否支持子 Agent 的流式状态报告（进度更新到主 UI）？
- 是否支持用户级 Markdown 声明式注册（类似 Claude Code 的 `.claude/agents/*.md`）？
- 是否需要把 `ChatService.runAgentTurn` 重构为复用 `SubAgentLoopRunner`（消除两套循环的维护成本）？
