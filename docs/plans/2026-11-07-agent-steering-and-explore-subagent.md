# Agent Steering and Read-Only Explore Subagent Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** 在持久 ConversationInput 之上提供可预测的 `next/later` 排队与显式停止后发送，并增加一个复用现有 AgentLoop/ToolManager 的只读 Explore 子代理。

**Architecture:** `next/later` 只是账本中的调度分类，不新建队列或数据库；`now` 是用户明确取消当前 Turn 后再提交的组合动作。Explore 由父 ToolJob 启动，使用同一 `TurnReducer`、LLMManager、ToolManager 和权限链；首版 child LLM 固定走非流式 `complete`，子 transcript 有界且只在内存，最终报告作为父工具结果/Artifact 返回。

**Tech Stack:** Swift 6、Swift Concurrency、Swift Testing、ProviderMessageSender、PluginMessageSender、PluginAgentLoop、ProviderToolManager、PluginToolManager、KitAgentTool。

---

## 1. 前置条件

开始本计划前必须完成并验收：

1. Durable Conversation Input：稳定 commandID、ledger、CAS、FIFO、单点 dispatch。
2. AgentExecutionContext 与 Tool Contract：Trace、deadline、结果预算、Artifact、共享 Tool pipeline。
3. Stream Attempt Recovery：每个 LLM step 新 attempt，final/tool result durable 屏障。
4. Agent Test/Architecture Governance：Factory 装配与故障注入可运行。

如果前置接口名称变化，保持本文件语义并适配当前代码；不要为了匹配示例恢复旧接口。

### 非目标

- 不实现“立即打断正在执行的副作用工具并保证已停止”。`now` 只能请求取消并等待当前 Turn 终态。
- 不让 queued steering 修改当前 LLM 请求中的消息，不在流式中途拼接用户正文。
- 不创建第二套 ToolManager、权限系统、Turn FSM 或消息数据库。
- 不做通用自主子代理平台、写文件子代理、嵌套 Explore 或后台脱离父 Job 的长期任务。
- 不把子代理内部消息混入父会话 MessageModel，避免污染 Resume、压缩和 UI。
- 不让 Explore 绕过工具授权，不自动执行 Shell/MCP 写操作。
- 不承诺父 Turn 崩溃后子任务可恢复；父 ToolJob 结果未知时不自动重放。
- 首版不做 child streaming、child StreamAttemptAnchor 或 child MessageModel 持久化；这些能力需要独立的 child-private transcript schema 专项，不能在 Explore 中附带实现。

## 2. Steering 状态语义

### 2.1 QueueClass

给 ConversationInputCommand/ledger 增加：

```swift
public enum ConversationInputQueueClass: String, Codable, Sendable {
    case next
    case later
}
```

- `later`：普通排队，按 queueSequence FIFO。
- `next`：优先于所有 later，在同为 next 的命令内仍按 queueSequence FIFO。
- 当前 promoting/promoted/dispatching/running 输入不被抢占。
- “next 安全边界”是当前 Turn 到达终态；如果当前 Turn 正 awaitingUser，必须先由用户回答/取消，不能偷偷替换挂起上下文。
- 多个 next 不在首版合并成一条用户消息，每条仍独立 promotion/Turn。

queueClass 是调度 metadata，不是功能 payload：

- `payloadHash` 不覆盖 queueClass。
- queued 状态可通过 `changeQueueClass(commandID:expectedRevision:to:)` CAS 修改，revision+1。
- 一旦 promoting 或更后状态，不允许改 class。
- content、目标、附件、IDs 变化仍必须新 commandID。

### 2.2 `now` 是组合动作，不是第三种持久队列

`interruptAndSubmit` 顺序：

```text
用户看到“当前 LLM/工具可能已产生副作用”的明确确认
→ AgentLoop cancelCurrentRequest
→ 等待当前 Turn 发布 terminal outcome
→ 检查被取消工具的 sideEffectOutcome；unknown 必须保留警告
→ 新 command 以 queueClass=next durable accept
→ 统一 drain promotion/dispatch
```

如果取消等待失败/超时，不自动提交新 Turn；UI 提供重试取消或仍排队为 later 的选择。不能仅调用 `Task.cancel()` 就立即 dispatch。

## 3. Task 1：Ledger QueueClass 与优先 Drain

**Files:**

