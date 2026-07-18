# AgentTool 动态注入改造方案

> 目标：把插件向 Agent 贡献工具的时机，从**「App 启动时一次性冻结进全局单例」**改为**「每次发消息时按当前 context 动态构建 per-request 工具集」**。
>
> 状态：提案（Proposal），尚未实施。所有 `file:line` 引用基于 `dev` 分支截至 2026-07-18 的代码。

---

## 0. TL;DR

- **现状**：`ToolService` 是全局单例，工具表在 App 启动期（`RootContainer.bootstrapAfterPluginLifecycle`）遍历所有插件调 `agentTools(context:)` 一次性构建，之后发消息只读缓存。
- **问题**：LLM 永远看到全部插件工具，与当前项目/会话上下文无关。例如打开 Go 项目时仍会注入 Swift 工具，既浪费 token，也增加模型选错工具的概率。
- **改造方向**：把 `agentTools(context:)` 从「启动初始化函数」升级为「每次发送消息都调用的运行时钩子」。插件拿到反映最新世界状态的 `context`（当前项目、会话状态、当前 model 等），自行决定要不要返回工具。框架不关心筛选逻辑。
- **核心改动**：`ToolService` 从全局单例缓存 → per-request 实例；turn loop 改用本次请求的工具集；启动期不再构建工具（更快、更健壮，单插件抛错不再 crash）。
- **最大风险**：并发安全——多个会话可并发跑 turn，若仍用全局 `ToolService.tools` 会互相覆盖。per-request 实例是必须项，不是可选优化。

---

## 1. 背景与动机

### 1.1 用户场景

> 假设用户当前针对一个 Go 项目，那么 Swift 项目相关工具就没必要注入；假设用户又切换到了 Swift 项目，那么此时 Swift 项目相关工具就可以注入了。

工具的 `name` / `description` / `inputSchema` 会进入每次 API 请求的 prompt。工具越多：

1. **token 成本上升**——每个工具的 schema 都要随请求发送；
2. **模型选择负担上升**——在 20 个工具里挑 1 个，比在 5 个里挑更容易出错；
3. **相关性下降**——工具表本应反映「此刻能干什么」，而不是「App 装了哪些插件」。

### 1.2 改造的真正价值（认知校正）

| 动机 | 是否成立 | 说明 |
|---|---|---|
| 省内存 | ⚠️ 几乎无效 | 工具实例本身是轻量元数据（name/desc/schema），真正占资源的 I/O 在 `execute()` 时才分配。把注入时机后移对内存曲线影响极小。 |
| **工具表更精准，降 token、降误选** | ✅ **核心收益** | 这是本次改造的真实动机。 |
| 启动更快、更健壮 | ✅ 附带收益 | 单插件 `agentTools` 抛错从启动期硬失败（`CrashedView`）降级为发消息时软提示。 |
| 统一心智模型 | ✅ 附带收益 | 所有运行时相关性判断收敛到 `agentTools(context:)` 一处。 |

---

## 2. 现状分析

### 2.1 工具表构建链路（改造前）

```
LumiCore.init
  └─ AgentToolComponent.bootstrapToolService          (AgentToolComponent.swift:31)
        ├─ ToolService()                              ← 全局单例诞生
        ├─ lumiCore.registerService(ToolService.self, ...)   ← 注册表强引用
        ├─ toolService.environment = bridge
        └─ validateToolNameUniqueness(...)            ← 启动期名校验 (LumiCore.swift:87-92)

App 加载完插件后:
AgentToolComponent.bootstrapToolContributions         (AgentToolComponent.swift:65)
  ├─ provider.agentTools(context:)                    (LumiPluginRegistry+State.swift:188)
  ├─ toolService.registerTools(pluginTools)           ← 覆盖式写入缓存
  ├─ toolService.registerBuiltInTools(builtInTools)   ← NoOp/ConversationInfo
  ├─ toolService.appendTools(subAgentTools)           ← SubAgentDelegateTool
  └─ lumiCore.chatService.registerToolService(toolService)   ← ChatService weak 持有

每轮 turn:
ChatService.runAgentTurn(conversationID:)             (ChatService.swift:850)
  └─ 每轮 LLM 调用经 makeAssistantMessageWithEmptyRetry → SendPipeline.makeAssistantMessage
        ├─ service.agentTools → toolService?.tools ?? builtInTools   (SendPipeline.swift:275)
        └─ LumiLLMRequest(... tools: tools ...)       ← 永远是同一份冻结快照
  └─ 工具执行: toolService.tool(named:) / toolService.execute(...)   (ChatService.swift:956/967/1018)
```

