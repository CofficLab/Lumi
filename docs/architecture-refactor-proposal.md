# Lumi 分层架构优化方案

> 目标：**架构清晰、分工明确、关注点分离**。
>
> 本文档基于对 `LumiCoreKit` 与 `LumiChatKit`（及其装配层 `LumiAppKit`）的审查，
> 给出当前架构的诊断、目标分层模型、以及分阶段、可落地的重构路线。
>
> 状态：提案（Proposal），尚未实施。文末附"决策点"，需在动工前对齐取舍。

---

## 0. TL;DR

- 依赖方向是**对的**（单向、无循环 import），依赖倒置（工厂 + 协议）用得也正确。
- 真正的病灶集中在四个字：**领域归属错位**、**状态囤积**、**关注点穿透**、**全局状态泛滥**。
- 最该先动的一刀：**通知统一 + 重复枚举合并**（零架构成本，立即收益）。
- 最大的一刀：**拆出 `LumiChatContracts` 协议包**，让 CoreKit 真正回到领域中立。
- 最大的一刀（代码层）：让 `ChatService` 从"上帝对象"变回"门面 + 状态容器"，把 agent 循环引擎下放到 `SendPipeline`。

---

## 1. 现状分层模型

```
┌─────────────────────────────────────────────────────────┐
│  LumiAppKit  (App 层 / 组合根)                            │  ← 同时依赖 Core + Chat
│   RootContainer, LumiCoreService, PluginService, ...     │     唯一允许"知道具体类"的层
└───────────────┬─────────────────────────┬───────────────┘
                │ depends on              │ depends on
                ▼                         ▼
┌───────────────────────────┐  ┌──────────────────────────┐
│  LumiChatKit (实现层)      │  │  ModelRouterKit          │
│   ChatService, Managers,  │  │  EditorChatInputKit      │
│   Persistence, Checks,    │  └──────────────────────────┘
│   BuiltInTools,           │
│   ChatSectionCoordinator  │
└─────────────┬─────────────┘
              │ depends on
              ▼
┌─────────────────────────────────────────────────────────┐
│  LumiCoreKit (核心层)                                     │  ← 只依赖 SuperLogKit / LumiLocalizationKit
│   LumiCore (聚合根), LumiCoreAccessing (协议),           │
│   Chat/ (19 文件!), AgentTurn/, LLMProvider/,            │
│   Plugin/, Layout/, Message/, ...                        │
└─────────────────────────────────────────────────────────┘
```

### 装配链路（谁注入谁）

App 层 `LumiCoreService.init` 是唯一合法的"知道 `ChatService` 具体类"的地方：

```
RootContainer.init()                              [App 层组合根]
   ├─ LumiCore()                                  [CoreKit, 空壳]
   ├─ lumiCore.setupChatService { ChatService(...) }   ← 注入点
   │       └─ ChatService(...)                    [ChatKit 实现] 在此被引用
   └─ lumiCore.boot(...)                          ← boot 时回调闭包，真正创建实例
           └─ chatService = factory(coreDatabaseDirectory)
           └─ registerService(...)                存进服务表
```

CoreKit 只持有 `any LumiChatServicing`（协议），不认识 `ChatService`（具体类）。
插件通过 `LumiPluginContext` 拿到的同样是协议类型——这是"插件上级是 LumiCore"的实现基础。

---

## 2. 诊断：哪些地方做了"不该做的事"

### 2.1 领域归属错位（最严重）

`LumiCoreKit/Sources/Chat/` 下有 **19 个文件**，其中大量是纯聊天域概念：