- Modify: `Packages/ProviderMessageSender/Sources/ProviderMessageSender/ConversationInputCommand.swift`
- Modify: `Packages/ProviderMessageSender/Sources/ProviderMessageSender/ConversationInputManaging.swift`
- Modify: `Packages/PluginMessageManager/Sources/PluginMessageManager/Models/ConversationInputModel.swift`
- Modify: `Packages/PluginMessageManager/Sources/PluginMessageManager/Service/MessageStore+ConversationInput.swift`
- Modify: `Packages/ProviderMessageSender/Sources/ProviderMessageSender/MessageSenderCoordinator.swift`
- Test: `Packages/ProviderMessageSender/Tests/ProviderMessageSenderTests/ConversationInputQueueClassTests.swift`
- Test: `Packages/PluginMessageManager/Tests/PluginMessageManagerTests/ConversationInputQueueClassStoreTests.swift`
- Test: `Packages/ProviderMessageSender/Tests/ProviderMessageSenderTests/MessageSenderSteeringTests.swift`

### Step 1：写失败测试

1. 接受 later A、later B、next C 后，当前 Turn 结束顺序为 C → A → B。
2. next C、next D 之间仍 FIFO。
3. later A 已 promoting 时，新 next C 不抢占 A。
4. queued B 可 CAS 从 later 改 next；旧 revision 修改失败。
5. promoting/promoted/running 修改 class 被拒绝。
6. 同 commandID 重试仅 queueClass 不同时不产生 payload conflict，以持久 revision 操作语义为准；content 不同仍 conflict。
7. App 重启保留 queueClass 与顺序。
8. payloadHash 对同功能 payload 的 class 变化保持稳定。

### Step 2：确认失败

```bash
swift test --package-path Packages/ProviderMessageSender --filter ConversationInputQueueClassTests
swift test --package-path Packages/PluginMessageManager --filter ConversationInputQueueClassStoreTests
swift test --package-path Packages/ProviderMessageSender --filter MessageSenderSteeringTests
```

### Step 3：最小实现

模型字段给已有 queued rows 默认 `.later`，轻量迁移不重写 payload。Store 查询先 next 后 later，各按 queueSequence；选择+CAS lease 在同一 Store 串行边界完成，避免两个 worker 抢同一条。

### Step 4：确认通过

```bash
swift test --package-path Packages/PluginMessageManager
swift test --package-path Packages/ProviderMessageSender
swift test --package-path Packages/PluginMessageSender
```

### Step 5：独立提交

```bash
git add Packages/ProviderMessageSender Packages/PluginMessageManager Packages/PluginMessageSender
git diff --cached --check
git commit -m "feat(ProviderMessageSender): prioritize queued steering inputs"
```

## 4. Task 2：显式 Interrupt-and-Submit 与 UI

**Files:**

- Modify: `Packages/ProviderMessageSender/Sources/ProviderMessageSender/MessageSendingProviding.swift`
- Modify: `Packages/ProviderMessageSender/Sources/ProviderMessageSender/MessageSenderCoordinator.swift`
- Modify: `Packages/ProviderMessageSender/Sources/ProviderMessageSender/DefaultMessageSender.swift`
- Modify: `Packages/PluginMessageSender/Sources/PluginMessageSender/Providers/MessageSender.swift`
- Modify: `Packages/PluginConversationInput/Sources/PluginConversationInput/ViewModels/ConversationInputViewModel.swift`
- Modify: `Packages/PluginConversationInput/Sources/PluginConversationInput/ViewModels/SendActionBarViewModel.swift`
- Modify: relevant queued-message view
- Test: `Packages/ProviderMessageSender/Tests/ProviderMessageSenderTests/InterruptAndSubmitTests.swift`
- Test: `Packages/PluginConversationInput/Tests/PluginConversationInputTests/SteeringPresentationTests.swift`

### Step 1：写失败测试

- busy 普通发送默认 later；“下一条发送”生成 next。
- queued UI 分组和顺序来自 ledger projection，不维护第二数组。
- interruptAndSubmit 在 current Turn terminal 之前不 accept/dispatch 新 command。
- 非协作工具取消后 unknown 时，UI 警告仍在；新 Turn 不自动重放旧工具。
- cancel 失败不丢 draft，不提交新 command；用户可恢复。
- 双击“停止并发送”只运行一个组合动作。
- 两个 Sender 实现行为一致，queued cancel/reprioritize 重启后正确。