### 2.2 触发重建的入口（改造前只有两个）

`ToolService.tools` 的重建由 `bootstrapToolContributions()` 驱动，它在两处被调用（`RootContainer.swift`）：

1. **启动期**——`bootstrapAfterPluginLifecycle()`（:185）；
2. **插件开关变化**——`onLumiEnabledPluginsDidChange` 通知回调（:138-145）。

**没有订阅 `currentProjectDidChange`**，因此项目切换不会刷新工具表。

### 2.3 关键事实清单

| 关注点 | 现状 | 位置 |
|---|---|---|
| `ToolService` 类型 | `@MainActor final class`，持有 `tools` / `toolsByName` / `environment` 三个 `var` | `ToolService.swift:8-18` |
| `ToolService` 实例数 | 进程级单例（通过 `LumiCore.services` 注册表强引用 + `ChatService.toolService` weak 引用） | `AgentToolComponent.swift:36` |
| `ChatService` 实例数 | per-LumiCore 唯一（进程级单例） | `LumiCore.swift:17, 72-73` |
| 会话并发 | 同一会话不并发（`activeTasksByConversationID` 互斥）；**不同会话可并发** | `ChatService.swift:52-53` |
| `LumiPluginContext` 是否携带项目信息 | 不直接携带，但暴露 `lumiCore?.projectComponent.currentProject` | `LumiPluginContext.swift:32`, `LumiCoreAccessing.swift:32` |
| `.projectDidOpen` 生命周期 | **死代码**——定义了但全仓库无人调用 | `LumiPlugin.swift:145`, `LumiPluginRegistry.swift:193` |
| 插件示例 `EditorSwiftPlugin.agentTools` | 无条件返回 3 个 Swift 工具，**不读 context** | `EditorSwiftPlugin.swift:71-78` |
| `EditorSwiftPlugin` 其他贡献方法 | 已在用 context 条件判断（`titleToolbarItems`/`panelBottomTabItems`） | `EditorSwiftPlugin.swift:25-69` |

---

## 3. 目标架构

### 3.1 设计原则

1. **框架只负责调度**——「是否注入工具」的决策权完全交给插件，`agentTools(context:)` 是唯一判断点。
2. **per-request 隔离**——每次发消息构建一份工具集，本次 turn 序列内稳定，请求结束即释放。
3. **零启动期硬依赖**——启动不再构建工具表，单插件失败不 crash app。
4. **保留容错**——单插件抛错不影响其他插件，失败信息收进 `toolContributionFailures` 供 UI 软提示。

### 3.2 改造后的构建链路

```
用户发送一条消息
  │
  ▼
SendPipeline.makeAssistantMessage (SendPipeline.swift:273)
  │
  │  【新增步骤 1】构造最新 LumiPluginContext
  ├─ context.lumiCore?.projectComponent.currentProject = (当前项目)
  │     context 反映此刻世界状态，不是启动快照
  │
  │  【新增步骤 2】遍历启用插件，各自回答「你现在提供哪些工具?」
  ├─ EditorSwiftPlugin  → context 是 Go 项目 → 返回 []
  ├─ EditorGoPlugin     → context 是 Go 项目 → 返回 [AddGoModuleTool, ...]
  └─ AskUserPlugin      → 无关项目 → 返回 [AskUserTool]
  │     (LumiPluginRegistry+State.swift:188 的容错逻辑照旧)
  │
  │  【新增步骤 3】合并 [插件工具 + builtInTools + subAgentTools]
  ├─ 名字冲突校验（轻量去重，原启动期校验挪到这）
  │
  │  【新增步骤 4】new 一个 per-request ToolService 实例
  ├─ 把上述工具集塞进去；只服务本次会话的本次 turn 序列
  │
  │  【新增步骤 5】填进 LLMRequest
  ├─ request.tools = 上面那一份（LLM 只看到 Go 工具）
  │
  ▼
LLM 返回 tool_calls
  │
  ▼
ChatService.runAgentTurn (ChatService.swift:850)
  │  【改动】turn loop 用 per-request 工具集，不是全局 self.toolService
  ├─ perRequestToolService.tool(named:) / execute(...)
  │
  └─ 继续下一轮 turn（仍用同一份 per-request 工具集）
       直到 LLM 不再调工具 → per-request ToolService 释放
```