| 文件 | 性质 | 是否越界 |
|---|---|---|
| `LumiChatServicing.swift` | 聊天服务协议 | 🟡 依赖倒置的合理代价（协议须在 CoreKit 供反向引用） |
| `LumiChatNotifications.swift` | `lumiTurnFinished`/`lumiAskUserDidAnswer`/`lumiMessageSaved` 通知名 | 🔴 越界 |
| `LumiConversationContextUsage.swift` | 含硬编码 `content.count / 4` token 估算 | 🔴 业务算法下沉 |
| `ModelUsageStatsService.swift` (190 行) | token 聚合 + 按天分桶 + 连续补零算法 | 🔴 业务算法下沉 |
| `LumiConversationSummary.swift` | 会话配置枚举，内嵌英文 system prompt 文案 | 🟡 模型本体合理，prompt 文案下沉 |
| `LumiImageAttachment` / `LumiStreamChunk` / `LumiPendingToolConfirmation` 等纯模型 | 值类型 | 🟢 可共享，放 CoreKit 可接受 |

**根因**：为了让 CoreKit 不 import ChatKit，把所有聊天契约都塞进了 CoreKit，
反而让 CoreKit "知道"了它本不该知道的聊天语义（通知名、turn 结束原因、token 怎么算）。

### 2.2 通知：定义与发送方分居两层，且双重发送

- `.lumiTurnFinished` / `.lumiTurnCompleted` / `.lumiMessageSaved` **通知名定义在 CoreKit**
  （`Chat/LumiChatNotifications.swift`），**但由 LumiChatKit post**
  （`SendPipeline.swift:387,418,423`、`MessageManager.swift:141`）。
- 更糟：CoreKit 自己的 `AgentTurn/AgentNotifications.swift:44,50` **也在 post 同一个 `.lumiTurnFinished`/`.lumiTurnCompleted`**。
  → 同一个通知名被两层各自发送，**发送方分裂**。
- 重复定义：
  - `.messageSaved`（AgentTurn 域，`AgentNotifications.swift`）vs `.lumiMessageSaved`（Chat 域）——语义重叠。
  - `TurnEndReason`（带 associated value，`AgentTurn/TurnEndReason.swift:4`）
    vs `LumiTurnEndReason`（String rawValue，`TurnEndReason.swift:13`）——语义重叠，后者注释自承"LumiChatKit turn 结束原因"。

### 2.3 ChatService：形似门面，实为"共享可变状态的囤积者"

`ChatService.swift`（1097 行）：

- 持有 ~15 个 `@Published` + ~15 个内部 property。4 个 Manager（`ConversationManager`/`MessageManager`/`ProviderManager`/`SendPipeline`）**不拥有自己的状态**，全部通过 `weak service` 回头直接 mutate ChatService 的字段。
  → 这是**代码组织上的拆分，不是职责上的解耦**。状态维度上 ChatService 仍是上帝对象。
- 最核心的 `runAgentTurn`（约 200 行）和两个重试方法（约 150 行）**反而没下放**给 `SendPipeline`，却把边角 CRUD 派给了 Manager——**优先级倒置**。
- 7 个 `persistXxx` 协调方法散落各处，每个 Manager 写状态都要回头调对应的 persist——**事务边界没有封装**。

### 2.4 UI 关注点穿透进实现层

`LumiChatKit/Sources/ChatSectionCoordinator.swift`（241 行）是纯 UI 协调器：
`import AppKit`/`SwiftUI`、弹 `NSOpenPanel`、处理文件拖放、处理 `/clear`/`/help`/`/model` 斜杠命令、持有 `@Published draft`/`inputHeight`/`isInputFocused` 等 UI 状态。
它与聊天业务逻辑同处一个 package，会让任何想复用 `ChatService` 的非 UI 场景被迫拖入 AppKit。

此外 `ChatService` 自身持有 `messageRenderers` + `renderer(for:)`（渲染器注册/匹配），也是 UI 关注点。

### 2.5 全局可变状态泛滥

CoreKit：
- 模块级 `nonisolated(unsafe) var currentLumiCore` / `currentLumiCoreDataRootDirectory` / `lumiCoreFallbackDataRootDirectory`（3 个 unsafe 全局）。
- 单例 `LumiAPIKeyStore.shared` / `ProviderRenderKindManager.shared` / `ProviderSettingsStore.shared` / `LogoRegistry.shared`。
- `LumiAPIKeyStore.shared` 还被 `LumiLLMProvider` 直接静态访问，**绕过依赖注入**。