### Step 2：确认失败

```bash
swift test --package-path Packages/ProviderMessageSender --filter InterruptAndSubmitTests
swift test --package-path Packages/PluginConversationInput --filter SteeringPresentationTests
swift test --package-path Packages/PluginMessageSender
```

### Step 3：最小实现

新增一个 MainActor async requirement，两个 Sender 委托 coordinator。UI 复用现有停止确认和 queued 视图，不新造全屏队列管理。`next/later` 的文案清楚说明“当前回合结束后”，避免暗示立即中断。

### Step 4：确认通过

```bash
swift test --package-path Packages/ProviderMessageSender
swift test --package-path Packages/PluginMessageSender
swift test --package-path Packages/PluginConversationInput
swift test --package-path Packages/FactoryLumi
```

### Step 5：独立提交

```bash
git add Packages/ProviderMessageSender Packages/PluginMessageSender Packages/PluginConversationInput Packages/FactoryLumi
git diff --cached --check
git commit -m "feat(PluginConversationInput): add safe steering queue actions"
```

## 5. Explore 子代理契约

### 5.1 Run 限制

新建 `Packages/PluginAgentLoop/Sources/PluginAgentLoop/Subagents/ExploreSubagentTypes.swift`：

```swift
public struct ExploreSubagentRequest: Sendable, Equatable {
    public let objective: String
    public let parentConversationID: UUID
    public let parentTurnID: UUID
    public let execution: AgentExecutionContext
}

public struct ExploreSubagentLimits: Sendable, Equatable {
    public let maxTurns: Int       // default 4
    public let maxToolCalls: Int   // default 12
    public let maxReportBytes: Int // default 32 * 1024
}

public enum ExploreSubagentTermination: String, Sendable {
    case completed
    case turnLimit
    case toolCallLimit
    case cancelled
    case timedOut
    case failed
}
```

实际 initializer 给 limits 默认值并校验正数。deadline 取父 execution.deadline 与 Explore executionLimits.timeout 的较早值。

### 5.2 只读 Tool Policy

`ExploreToolPolicy` 同时要求：

1. 工具名在明确 allowlist（读取文件、搜索、git status/diff/log 等现有只读工具；按当前名称登记）。
2. `executionCapability == .parallelReadOnly`。
3. `sideEffectScope(arguments:) == .readOnly`。
4. `permissionRiskLevel(arguments:)` 为 safe/low，且不 `requiresExplicitApproval`。
5. 非 Shell、非通用代码执行、非 MCP、非 Explore 自身、非 AskUser/交互工具。

即使工具名叫 read，只要参数动态判定写风险也拒绝。拒绝结果作为 child tool error 返回给子模型，不直接执行，不在父会话创建未授权副作用。

所有允许调用仍通过 ToolManager 创建真实 ToolJob，保留审计、deadline、结果 finalizer 与 Trace；禁止 runner 直接 `tool.executeResult` 绕过管理器。

### 5.3 子 Transcript

- 内存中有界数组，使用与父 AgentLoop 相同的 LLMMessage/tool_use/tool_result 配对校验。
- 不写任何父会话 MessageModel，也不写同 conversationID 的 child assistant MessageModel；因此不会进入父时间线、导出、compact、Resume 或下一次父 LLM 历史。
- 首版每个 child LLM step 固定调用现有 `LLMManaging.complete`（非流式），拿到完整 `LLMResponse` 后复用父 AgentLoop 的 final response/tool-call 校验，再送入 `TurnReducer.llmResponded`。禁止调用 `streamComplete`，也不创建 StreamAttemptAnchor；这样不存在 checkpoint 自动 upsert 父时间线的问题。
- 每个 step 仍新建本地 `childAttemptID` 与 child span，仅用于取消、迟到完整响应防护和审计关联；它不是 durable stream attempt。旧 step 的完整响应若在 cancel/新 step 后到达，直接丢弃，不 reduce、不执行工具。
- child 工具结果仍通过 ToolManager 的 durable-result 屏障，确认持久化后才发起下一 child LLM `complete`。父 ToolJob 只持久化 Explore 最终 report/error；中间 child transcript 不做 durable checkpoint，崩溃后按 outcomeUnknown，不自动重启 child。
- 最终只把 report 和必要统计返回父工具；完整报告超预算走 Artifact。

## 6. Task 3：ExploreToolPolicy 与 Child Trace