### 3.3 改造前 vs 改造后

| 阶段 | 改造前 | 改造后 |
|---|---|---|
| App 启动 | 遍历所有插件构建工具，冻结进全局 ToolService；插件抛错走 `CrashedView` | 不碰工具，只造空壳 ToolService |
| 打开项目 | 无影响（工具是快照） | 无影响（工具延迟到发消息时构建） |
| 用户发消息 | 直读全局缓存 `toolService.tools` | 遍历插件按 context 构建 + new per-request ToolService |
| LLM 看到的工具 | 全部插件工具（与项目无关） | 仅当前 context 相关工具 |
| turn loop 执行 | 用全局 `self.toolService` | 用本次构建的 per-request ToolService |
| 请求结束 | 工具常驻内存 | per-request ToolService 释放 |
| 并发安全 | 多会话共用全局，有覆盖竞争 | 天然隔离 |
| 插件 `agentTools` 抛错 | 启动硬失败 | 发消息时软降级 |

---

## 4. 改造点清单（逐文件）

### 4.1 核心改动（必须）

#### ① `LumiToolServicing` 协议
`Packages/LumiCoreKit/Sources/AgentTool/LumiAgentTool.swift:373-380`

当前协议要求 `AnyObject`（只能 class 实现），且暴露 `registerTools`。改造后需要支持 per-request 实例化：新增工厂方法或允许 `init(tools:environment:)`。

```swift
// 改造前
@MainActor
public protocol LumiToolServicing: AnyObject {
    var tools: [any LumiAgentTool] { get }
    func registerTools(_ tools: [any LumiAgentTool]) throws
    func tool(named name: String) -> (any LumiAgentTool)?
    func execute(_ toolCall: LumiToolCall, conversationID: UUID) async -> LumiToolResult
}

// 改造后（草案）
@MainActor
public protocol LumiToolServicing: AnyObject {
    var tools: [any LumiAgentTool] { get }
    func tool(named name: String) -> (any LumiAgentTool)?
    func execute(_ toolCall: LumiToolCall, conversationID: UUID) async -> LumiToolResult
}
// 工厂方法由 ToolService 提供：
//   ToolService(tools: [...], environment: bridge)
// registerTools 仍可保留用于兼容/测试，但生产路径不再依赖。
```

#### ② `ToolService` 支持直接初始化
`Packages/LumiCoreKit/Sources/AgentTool/ToolService.swift`

新增一个接受初始工具集的 `init`，让 per-request 构建直接产生就绪实例，免去「先空构造再 register」的两步。`environment` 仍由启动期注入的 bridge 提供，per-request 实例复用同一份 bridge。

#### ③ `AgentToolComponent` 拆分
`Packages/LumiCoreKit/Sources/AgentTool/AgentToolComponent.swift:65-111`

把 `bootstrapToolContributions` 拆成两段：
- 启动期保留：`bootstrapToolService`（造空壳 ToolService + 注入 environment）。
- 新增运行期：`buildToolSet(context:provider:builtInTools:lumiCore:) -> ToolService`，封装「插件工具 + 内置工具 + subAgent 工具」的合并逻辑，供 `SendPipeline` 调用。

#### ④ `SendPipeline.makeAssistantMessage`
`Packages/LumiChatKit/Sources/Managers/SendPipeline.swift:273-281`

把第 275 行的「直读 `service.agentTools`」改为：
1. 构造最新 `LumiPluginContext`；
2. 调 `buildToolSet(...)` 得到 per-request `ToolService`；
3. 把它**传递给 turn loop**（关键，见 ⑤），并取其 `.tools` 填进 `LumiLLMRequest`。