ChatKit：`ChatService.swift:8` 的 `static weak var shared`，且 `BuiltInTools/ConversationInfoTool.swift` 反向通过该单例抓 ChatService，而非走 `LumiToolExecutionContext` 注入。

> 说明：`LumiCore.current` / `currentLumiCore` 的存在有现实原因——插件侧 `static let shared = ...` 单例在非 MainActor 上下文 init，拿不到协议注入。
> 见 `LumiCoreService.swift:50-60` 的注释。优化时要给出替代注入路径，不能简单删除。

---

## 3. 做得好的地方（保留，不要动）

| 维度 | 证据 |
|---|---|
| 依赖方向单向 | LumiChatKit → LumiCoreKit；CoreKit 全仓库无 `import LumiChatKit` |
| 接口隔离做得好 | `LumiCoreAccessing`（只读）与 `LumiCoreBootstrapping`（启动期）拆成两个协议，ChatService 只能看到只读子集 |
| 持久化层干净 | `LumiChatKit/Persistence/` 纯存储映射，未重定义领域模型 |
| LumiCore 非上帝对象 | 它是聚合根 / service locator，每域委托给具体服务，约 265 行 |
| 依赖倒置装配正确 | `setupChatService` + 工厂闭包 + `any LumiChatServicing`，避免了循环依赖 |

---

## 4. 目标分层模型

```
┌─────────────────────────────────────────────────────────────┐
│  LumiAppKit  (组合根 / Composition Root)                      │
│   - 唯一知道具体类的层：new ChatService / new EditorCoreService│
│   - 接线：PluginService → ChatService / LumiCore              │
│   - UI 协调器（从 ChatKit 上移的 ChatSectionCoordinator 等）    │
└───────────┬───────────────────────────┬─────────────────────┘
            │                           │
            ▼                           ▼
┌────────────────────────┐   ┌──────────────────────────────┐
│  LumiChatKit (实现层)   │   │  ModelRouterKit / Editor...   │
│   ChatService = 门面     │   └──────────────────────────────┘
│   + 状态容器            │
│   SendPipeline = 引擎    │
│   Managers = 状态拥有者  │
│   Persistence (存储映射) │
│   Checks / BuiltInTools │
└───────────┬─────────────┘
            │ depends on (双向依赖这个协议包)
            ▼
┌─────────────────────────────────────────────────────────────┐
│  LumiChatContracts  (NEW - 纯协议/模型包, 零实现)              │
│   LumiChatServicing, 通知名, TurnEndReason,                  │
│   LumiConversationSummary, 纯值类型, Middleware 协议          │
└───────────┬─────────────────────────────────────────────────┘
            │ depends on
            ▼
┌─────────────────────────────────────────────────────────────┐
│  LumiCoreKit (核心层 - 真正领域中立)                           │
│   LumiCore (聚合根), LumiCoreAccessing,                      │
│   AgentTurn/ (无 Chat 语义), LLMProvider/, Plugin/,          │
│   Layout/, Message/ (通用消息原语), ...                        │
│   - 不含任何 Chat 语义、不含聊天通知名                          │
└─────────────────────────────────────────────────────────────┘
```

核心变化：

1. **新增 `LumiChatContracts` 协议包**——CoreKit 与 ChatKit 共同依赖它，
   让 Chat 契约不再"住"在 CoreKit 里。
2. **CoreKit 瘦身**——移除所有 Chat 语义（通知名、turn 原因、token 算法），
   只保留领域中立的核心。
3. **ChatService 回归门面**——状态下沉到各 Manager，agent 循环引擎化。
4. **UI 上移到 App 层**——`ChatSectionCoordinator` 等离开 ChatKit。

---

## 5. 分阶段重构路线

按"风险从低到高、收益从立竿见影到长期"排序。每个阶段都是**独立可交付、可回滚**的。

### 阶段 0：通知与枚举统一（零架构成本，立即收益）