**Files:**

- Create: `Packages/PluginAgentLoop/Sources/PluginAgentLoop/Subagents/ExploreSubagentTypes.swift`
- Create: `Packages/PluginAgentLoop/Sources/PluginAgentLoop/Subagents/ExploreToolPolicy.swift`
- Test: `Packages/PluginAgentLoop/Tests/PluginAgentLoopTests/ExploreToolPolicyTests.swift`
- Test: `Packages/PluginAgentLoop/Tests/PluginAgentLoopTests/ExploreSubagentContextTests.swift`

### Step 1：写失败测试

用 fake tools 逐项验证 allowlist + capability + sideEffect + risk 五个条件，任一不满足都拒绝。特别覆盖：

- 名称看似只读但 scope=workspaceWrite。
- MCP readOnlyHint 仍因首版策略被排除。
- Shell `git status` 也不因参数看似安全而绕过 Shell 排除。
- requiresExplicitApproval=true 永不自动放行。
- Explore 工具自身被排除，不能递归。
- child context traceID 同父，spanID 新建，parent 为 Explore ToolJob span；child turnID 新，conversationID 保持父项目身份。
- deadline 取最早值，取消只传播，不伪造副作用完成。

### Step 2：确认失败

```bash
swift test --package-path Packages/PluginAgentLoop --filter ExploreToolPolicyTests
swift test --package-path Packages/PluginAgentLoop --filter ExploreSubagentContextTests
```

### Step 3：最小实现

实现纯 policy 和 context mapping，不接 LLM。allowlist 是显式集合，不用字符串包含 `read/search` 自动推断。

### Step 4：确认通过

```bash
swift test --package-path Packages/PluginAgentLoop
swift test --package-path Packages/KitAgentTool
```

### Step 5：独立提交

```bash
git add Packages/PluginAgentLoop Packages/KitAgentTool
git diff --cached --check
git commit -m "feat(PluginAgentLoop): define read-only explore tool policy"
```

## 7. Task 4：复用 TurnReducer 的 Explore Runner

**Files:**

- Create: `Packages/PluginAgentLoop/Sources/PluginAgentLoop/Subagents/ExploreSubagentRunner.swift`
- Create: `Packages/PluginAgentLoop/Sources/PluginAgentLoop/Subagents/ExploreSubagentTool.swift`
- Modify: `Packages/PluginAgentLoop/Sources/PluginAgentLoop/Managers/AgentLoopManager.swift` only to expose shared services through existing internal composition
- Test: `Packages/PluginAgentLoop/Tests/PluginAgentLoopTests/ExploreSubagentRunnerTests.swift`
- Test: `Packages/PluginAgentLoop/Tests/PluginAgentLoopTests/ExploreSubagentToolTests.swift`

### Step 1：写失败测试

1. fake LLM 请求读取文件 → 收到 tool result → 最终报告，runner 完成且父工具收到 report。
2. 模型请求写文件：policy 拒绝，ToolManager execute 次数为 0，child 可修正并最终回答。
3. 所有允许工具调用通过 ToolManager，有真实 jobID/audit/trace。
4. 超过 maxTurns/maxToolCalls 返回对应 termination 和已收集的部分报告，不无限循环。
5. malformed child tool call 使用现有 correction 预算，不执行半成品。
6. fake LLM 的 `streamComplete` 若被调用直接让测试失败；每步 `complete` 使用新 childAttemptID/span，旧 step 的迟到完整响应被丢弃，最终 tool result durable 后才下一请求。
7. child 消息不插入父 MessageManager，StreamAttemptAnchor Store 的写入次数为 0，父历史只出现 Explore 父工具调用/结果。
8. report 超 maxReportBytes 写 Artifact，父模型只收 preview。
9. runner 不调用 UI 当前 selectedConversation，项目路径来自 parentConversationID。

### Step 2：确认失败

```bash
swift test --package-path Packages/PluginAgentLoop --filter ExploreSubagentRunnerTests
swift test --package-path Packages/PluginAgentLoop --filter ExploreSubagentToolTests
```

### Step 3：最小实现

Runner 是子执行协调器，不是新 FSM：