#### ⑤ `ChatService.runAgentTurn` 改用 per-request ToolService
`Packages/LumiChatKit/Sources/ChatService.swift:850-1020`

当前 turn loop 在三处用 `self.toolService`（:956、:967、:1018）。改造后接受一个 `toolService` 参数，内部全程使用它，不再触碰 `self.toolService`。

```swift
// 改造前
func runAgentTurn(conversationID: UUID, imageAttachments: [LumiImageAttachment] = []) async throws -> LumiAgentTurnOutcome {
    // ... 用 self.toolService
}

// 改造后（草案）
func runAgentTurn(
    conversationID: UUID,
    toolService: any LumiToolServicing,   // ← per-request 工具集
    imageAttachments: [LumiImageAttachment] = []
) async throws -> LumiAgentTurnOutcome {
    // ... 用传入的 toolService
}
```

### 4.2 配套改动

#### ⑥ 启动流程摘除工具构建
`Packages/LumiAppKit/Sources/LumiAppKit/Bootstrap/RootContainer.swift:185`

从 `bootstrapAfterPluginLifecycle` 里移除 `bootstrapToolContributions()` 调用。`onLumiEnabledPluginsDidChange`（:138-145）的通知订阅可以移除（或保留为空操作）——插件开关不再需要重建工具表，下次发消息自然反映。

#### ⑦ 启动期名校验时机调整
`Packages/LumiCoreKit/Sources/LumiCore.swift:87-92`

`validateToolNameUniqueness` 从启动期挪到 `buildToolSet` 里，每次构建时轻量去重。失败走软降级（跳过冲突工具或记入 `toolContributionFailures`），不阻断本次请求。

#### ⑧ `LumiPluginContext` 携带当前项目
`Packages/LumiCoreKit/Sources/Plugin/LumiPluginContext.swift`

现状已能通过 `context.lumiCore?.projectComponent.currentProject` 间接读取（`LumiCoreAccessing.swift:32`），无需强行加字段。但建议在 `LumiPluginContext` 上加一个便捷计算属性 `var currentProject: ProjectEntry?`，减少插件样板代码。

#### ⑨ `.projectDidOpen` 死代码处理
`Packages/LumiPluginRegistry/Sources/LumiPluginRegistry.swift:193`

本改造下工具表不响应项目切换（延迟到发消息），所以不需要接通这个钩子。建议**保留定义、文档标注废弃**，或在本改造里顺手接通（`OpenProjectHandler.swift:46` 处 fire）作为独立收益——视优先级决定，不属于本方案必需。

---

## 5. 并发安全分析（核心风险）

### 5.1 为什么必须 per-request

多个会话可并发跑 turn（`ChatService.swift:52` 的 `activeTasksByConversationID` 允许不同会话各有独立 Task，都在 `@MainActor` 上交替执行）。若工具集仍是全局单例：

```
会话 A（Go 项目）发消息   → ToolService.tools = [Go 工具]
会话 B（Swift 项目）发消息 → ToolService.tools = [Swift 工具]   ← 覆盖了 A 的！
会话 A 下一轮 turn        → tool(named: "add_go_module") → 找不到 ❌
```

虽然 `@MainActor` 串行化保证 `tools` 不会被并发破坏，但**逻辑上的覆盖竞争仍然存在**（A 的工具集被 B 整体替换）。

### 5.2 per-request 如何解决

每次发消息 new 一个 `ToolService`，本次 turn 序列内全程持有。不同会话的 turn loop 各自持有自己的实例，互不可见、互不覆盖。请求结束后随 turn 上下文一起释放。

### 5.3 `environment` 复用

`ToolService.environment`（`ToolService.swift:15`）持有 `verbosity`、`currentProjectPath` 等运行时桥接，是只读的消费方，可以安全地被多个 per-request 实例共享（注意：若 `environment` 内有可变状态，需要单独评估）。

---

## 6. 性能与契约

### 6.1 每次发消息的开销

`agentTools(context:)` 被调用的频率从「启动 1 次」变成「每次发消息 1 次」。可控的前提是**插件遵守契约**：