> ✅ **已于本次清理完成**（2026-07）：`AgentTurn/` 模块整批 legacy 类型已移除——
> `AgentNotifications.swift`（连同 `.messageSaved`/`.agentTurnPhaseChanged` 及 no-op 的
> `AgentTurnLifecycle.postTurnFinished`）、废弃 `TurnEndReason` 及其桥接 `init`、
> `AgentChatMessage` / `AgentConversationStore` / `AgentLLMSendService` / `AgentTurnPhase` /
> `AgentTurnDerivation` / `NotifyingAgentConversationStore` / `AgentSendPipelineLog` /
> `ToolExecutionSummary` 全部删除；`SuperPluginLegacyTypes.PluginRuntimeContext` 中无人
> 覆盖的 Agent pipeline 闭包段一并剥离。模块现仅保留 4 个 Lumi 前缀类型
> （`LumiAgentTurnCheck` / `LumiAgentTurnOutcome` / `LumiAgentTurnDerivation` / `LumiTurnEndReason`）。
> 通知名权威定义在 `Chat/LumiChatNotifications.swift`，turn 结束通知由
> `LumiChatKit.SendPipeline` 唯一发送。

**目标**：消除双重发送、重复定义。不移动任何文件、不改依赖图。

| 动作 | 文件 |
|---|---|
| 删除 `AgentTurn/AgentNotifications.swift` 对 `.lumiTurnFinished`/`.lumiTurnCompleted` 的 post，统一由 LumiChatKit 的 `SendPipeline` 唯一发送 | `AgentNotifications.swift:44,50` |
| 合并 `TurnEndReason`（associated value）与 `LumiTurnEndReason`（String rawValue）为一个类型；保留更富表达力的那个，废弃另一个并留 `@available(*, deprecated)` 过渡 | `AgentTurn/TurnEndReason.swift` |
| 统一 `.messageSaved` 与 `.lumiMessageSaved` 为单一通知名 | `AgentNotifications.swift` / `Chat/LumiChatNotifications.swift` |
| 明确每个通知**只有一个发送方**，在通知定义处写注释标注 owner | `LumiChatNotifications.swift` |

**验收**：`grep` 同名通知的 post 点，每个通知名有且仅有一个发送方。

**风险**：低。需全局检查通知订阅方是否对 associated value 类型敏感。

---

### 阶段 1：业务算法回迁到 LumiChatKit

**目标**：把"纯函数化业务算法"从 CoreKit 移回实现层。

| 动作 | 目的地 |
|---|---|
| 迁移 `ModelUsageStatsService.swift`（190 行 token 聚合） | `LumiChatKit/Sources/` |
| 迁移 `LumiConversationContextUsage.swift`（含 `content.count / 4` 估算） | `LumiChatKit/Sources/` |
| `LumiConversationSummary` 各枚举的 `systemPromptFragment` 英文文案：抽成可注入的默认配置，而非硬编码在 CoreKit 模型里 | CoreKit 保留枚举，prompt 移到 ChatKit/App |

**前置依赖**：这些算法依赖的 `LumiChatMessage` 等若仍在 CoreKit，需随阶段 2 一并迁移，或先保留对 CoreKit 模型的依赖（ChatKit 本就依赖 CoreKit，可接受）。

**验收**：CoreKit 不再含 token 计算/统计的具体算法。

**风险**：中。需更新 import 与测试目标归属。

---

### 阶段 2：拆出 `LumiChatContracts` 协议包（最大的一刀）

**目标**：让 CoreKit 真正领域中立。这是解决 §2.1 根因的结构性手段。

**新包结构**：

```
Packages/LumiChatContracts/
  Package.swift           # 依赖: LumiCoreKit (如果协议里引用了 CoreKit 的通用类型)
  Sources/
    LumiChatServicing.swift          # 聊天服务协议
    LumiChatNotifications.swift      # 通知名 + userInfo key
    TurnEndReason.swift              # 合并后的单一枚举
    LumiConversationSummary.swift    # 会话配置模型 + 枚举
    LumiImageAttachment.swift        # 纯值类型
    LumiSendMiddleware.swift         # 中间件协议
    LumiPendingToolConfirmation.swift
    ... (其余从 CoreKit/Sources/Chat/ 迁出的纯模型/协议)
```