- 持有 `TurnRuntime`，调用现有 `TurnReducer.reduce`。
- 调用现有 LLMManager 的 `complete` 与 ToolManager，不调用 StreamAttempt committer/finalizer；完整响应复用现有 final tool-call validator 后才能 reduce 为 `.llmResponded`。
- 每个 child step 开始时生成 childAttemptID/child span，await `complete` 后先核对当前 step 与取消状态；旧响应不进入 reducer。childAttemptID 只存在于 runner/audit，不写入父功能消息。
- tool call 提交前用 ExploreToolPolicy 过滤；拒绝项生成普通 child tool error，不进入 ToolManager。
- 允许的 child 工具完成后 await `durableToolResult(forToolCallID:conversationID:turnID:)`，使用 child turnID 和父 conversationID 限定作用域，再写 child 内存 tool_result 并进入下一 `complete`。
- 只保留本 child 的 LLMMessage transcript，父消息存储只由 Explore 父 ToolJob 写入最终 report/error；不持久化中间 transcript，崩溃恢复不重建 runner。
- maxTurns/maxToolCalls/deadline 在每个步骤前检查，错误最终只 resume continuation 一次。

ExploreSubagentTool 本身首版 `executionCapability = .serialSideEffect`，避免并行启动多个 LLM/文件扫描；workspace sideEffectScope 可声明 readOnly，但调度不因此放开。

### Step 4：确认通过

```bash
swift test --package-path Packages/PluginAgentLoop
swift test --package-path Packages/ProviderAgentLoop
swift test --package-path Packages/ProviderToolManager
swift test --package-path Packages/PluginToolManager
swift test --package-path Packages/PluginMessageManager
```

### Step 5：独立提交

```bash
git add Packages/PluginAgentLoop Packages/ProviderAgentLoop Packages/ProviderToolManager Packages/PluginToolManager Packages/PluginMessageManager
git diff --cached --check
git commit -m "feat(PluginAgentLoop): run bounded read-only explore subagents"
```

## 8. Task 5：取消、超时、崩溃与 Artifact

**Files:**

- Modify: `Packages/PluginAgentLoop/Sources/PluginAgentLoop/Subagents/ExploreSubagentRunner.swift`
- Modify: `Packages/PluginAgentLoop/Sources/PluginAgentLoop/Subagents/ExploreSubagentTool.swift`
- Test: `Packages/PluginAgentLoop/Tests/PluginAgentLoopTests/ExploreSubagentCancellationTests.swift`
- Test: `Packages/PluginAgentLoop/Tests/PluginAgentLoopTests/ExploreSubagentCrashTests.swift`
- Test: `Packages/PluginToolManager/Tests/PluginToolManagerTests/ExploreToolJobTests.swift`

### Step 1：写失败测试

- 父 ToolJob cancel 传播到当前 child LLM request/ToolJob；后续不启动新 step。
- 协作只读工具及时取消；非协作工具 late completion 不覆盖父结果。
- parent deadline 先到时 termination=timedOut，sideEffectOutcome 只描述实际已知事实。
- 父进程在 child LLM/工具执行中消失：重启父 Job outcomeUnknown，不自动启动新 Explore。
- Artifact 写失败时父 ToolJob 显示结果交付失败，不重跑已完成的读取/LLM（是否允许用户显式重试由现有 UI 决定）。
- 连续完成/取消/超时竞争只产生一个父 ToolJob 终态。
- child report 中文件内容造成的指令文本只作为数据，不改变 tool policy。

### Step 2：确认失败

```bash
swift test --package-path Packages/PluginAgentLoop --filter ExploreSubagentCancellationTests
swift test --package-path Packages/PluginAgentLoop --filter ExploreSubagentCrashTests
swift test --package-path Packages/PluginToolManager --filter ExploreToolJobTests
```

### Step 3：最小实现

把 parent context cancellation closure传入每个 child step；child 不拥有脱离父 Job 的 unstructured task。完整报告先写 Artifact，再发布父结果；任何 failure 都走现有 Tool pipeline 的 outcome mapping。

### Step 4：确认通过

```bash
swift test --package-path Packages/PluginAgentLoop
swift test --package-path Packages/PluginToolManager
swift test --package-path Packages/ProviderToolManager
swift test --package-path Packages/PluginConversationResume
```

### Step 5：独立提交

```bash
git add Packages/PluginAgentLoop Packages/PluginToolManager Packages/ProviderToolManager Packages/PluginConversationResume
git diff --cached --check
git commit -m "fix(PluginAgentLoop): bound explore cancellation and recovery"
```

## 9. Task 6：生产注册与端到端验收