> `agentTools(context:)` 必须 O(1) 量级：只做基于 context 的纯判断 + 实例化，**严禁 I/O**。
>
> 重活（文件扫描、网络、语言检测）必须：
> - 放进 `execute()` 里按需做，或
> - 在项目打开时预算一次，结果缓存进 `LumiPluginContext` 或 `ProjectEntry`。

### 6.2 项目语言检测的预算策略

项目语言（Go/Swift/Rust）应在 `OpenProjectHandler.requestOpen`（`OpenProjectHandler.swift:26-47`）打开项目时探测一次（扫 `go.mod` / `Package.swift` / `Cargo.toml`），结果存入 `ProjectEntry`。**不要**在 `agentTools(context:)` 里现扫。

> 注：当前 `ProjectEntry` 只有 `name`/`path`/`lastUsed`（`ProjectEntry.swift:4-16`），没有类型字段。语言检测属于独立增强，可后续单独提案；本方案不强制要求它落地（插件也可临时靠 `path` 后缀或文件存在性判断）。

---

## 7. 兼容性与回滚

### 7.1 插件契约影响

`LumiPlugin.agentTools(context:)`（`LumiPlugin.swift:24-31`）**签名不变**，现有插件无需改动即可继续工作（行为退化为「无条件返回固定工具集」，等价于改造前的效果）。新能力（按 context 筛选）是可选增强。

### 7.2 `LumiToolServicing` 协议变更

`registerTools` 从协议移除是 breaking change（如果有外部 mock 实现该协议）。降级方案：保留 `registerTools` 在协议里为 optional 或提供默认实现，避免破坏测试 mock。

### 7.3 回滚

改造集中在 `AgentToolComponent` / `SendPipeline` / `ChatService.runAgentTurn` / `RootContainer` 四处，可独立提交、独立回滚。若上线后发现性能不可接受，回滚 `SendPipeline` 第 275 行的直读逻辑即可恢复全局缓存行为。

---

## 8. 实施步骤（建议顺序）

1. **协议与类型调整**（①②）——`LumiToolServicing` 加工厂方法、`ToolService` 加 `init(tools:environment:)`。此步不改变运行行为，仅扩展能力。
2. **拆分构建逻辑**（③）——新增 `AgentToolComponent.buildToolSet`，与 `bootstrapToolContributions` 并存，先不动调用方。
3. **改 turn loop 签名**（⑤）——`runAgentTurn` 接受 `toolService` 参数，内部改用传入实例。调用方暂传 `self.toolService`（等价行为）。
4. **接通 per-request 路径**（④）——`SendPipeline` 改为调 `buildToolSet` 构建本次工具集，传入 turn loop。此时行为已切换到动态构建。
5. **摘除启动期构建**（⑥⑦）——从 `RootContainer` 移除 `bootstrapToolContributions` 调用，名校验挪到 `buildToolSet`。
6. **验证**——构建 + 跑 `LumiChatKit` 测试 + 手测多会话并发场景。

每一步都可独立编译、独立提交，便于定位问题。

---

## 9. 待决策点

| 问题 | 选项 | 建议 |
|---|---|---|
| `LumiToolServicing.registerTools` 是否从协议移除 | A. 移除（breaking）/ B. 保留为兼容 | 视是否有外部 mock 实现决定；优先 B |
| `.projectDidOpen` 死代码是否顺手接通 | A. 保留废弃 / B. 接通（独立收益） | 本方案不依赖，可单独立项 |
| 是否给 `ProjectEntry` 加语言字段 | A. 加（需检测逻辑）/ B. 不加（插件靠 path 判断） | 与语言检测一起做，单独提案 |
| builtInTools（NoOp/ConversationInfo）何时注入 | A. 每次 buildToolSet 都加 / B. 启动期注入一次 | A，保持 per-request 完整自洽 |

---

## 10. 参考

- 现状分层模型与 ChatService 上帝对象诊断：`docs/architecture-refactor-proposal.md`
- LLM Provider 重构模式（直接实现协议 + 工具函数复用）：`docs/refactor-guide-llm-provider.md`