**依赖图变化**：

```
Before:  ChatKit ──▶ CoreKit(含 19 个 Chat 文件)
After:   ChatKit ──▶ Contracts ──▶ CoreKit
         ChatKit ──▶ CoreKit (仍可, CoreKit 保留通用基础设施)
```

**关键约束**：

- `LumiChatServicing` 协议里若引用了 CoreKit 类型（如 `LumiChatMessage`），则 Contracts 反向依赖 CoreKit。需决定这些通用消息原语归属：
  - 选项 A：通用消息原语（`LumiChatMessage`/`LumiToolCall`）留在 CoreKit，Contracts 依赖 CoreKit。
  - 选项 B：把消息原语也一并下沉到 Contracts 或更细的包，CoreKit 完全不含消息概念。
  - **推荐 A**：增量小，CoreKit 保留"通用消息原语"是合理的领域中立内容。

- CoreKit 的 `LumiPlugin` hook 若反向引用了 `LumiChatServicing`，该 hook 协议应移到 Contracts，或改由 `PluginService` 在 App 层做胶合（见 §5 决策点）。

**验收**：`grep -r "lumiTurn\|Chat" Packages/LumiCoreKit/Sources/` 仅命中真正通用的部分（如通用消息原语），不含聊天业务语义。

**风险**：高。触及依赖图顶层结构，影响所有下游包的 Package.swift。需充分测试 + 分批迁移（先建包并重导出，再逐个迁移，最后断开旧路径）。

**回滚策略**：保留一段时间的 `@_exported import` 重导出别名，让旧 import 路径继续可用，分多次 PR 逐步切断。

---

### 阶段 3：ChatService 解耦（代码层最大的一刀）

**目标**：ChatService 从上帝对象回归"门面 + 状态容器"，agent 循环引擎化。

**3.1 agent 循环引擎化**

```
Before:  ChatService.runAgentTurn(...)   (200 行, 含插件 hook 直连)
After:   SendPipeline.runAgentTurn(...)  (ChatService 转发)
```

- 把 `runAgentTurn` 及两个 `makeAssistantMessageWithXxxRetry` 从 `ChatService` 迁到 `SendPipeline`。
- **消除插件层硬耦合**：`runAgentTurn` 里直接调 `LumiPluginRegistry.toolExecutionHooks()` 的地方，改为通过 `LumiToolServicing`（已存在的抽象）或注入的 hook 闭包，不直接触碰插件注册表。

**3.2 Manager 拥有自己的状态**

```
Before:  Manager 通过 weak service 直接 mutate service.conversations / messagesByConversationID / ...
After:   Manager 持有自己的状态，通过 delegate / Combine 向上通知 ChatService
```

- 会话列表、消息字典、provider 字典、pending 队列、revision 计数器分别下沉到对应 Manager。
- ChatService 持有各 Manager 的引用，`@Published` 通过转发 Manager 的状态实现（SwiftUI 仍能刷新）。
- **事务边界封装**：`persistXxx` 协调逻辑收进各 Manager 内部，Manager 在改完状态后自己负责持久化 + revision++。

**3.3 AskUser 通知监听外移**

`setupAskUserNotificationObserver`（`ChatService.swift:100-121`）和 `resumeAfterAskUser`——把"通知驱动的业务决策"抽成独立的 `AskUserCoordinator`（或并入现有 `AskUserBridge`，见 Plugins/AskUserPlugin），不混在核心服务里。

**验收**：

- `ChatService.swift` 行数显著下降（目标 < 400 行），主体是转发方法。
- `SendPipeline` 成为明确的"agent 循环引擎"。
- 各 Manager 持有并内聚自己的状态。
- `grep LumiPluginRegistry Packages/LumiChatKit/Sources/` 仅命中抽象层，无直连。

**风险**：高。这是最易引入回归的一步，需配套单元测试（现有 `LumiChatKitTests/` 可作基线）。建议拆成 3.1 → 3.2 → 3.3 三个子 PR。