**Files:**

- Modify: `Packages/FactoryLumi/Sources/FactoryLumi` existing AgentLoop/ToolManager composition
- Modify: `Packages/PluginAgentLoop/Sources/PluginAgentLoop/PluginAgentLoop.swift` only if tools are contributed through its existing lifecycle
- Test: `Packages/FactoryLumi/Tests/FactoryLumiTests/ExploreSubagentAssemblyTests.swift`
- Test: `Packages/FactoryLumi/Tests/FactoryLumiTests/AgentSteeringAssemblyTests.swift`
- Test: `Packages/PluginMessageRenderer/Tests/PluginMessageRendererTests/ExploreToolRenderingTests.swift`

### Step 1：写失败装配与渲染测试

- 生产 ToolRegistry 只有一个 Explore 工具，使用真实 runner/services，不是 fake。
- Explore 不出现在自己的 child allowlist。
- 父工具 UI 显示目标、状态、turn/tool 使用计数、termination 和 Artifact 链接。
- queued steering 在真实生产 Sender 可用，重启投影一致。
- 禁用 AgentLoop/ToolManager Plugin 后 Explore 不残留可用工具或后台任务。

### Step 2：确认失败并最小装配

```bash
swift test --package-path Packages/FactoryLumi --filter ExploreSubagentAssemblyTests
swift test --package-path Packages/FactoryLumi --filter AgentSteeringAssemblyTests
swift test --package-path Packages/PluginMessageRenderer --filter ExploreToolRenderingTests
```

只通过现有插件贡献/注册机制添加工具，不让 Explore 自己修改全局 Registry。

### Step 3：运行完整相关矩阵

```bash
swift test --package-path Packages/ProviderMessageSender
swift test --package-path Packages/PluginMessageSender
swift test --package-path Packages/PluginMessageManager
swift test --package-path Packages/PluginConversationInput
swift test --package-path Packages/ProviderAgentLoop
swift test --package-path Packages/PluginAgentLoop
swift test --package-path Packages/ProviderToolManager
swift test --package-path Packages/PluginToolManager
swift test --package-path Packages/PluginConversationResume
swift test --package-path Packages/PluginMessageRenderer
swift test --package-path Packages/PluginConversationExport
swift test --package-path Packages/FactoryLumi
```

再运行 `Scripts/run-agent-reliability-tests.sh all` 和全包测试。

### Step 4：真实 App 验证

1. busy Turn 中依次发送 later A、next B、later C：当前 Turn 后 B → A → C，消息 ID 与顺序稳定。
2. 将 queued A 改为 next，重启后优先级仍正确；已 promoted 项不能修改。
3. 执行“停止并发送”：只有当前 Turn terminal 后新 Turn 开始；工具 unknown 警告可见。
4. 让 Explore 阅读一个小型测试项目：只调用只读工具，报告引用正确文件，父会话没有 child 中间消息。
5. 要求 Explore 修改文件/运行 Shell/MCP：全部拒绝，真实文件无变化，审计记录拒绝原因。
6. 大报告生成 Artifact，父模型收 preview，UI/导出可读取 reference。
7. 取消/超时/强制退出：无脱离父 Job 的后台 Explore，重启不自动重跑，Resume 文案不声称未执行。
8. 普通父 Agent 工具、授权、compact、Resume、消息渲染无回归。

### Step 5：独立提交

```bash
git add Packages/FactoryLumi Packages/PluginAgentLoop Packages/PluginMessageRenderer
git diff --cached --check
git commit -m "test(FactoryLumi): verify steering and explore assembly"
```

## 10. 完成定义

- next/later 只是持久账本调度分类，FIFO/CAS/重启语义有测试；没有第二个内存队列。
- `now` 始终先请求取消并等待当前 Turn terminal，不把 cancelRequested 当副作用停止。
- Explore 复用 TurnReducer、LLMManager、ToolManager 与权限/审计链；首版 child 固定非流式 `complete`，不创建 StreamAttemptAnchor。
- 五重只读 policy 全部满足才执行，Shell/MCP/交互/嵌套 Explore 首版明确排除。
- child transcript 不污染父消息历史；最终报告受预算控制，Artifact 全链路可用。
- parent/child Trace 关联正确，取消、超时、崩溃与 late completion 不导致重放或悬挂。
- Factory 真实装配和 App 手工路径通过，未用 fake runner 替代生产验收。