---

### 阶段 4：UI 上移到 App 层

**目标**：LumiChatKit 不含 AppKit/SwiftUI 业务协调逻辑。

| 动作 | 说明 |
|---|---|
| `ChatSectionCoordinator.swift` 移到 `LumiAppKit` 或新建 UI 协调层 | 它是纯 UI 协调器（NSOpenPanel/拖放/斜杠命令），不该和 ChatService 同包 |
| `ChatService.messageRenderers` + `renderer(for:)` 评估上移到 UI 层 | 渲染器注册/匹配是 UI 关注点 |

**验收**：`LumiChatKit` 不 `import AppKit`（除必要的类型 alias）。非 UI 场景可复用 `ChatService`。

**风险**：中。需处理 `RootContainer.swift:66-69` 对 `ChatSectionCoordinator` 的构造依赖，确认上移后装配链仍通。

---

### 阶段 5：全局状态收敛

**目标**：消除 unsafe 全局变量泛滥，回归依赖注入。

| 动作 | 说明 |
|---|---|
| 收敛 `currentLumiCore` / `currentLumiCoreDataRootDirectory` / `lumiCoreFallbackDataRootDirectory` 为单一入口，或注入到插件 context | 详见 `LumiCoreService.swift:50-60` 注释，需给插件单例替代注入路径 |
| `LumiAPIKeyStore.shared` / `ProviderRenderKindManager.shared` / `ProviderSettingsStore.shared` / `LogoRegistry.shared` 改走 `registerService` 注入 | `LumiLLMProvider` 对 `LumiAPIKeyStore.shared` 的静态访问改为注入 |
| `ChatService.shared` 单例：评估移除，`ConversationInfoTool` 改走 `LumiToolExecutionContext` 注入 | 消除工具→服务单例的反向耦合 |

**验收**：`grep "nonisolated(unsafe) var" Packages/LumiCoreKit/Sources/` 清零或收敛为 1 个有充分注释的入口。

**风险**：高。插件侧 `static let shared = ...` 单例有现实约束（非 MainActor init），需逐个评估替代注入路径。建议放最后，且先做调研。

---

## 6. 风险控制总览

| 阶段 | 风险 | 回滚成本 | 建议节奏 |
|---|---|---|---|
| 0 通知/枚举统一 | 低 | 低（纯重命名/删冗余） | 1 个 PR，立即做 |
| 1 算法回迁 | 中 | 中（移动文件 + 改 import） | 1-2 个 PR |
| 2 拆 Contracts 包 | 高 | 高（依赖图顶层） | 多个 PR：建包→重导出→迁移→断旧路径 |
| 3 ChatService 解耦 | 高 | 中高（易回归） | 3 个子 PR，配测试 |
| 4 UI 上移 | 中 | 中 | 1 个 PR |
| 5 全局状态收敛 | 高 | 高（触及插件单例约束） | 最后做，先调研 |

**贯穿原则**：

- 每个阶段独立可交付、可回滚，不相互阻塞。
- 充分利用 `@_exported import` / `@available(*, deprecated)` 做渐进迁移，允许旧路径与新路径共存一段时间。
- 高风险阶段（2/3/5）配套单元测试为基线，迁移后跑全套测试。
- CoreKit 保留的"通用消息原语"是否算越界，取决于团队对"核心层"的定义——见决策点。

---

## 7. 决策点（动工前需对齐）

这些是影响方案走向的取舍，建议先拍板再动手：

1. **`LumiChatServicing` 协议归属**：留在 CoreKit（现状，依赖倒置代价）/ 下沉到新 Contracts 包 / 移到 App 层胶合。
   - 推荐：下沉到 Contracts 包（阶段 2）。

2. **通用消息原语（`LumiChatMessage`/`LumiToolCall`）归属**：留 CoreKit（领域中立的通用原语）/ 下沉。
   - 推荐：留 CoreKit。CoreKit 保留"通用消息原语"是合理的，它不含聊天业务语义。

3. **CoreKit 的 `AgentTurn/` 模块**：它 post 过 `.lumiTurnFinished`、定义过 `TurnEndReason`——这是否说明 AgentTurn 本身就带 Chat 语义？
   - 需判断：AgentTurn 是"通用 agent 循环原语"（应留 CoreKit，仅去掉 Chat 通知耦合）
     还是"聊天 agent 循环"（应整体下沉）。
   - 推荐：作为通用原语留 CoreKit，但去除它与 Chat 通知名的耦合（阶段 0）。

4. **是否真的需要新包**：拆 `LumiChatContracts` 增加包数量与维护成本。
   - 备选：不拆包，仅把 Chat 文件按"协议/模型/算法"分类整理，接受它们留在 CoreKit。
   - 取舍：拆包结构最干净但成本高；不拆包成本低但 CoreKit 仍"知道"Chat 语义。
   - 推荐：先做阶段 0/1（零/低成本，立即收益），阶段 2 视团队对"包数量"的容忍度再定。

5. **UI 层是否独立成包**：`ChatSectionCoordinator` 移到 LumiAppKit 还是新建 `LumiChatUI` 包。
   - 推荐：先移到 LumiAppKit（最小改动）；若 LumiAppKit 膨胀再拆。

---

## 8. 验收标准（完成后如何判断成功）

- [ ] `grep -r "import LumiChatKit" Packages/LumiCoreKit/Sources/` 为空（已满足，保持）。
- [ ] 每个聊天通知名有且仅有一个发送方，注释标注 owner。
- [ ] `TurnEndReason` / `LumiMessageSaved` 系列无重复定义。
- [ ] CoreKit 不含 token 计算/统计的具体业务算法。
- [ ] `ChatService.swift` < 400 行，主体为转发方法。
- [ ] `SendPipeline` 承担 agent 循环引擎职责，`ChatService` 不直连 `LumiPluginRegistry`。
- [ ] 各 Manager 持有并内聚自己的状态。
- [ ] `LumiChatKit` 不 `import AppKit`（业务协调器上移后）。
- [ ] `grep "nonisolated(unsafe) var" Packages/LumiCoreKit/Sources/` 收敛为 ≤1 个有注释的入口。
- [ ] 全套单元测试通过（`LumiCoreKitTests` + `LumiChatKitTests`）。

---

## 附录 A：关键文件索引

### CoreKit
- `Sources/LumiCore.swift` — 聚合根，`setupChatService`/`boot`/`registerService`
- `Sources/LumiCoreAccessing.swift` — 只读协议 + 启动期协议 + `ChatServiceFactory` 别名（L96）
- `Sources/Chat/LumiChatServicing.swift` — 聊天服务协议（70 行，约 40 方法）
- `Sources/Chat/LumiChatNotifications.swift` — 聊天通知名（越界候选）
- `Sources/Chat/ModelUsageStatsService.swift` — 190 行 token 聚合算法（越界候选）
- `Sources/Chat/LumiConversationContextUsage.swift` — 含 `content.count/4` 估算（越界候选）
- `Sources/AgentTurn/AgentNotifications.swift` — 重复 post `.lumiTurnFinished`（L44,50）
- `Sources/AgentTurn/TurnEndReason.swift` — `TurnEndReason` + `LumiTurnEndReason` 双定义

### ChatKit
- `Sources/ChatService.swift` — 1097 行上帝对象（解耦目标）
- `Sources/Managers/SendPipeline.swift` — agent 循环引擎的归宿
- `Sources/Managers/{Conversation,Message,Provider}Manager.swift` — 状态应下沉到此
- `Sources/Persistence/` — 干净的存储映射层（保持）
- `Sources/ChatSectionCoordinator.swift` — UI 协调器（上移目标）
- `Sources/BuiltInTools/ConversationInfoTool.swift` — 反向抓 `ChatService.shared`（待注入化）

### AppKit（组合根）
- `Sources/LumiAppKit/Services/LumiCoreService.swift:33` — **ChatService 注入点**
- `Sources/LumiAppKit/Bootstrap/RootContainer.swift` — 装配所有服务、接插件线
