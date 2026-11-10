# Stream Attempt Anchoring and Recovery Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** 让每次 LLM 流式请求都有持久 attempt 锚点和稳定 assistantMessageID，断流后只从最后提交状态恢复，并为 assistant tool call 与 tool result 建立 durable 屏障。

**Architecture:** AgentLoop 拥有 attempt 生命周期，`StreamAttemptAnchorModel` 与 MessageModel 共用 MessageStore；`StreamAttemptCommitter` 串行化 checkpoint/final 并拒绝旧 revision。网络层保留“首个 SSE 前才可安全请求重试”的现有策略，AgentLoop 在其上实现新 attempt 恢复，不做通用 token 续流。

**Tech Stack:** Swift 6、Swift Concurrency、SwiftData、Swift Testing、KitLLM、ProviderAgentLoop、PluginAgentLoop、PluginMessageManager、ProviderToolManager、PluginConversationResume。

---

## 1. 与现有计划的关系

本计划承接而不是重复：

- `docs/plans/2026-09-01-agent-loop-tool-call-recovery.md`：负责 malformed/truncated tool call 的协议校验与有界 correction retry。
- 现有 `VendorAPIService` 请求重试：只覆盖收到首个 SSE 前的安全重试，避免重复 token。
- 现有 ToolJob：负责授权、执行、取消与 Job 持久化，不自动重跑启动时发现的未知 Job。
- 现有 Resume：负责回合崩溃记录与孤儿 tool call 修复。

本计划新增的是“哪一个 assistant attempt 的哪一段内容已经 durable”这一事实，以及事件发布顺序。

### 非目标

- 不支持供应商没有的 token 级 continuation，不伪造 response ID 续传。
- 不把未提交流式 tail、半成品 tool call 或 raw SSE 当作模型历史事实。
- 不跨 MessageStore、ToolJob Store、Resume JSON 声明原子事务。
- 不重写 AgentTurnFSM；只增加 attempt identity/context 和 durable 前置条件。
- 不自动重放已开始的副作用工具，不承诺 LLM/工具 exactly-once。
- 不通过增加 raw stream 采集实现恢复；诊断 capture 默认关闭。

## 2. 核心模型

### 2.1 LLMStreamSnapshot

新建 `Packages/KitLLM/Sources/KitLLM/Core/LLMStreamSnapshot.swift`：

```swift
public struct LLMStreamSnapshot: Codable, Sendable, Equatable {
    public let content: String
    public let reasoningContent: String?
    public let toolCalls: [LLMToolCall]?
    public let inputTokenCount: Int?
    public let outputTokenCount: Int?
    public let cachedInputTokenCount: Int?
    public let cacheWriteInputTokenCount: Int?
    public let cacheTotalInputTokenCount: Int?
    public let responseID: String?
    public let stopReason: String?
    public let isFinal: Bool
}
```

rawResponse/rawStreamEvents 不进入快照。中间快照的 toolCalls 只是候选，不能直接被 ToolManager 执行；只有 final snapshot 通过现有 `validateToolCallArguments()` 后才能成为 MessageModel 的可执行 tool calls。

### 2.2 Anchor 值与协议

新建 `Packages/ProviderAgentLoop/Sources/ProviderAgentLoop/StreamAttemptAnchoring.swift`：

```swift
public enum StreamAttemptPhase: String, Codable, Sendable {
    case streaming
    case completed
    case interrupted
    case failed
    case cancelled
}

public struct StreamAttemptAnchor: Sendable, Equatable {
    public let conversationID: UUID
    public let turnID: UUID
    public let attemptID: UUID
    public let assistantMessageID: UUID
    public let requestOrdinal: Int
    public let revision: Int64
    public let phase: StreamAttemptPhase
    public let snapshot: LLMStreamSnapshot
    public let updatedAt: Date
    public let lastErrorCode: String?
}

public protocol StreamAttemptAnchoring: AnyObject {
    func beginStreamAttempt(
        conversationID: UUID,
        turnID: UUID,
        attemptID: UUID,
        assistantMessageID: UUID,
        requestOrdinal: Int
    ) async throws -> StreamAttemptAnchor

    func commitStreamAttempt(
        _ anchor: StreamAttemptAnchor,
        expectedRevision: Int64
    ) async throws -> StreamAttemptAnchor

    func latestStreamAttempt(
        conversationID: UUID,
        turnID: UUID
    ) async -> StreamAttemptAnchor?
}
```

协议放在 ProviderAgentLoop 是因为它描述 AgentLoop 的恢复需求；PluginMessageManager 可实现它，ProviderAgentLoop 不 import Plugin。

### 2.3 持久模型

新建 `Packages/PluginMessageManager/Sources/PluginMessageManager/Models/StreamAttemptAnchorModel.swift`：

```text
attemptID: String，unique
conversationID: String，indexed
turnID: String，indexed
assistantMessageID: String，unique
requestOrdinal: Int
revision: Int64
phase: String
snapshotJSON: Data
lastErrorCode: String?
updatedAt: Date
```

`(turnID, requestOrdinal)` 也必须有应用层唯一校验；macOS 14 下可沿用 MessageStore 原生 SQLite index 的方式建立复合索引，不依赖仅新版本可用的宏。

Schema 变为同一个 container 中的：

```swift
Schema([
    MessageModel.self,
    ConversationInputModel.self, // 若持久输入计划已落地
    StreamAttemptAnchorModel.self,
])
```

如果单独执行本计划而 ConversationInputModel 尚不存在，保留其插入点但不要在代码中引用不存在的类型；整合时必须合并 Schema，不能后执行者把前者删掉。

### 2.4 Attempt 规则

- 每次新 Turn 的第一次 LLM request 创建 attempt；每个工具批次后的下一 LLM step 也创建新 attempt。
- attemptID、assistantMessageID 在请求前分配并 durable begin；begin 失败则不发送 LLM 请求。
- 同一 attempt 的 checkpoint/final 复用 assistantMessageID。
- 网络层同一 attempt 内“首事件前 retry”复用 attempt identity；一旦收到事件后需要 AgentLoop 恢复，必须新 attemptID + 新 assistantMessageID。
- requestOrdinal 从 0 单调递增；旧 attempt 的回调不能覆盖更新的 ordinal/revision。
- completed/failed/interrupted/cancelled 为 anchor 终态；迟到 checkpoint 不得把终态改回 streaming。

## 3. Durable 事件顺序

### 正常 assistant 最终回复

```text
begin anchor(streaming) durable
→ 发送 LLM request
→ 0..N 次 checkpoint(anchor + 同一 assistant message) durable
→ final response 校验
→ final commit(anchor completed + assistant message) durable
→ 发布 final MessageChange / AgentLoop llmResponded
→ TurnReducer 进入 completed
```

### assistant tool call

```text
final tool call JSON 校验
→ assistant message（含 tool_calls）+ anchor completed 同事务 durable
→ 发布 tool call 事件
→ ToolManager submit / 创建 ToolJob durable record
→ 授权与执行
```

任何 final commit 失败都不得提交工具执行。

### tool result → 下一 LLM step

```text
ToolJob result durable
→ tool MessageModel durable upsert（稳定 toolCallID）
→ 更新 assistant 展示快照
→ 创建下一 attempt durable begin
→ 发送下一 LLM request
```

MessageStore 与 ToolJob Store 不原子，因此每一步都可重放 upsert，且只有前一步成功才进入下一步。

### 断流恢复

```text
记录 live snapshot（可领先 durable）
→ 错误发生
→ 读取最后 committed anchor/snapshot
→ 旧 attempt 标 interrupted durable
→ live projection 回滚到 committed prefix，丢弃未提交 tail
→ 使用现有有界恢复预算
→ 新 attemptID/assistantMessageID/requestOrdinal+1 durable begin
→ 新 LLM request
```

旧 committed prefix 可留在历史中，并配合现有一次性 recovery hint 要求模型避免重复；这不是 token continuation。若预算耗尽，Turn 进入可操作的 failed/paused 状态，不留下悬挂 continuation。

## 4. Task 1：Snapshot、Anchor 协议与 FSM 身份

**Files:**

- Create: `Packages/KitLLM/Sources/KitLLM/Core/LLMStreamSnapshot.swift`
- Create: `Packages/ProviderAgentLoop/Sources/ProviderAgentLoop/StreamAttemptAnchoring.swift`
- Modify: `Packages/PluginAgentLoop/Sources/PluginAgentLoop/AgentTurnFSM.swift`
- Test: `Packages/KitLLM/Tests/KitLLMTests/LLMStreamSnapshotTests.swift`
- Test: `Packages/ProviderAgentLoop/Tests/ProviderAgentLoopTests/StreamAttemptAnchorTests.swift`
- Test: `Packages/PluginAgentLoop/Tests/PluginAgentLoopTests/AgentTurnFSMTests.swift`

### Step 1：写失败测试

- LLMResponse → snapshot 保留功能字段，不含 raw diagnostics。
- startTurn 初始化 requestOrdinal=0/currentAttempt=nil；每次进入新 LLM step 请求 ordinal+1。
- 工具完成导致下一 LLM step 时必须产生新 attempt，而不是复用上一个 assistantMessageID。
- 同一 attempt 网络首事件前 retry 不增加 ordinal。
- 旧 attemptID 的 llmResponded/失败事件被 reducer 忽略；当前 attempt 才处理。
- 现有 llmRecoveryAttempts 仍在同一 Turn 内受限，新 attempt 不能重置总预算。

可在 `TurnRuntime` 添加：

```swift
public var currentAttemptID: UUID?
public var currentAssistantMessageID: UUID?
public var nextRequestOrdinal: Int
public var committedStreamRevision: Int64
```

TurnEvent 的 LLM 响应/失败需要携带 attemptID；不要仅凭 assistantMessageID 猜。

### Step 2：确认失败

```bash
swift test --package-path Packages/KitLLM --filter LLMStreamSnapshotTests
swift test --package-path Packages/ProviderAgentLoop --filter StreamAttemptAnchorTests
swift test --package-path Packages/PluginAgentLoop --filter AgentTurnFSMTests
```

### Step 3：最小实现

添加值类型和 reducer 身份，不接 I/O。保留现有 phase 名称；如果需要携带 attempt，可优先放 TurnRuntime，避免把所有 TurnPhase associated values 改得过大。

### Step 4：确认通过

```bash
swift test --package-path Packages/KitLLM
swift test --package-path Packages/ProviderAgentLoop
swift test --package-path Packages/PluginAgentLoop
```

### Step 5：独立提交

```bash
git add Packages/KitLLM Packages/ProviderAgentLoop Packages/PluginAgentLoop
git diff --cached --check
git commit -m "feat(ProviderAgentLoop): track stream attempt identity"
```

## 5. Task 2：Anchor + Message 同事务 Store

**Files:**

- Create: `Packages/PluginMessageManager/Sources/PluginMessageManager/Models/StreamAttemptAnchorModel.swift`
- Create: `Packages/PluginMessageManager/Sources/PluginMessageManager/Service/MessageStore+StreamAttempt.swift`
- Modify: `Packages/PluginMessageManager/Sources/PluginMessageManager/Service/MessageStore.swift`
- Modify: `Packages/PluginMessageManager/Sources/PluginMessageManager/Managers/MessageManager.swift`
- Modify: `Packages/PluginMessageManager/Package.swift` for ProviderAgentLoop if not already present
- Test: `Packages/PluginMessageManager/Tests/PluginMessageManagerTests/StreamAttemptStoreTests.swift`
- Test: `Packages/PluginMessageManager/Tests/PluginMessageManagerTests/StreamAttemptMigrationTests.swift`

### Step 1：写失败测试

- begin 返回前 anchor 已 save；相同 attemptID begin 幂等，不同 IDs/ordinal conflict。
- checkpoint 在 expectedRevision 匹配时，同一事务 upsert anchor 与预分配 assistantMessageID 的 MessageModel，只 save 一次。
- final completed 同样一次 save；中间 checkpoint 不写可执行 toolCalls 到 MessageModel。
- stale revision、旧 ordinal、终态后 checkpoint 全部拒绝且不修改消息。
- save 失败时 anchor 与 message 不出现半提交；重试同一 snapshot 可成功。
- completed anchor 重启后可读取，assistantMessageID 稳定。
- 旧消息库轻量迁移，历史消息、raw 字段与索引不变。

### Step 2：确认失败

```bash
swift test --package-path Packages/PluginMessageManager --filter StreamAttemptStoreTests
swift test --package-path Packages/PluginMessageManager --filter StreamAttemptMigrationTests
```

### Step 3：最小实现

Store lock 内独立 ModelContext 完成 fetch/upsert/CAS/save。`snapshotJSON` 可保存中间候选 tool calls 供诊断恢复判断，但 `MessageModel.toolCallsJson` 只在 final 且验证通过后写入。

MessageManager 在 save 成功后更新 live projection：中间 checkpoint 发 updated/inserted 事件，final 发 persisted 事件。durable API 的返回值不依赖 write-behind flush。

### Step 4：确认通过

```bash
swift test --package-path Packages/PluginMessageManager
swift test --package-path Packages/ProviderMessage
swift test --package-path Packages/ProviderAgentLoop
```

### Step 5：独立提交

```bash
git add Packages/PluginMessageManager Packages/ProviderMessage Packages/ProviderAgentLoop
git diff --cached --check
git commit -m "feat(PluginMessageManager): persist stream attempt anchors"
```

## 6. Task 3：串行 StreamAttemptCommitter 与迟到回调防护

**Files:**

- Create: `Packages/PluginAgentLoop/Sources/PluginAgentLoop/Managers/StreamAttemptCommitter.swift`
- Modify: `Packages/PluginAgentLoop/Sources/PluginAgentLoop/Managers/AgentLoopProvider+Message.swift`
- Test: `Packages/PluginAgentLoop/Tests/PluginAgentLoopTests/StreamAttemptCommitterTests.swift`

### Step 1：写失败测试

用可控 fake Store 阻塞 save，验证：

1. 快速 1000 个 chunk 不产生 1000 次同步磁盘写；按时间/字节阈值 coalesce。
2. 所有实际写按 revision 顺序，final 等待之前 checkpoint 完成。
3. final 后还有排队 checkpoint 时，final 是最后一次写且内容完整。
4. commit 失败向后传播，final 不发布成功事件。
5. 旧 attempt 回调在新 attempt begin 后被丢弃，不调用 Store。
6. cancel 与 final 竞争只有一个终态； continuation 不泄漏。
7. live snapshot 可领先 committed，但恢复读取的是 committed，不是最新内存 tail。

建议策略：交互 checkpoint 最多每 500ms 或累计 64KiB 一次，收到完整 tool call/final 时强制 flush。阈值注入测试，不用真实 sleep 证明逻辑。

### Step 2：确认失败

```bash
swift test --package-path Packages/PluginAgentLoop --filter StreamAttemptCommitterTests
```

### Step 3：最小实现

用 actor 或 MainActor 内的串行状态 + 单一 flush task 管理 `latestLiveSnapshot`、`pendingSnapshot`、`committedAnchor`、`flushTask`。不要为每个 chunk 创建无法追踪的 detached task。

API 至少包括 begin/live/checkpoint/finish/interrupt/cancel；finish 必须等待队列清空并返回 durable anchor。旧 attempt 由 identity + revision 双重 guard。

### Step 4：确认通过

```bash
swift test --package-path Packages/PluginAgentLoop
swift test --package-path Packages/PluginMessageManager
```

### Step 5：独立提交

```bash
git add Packages/PluginAgentLoop Packages/PluginMessageManager
git diff --cached --check
git commit -m "fix(PluginAgentLoop): serialize durable stream checkpoints"
```

## 7. Task 4：AgentLoop 请求与 Final 屏障接入

**Files:**

- Modify: `Packages/PluginAgentLoop/Sources/PluginAgentLoop/Managers/AgentLoopProvider+Turn.swift`
- Modify: `Packages/PluginAgentLoop/Sources/PluginAgentLoop/Managers/AgentLoopProvider+Message.swift`
- Modify: `Packages/PluginAgentLoop/Sources/PluginAgentLoop/Managers/AgentLoopProvider+Tool.swift`
- Modify: `Packages/PluginAgentLoop/Sources/PluginAgentLoop/Managers/AgentLoopManager.swift` only for capability wiring
- Modify: `Packages/FactoryLumi/Sources/FactoryLumi` existing AgentLoop/MessageManager composition
- Test: `Packages/PluginAgentLoop/Tests/PluginAgentLoopTests/StreamAttemptIntegrationTests.swift`
- Test: `Packages/FactoryLumi/Tests/FactoryLumiTests/StreamAttemptAssemblyTests.swift`

### Step 1：写失败测试

- begin anchor 失败时 LLM provider 调用次数为 0。
- 每次 LLM step begin 新 attempt，request 的 executionContext 与 attempt IDs 对应。
- final assistant 无工具：Store final save 未完成前 Turn 不 completed；完成后才发送 outcome。
- final assistant 有工具：final save 未完成前 ToolManager submit 次数为 0；成功后按原授权流程执行。
- malformed final tool arguments 走现有 correction recovery，不写可执行 tool call、不提交工具。
- routed retry/fallback 不错误创建多个 attempt；首事件后的 AgentLoop recovery才创建。
- Factory 生产 AgentLoop 注入真实 StreamAttemptAnchoring，而非 nil/default memory fallback。

### Step 2：确认失败

```bash
swift test --package-path Packages/PluginAgentLoop --filter StreamAttemptIntegrationTests
swift test --package-path Packages/FactoryLumi --filter StreamAttemptAssemblyTests
```

### Step 3：最小实现

把当前“收到 response 后先 insertMessage/发事件”的路径改为 committer.finish 后置。live chunk 仍可更新 UI，但所有 TurnReducer final 事件必须携带已提交 anchor。

AgentLoopManager 通过构造参数/能力注入 Anchor；禁止在 AgentLoop 内直接 new MessageStore 或访问数据库路径。

### Step 4：确认通过

```bash
swift test --package-path Packages/PluginAgentLoop
swift test --package-path Packages/ProviderAgentLoop
swift test --package-path Packages/PluginMessageManager
swift test --package-path Packages/FactoryLumi
```

### Step 5：独立提交

```bash
git add Packages/PluginAgentLoop Packages/ProviderAgentLoop Packages/PluginMessageManager Packages/FactoryLumi
git diff --cached --check
git commit -m "fix(PluginAgentLoop): commit stream finals before publishing outcomes"
```

## 8. Task 5：Committed-Anchor 断流恢复

**Files:**

- Create: `Packages/PluginAgentLoop/Sources/PluginAgentLoop/Managers/StreamRecoveryCoordinator.swift`
- Modify: `Packages/PluginAgentLoop/Sources/PluginAgentLoop/Managers/AgentLoopProvider+Turn.swift`
- Modify: `Packages/PluginAgentLoop/Sources/PluginAgentLoop/AgentTurnFSM.swift`
- Modify: `Packages/KitLLM/Sources/KitLLM/Support/VendorAPIService.swift` only to expose existing retry classification, not to broaden replay
- Test: `Packages/PluginAgentLoop/Tests/PluginAgentLoopTests/StreamRecoveryCoordinatorTests.swift`
- Test: `Packages/KitLLM/Tests/KitLLMTests/VendorAPIServiceRetryTests.swift`

### Step 1：写失败测试

| Fixture | 预期 |
|---|---|
| 首个 SSE 前网络失败 | 现有 Vendor retry，可复用 attempt |
| 已有 committed prefix 后断流 | 旧 attempt interrupted，新 attempt 新 IDs，未提交 tail 丢弃 |
| 只有 live tail、没有任何 checkpoint | 新 attempt 从空 committed snapshot 恢复，不保存假 prefix |
| 旧 attempt 在恢复后继续回调 | 全部 stale discard |
| malformed tool call stream | 走现有 correction，不执行半成品调用 |
| 连续断流超过预算 | Turn failed/paused 有可操作错误，无悬挂 task/continuation |
| completed final commit 后收到传输错误 | 不重复恢复；按已完成幂等处理 |
| 供应商提供 responseID 但无 continuation 契约 | 仍使用新 attempt，不做 token resume |

### Step 2：确认失败

```bash
swift test --package-path Packages/PluginAgentLoop --filter StreamRecoveryCoordinatorTests
swift test --package-path Packages/KitLLM --filter VendorAPIServiceRetryTests
```

### Step 3：最小实现

RecoveryCoordinator 从 committer 读取 committed anchor，而不是从 UI 文本或 raw events 重建。旧 attempt interrupted save 失败时，不启动新 attempt；将恢复本身标为可重试错误，避免两个活跃 attempt。

恢复上下文包含 committed prefix 与现有一次性 recovery hint；不得把旧 attempt 的候选 toolCalls 自动加入历史。预算使用 `TurnRuntime.llmRecoveryAttempts` 或统一的新 Turn 级 stream recovery budget，不能每个 attempt 重置。

### Step 4：确认通过

```bash
swift test --package-path Packages/KitLLM
swift test --package-path Packages/PluginAgentLoop
swift test --package-path Packages/PluginMessageManager
```

### Step 5：独立提交

```bash
git add Packages/KitLLM Packages/PluginAgentLoop Packages/PluginMessageManager
git diff --cached --check
git commit -m "fix(PluginAgentLoop): recover streams from committed attempt anchors"
```

## 9. Task 6：Tool Result Durable Barrier 与未知副作用

**Files:**

- Modify: `Packages/ProviderToolManager/Sources/ProviderToolManager/ToolManagerProviding.swift`
- Modify: `Packages/ProviderToolManager/Sources/ProviderToolManager/DefaultToolManagerProviding.swift`
- Modify: `Packages/ProviderToolManager/Sources/ProviderToolManager/ToolCallRecordStore.swift`
- Modify: `Packages/ProviderToolManager/Sources/ProviderToolManager/ToolJobRecordStore.swift`
- Modify: `Packages/PluginToolManager/Sources/PluginToolManager/Managers/ToolExecutionManager.swift`
- Modify: `Packages/PluginToolManager/Sources/PluginToolManager/Managers/ToolManager+Run.swift`
- Modify: `Packages/PluginAgentLoop/Sources/PluginAgentLoop/Observers/ToolJobObserver.swift`
- Modify: `Packages/PluginAgentLoop/Sources/PluginAgentLoop/Managers/AgentLoopProvider+Tool.swift`
- Modify: `Packages/PluginAgentLoop/Sources/PluginAgentLoop/Managers/AgentLoopProvider+Message.swift`
- Test: `Packages/ProviderToolManager/Tests/ProviderToolManagerTests/DefaultToolResultDurabilityTests.swift`
- Test: `Packages/ProviderAgentLoop/Tests/ProviderAgentLoopTests/AgentLoopFullLoopTests.swift` and other existing ToolManager fakes
- Test: `Packages/PluginToolManager/Tests/PluginToolManagerTests/ToolJobDurabilityTests.swift`
- Test: `Packages/PluginAgentLoop/Tests/PluginAgentLoopTests/ToolResultDurabilityTests.swift`
- Test: `Packages/FactoryLumi/Tests/FactoryLumiTests/FactoryLumiTests.swift` only if its ToolManager doubles require the new requirement

### Step 1：写失败测试

1. ToolJob result 尚未 durable 时，AgentLoop 不写下一 LLM request。
2. ToolJob result 已 durable、tool message save 失败时，不创建下一 attempt；重启可从 Job result upsert 同一 tool message，不重跑工具。
3. tool message 已 durable、下一 attempt begin 失败时，LLM 不调用，恢复只重试 begin。
4. 工具已 started 后进程消失且没有 result：重启 Job 标 outcomeUnknown，不自动 execute。
5. read-only Job 也不盲目重放；只有工具专属幂等策略明确允许才可另议。
6. toolCallID 稳定，重复 Job completion 不插入重复 tool message。
7. 多个只读并发 Job 全部 durable 后才进入下一 LLM step；串行副作用屏障不回归。
8. DefaultToolManagerProviding 的 `execute` / `executeBatch` / `executeAuthorized` 直接路径在 record 仅进入 write-behind buffer、尚未 flush 时，同样不得创建下一 attempt。
9. 直接路径 flush 失败必须抛错并停止后续 LLM；持久结果存在但 decode 失败也按损坏错误处理，不得当成 not-found 重跑工具。
10. 通过 `any ToolManagerProviding` 调用 durable query 时，两个生产实现和测试 fake 都执行各自的持久化确认，而不是默认空实现。

### Step 2：确认失败

```bash
swift test --package-path Packages/ProviderToolManager --filter DefaultToolResultDurabilityTests
swift test --package-path Packages/PluginToolManager --filter ToolJobDurabilityTests
swift test --package-path Packages/PluginAgentLoop --filter ToolResultDurabilityTests
```

### Step 3：最小实现

在 `ToolManagerProviding` 增加统一 requirement，不提供返回 nil 的 protocol extension 默认实现；全仓搜索 `: ToolManagerProviding`、`, ToolManagerProviding` 与测试 fake，本 Task 同步迁移所有 conformer（至少包括 ProviderAgentLoop、PluginAgentLoop、FactoryLumi 测试 doubles），不能靠编译警告略过：

```swift
func durableToolResult(
    forToolCallID toolCallID: String,
    conversationID: UUID,
    turnID: UUID?
) async throws -> ToolCallResult?
```

返回值语义固定为：持久化终态结果存在则返回结果；确认尚未完成/不存在则返回 nil；flush、读取或 decode 失败则抛错。`toolCallID + conversationID + turnID` 共同限定作用域，禁止只按原始 ID 跨 Turn 取结果。

- PluginToolManager：对 `ToolJobRecordStore` 增加 throwing 的 flush-and-fetch 终端结果能力。只有已从数据库重读到 terminal Job 和完整 result 才返回；内存 Job 状态与完成事件都不是 durable 证据。
- DefaultToolManagerProviding：对 `ToolCallRecordStore` 增加 throwing 的 flush-and-fetch 能力，复用现有功能结果快照。现有 `fetchRecord` 会先 flush，但其 `try?` 不能把 save 失败与 not-found 区分开，因此 durable 路径必须新增可抛错入口，不能直接把现有 nil 当确认成功。
- AgentLoop：Job observer 路径与直接 `execute` / batch / authorized 路径都先 await 上述确认，再通过 MessageStore durable upsert tool message。确认失败时保持当前 Turn 可恢复，不创建下一 attempt，不自动再次 execute。
- MessageManager 的 inserted 事件仍只用于 UI，不作为持久化确认。

启动恢复以 ToolJob record 或直接路径功能结果 record 为执行事实：已 started 无 durable result 只能标未知/失败并生成可修复 tool result；不得根据“没有完成消息”推断工具没运行。

### Step 4：确认通过

```bash
swift test --package-path Packages/ProviderToolManager
swift test --package-path Packages/ProviderAgentLoop
swift test --package-path Packages/PluginToolManager
swift test --package-path Packages/PluginAgentLoop
swift test --package-path Packages/PluginMessageManager
swift test --package-path Packages/PluginConversationResume
swift test --package-path Packages/FactoryLumi
```

### Step 5：独立提交

```bash
git add Packages/ProviderToolManager Packages/ProviderAgentLoop Packages/PluginToolManager Packages/PluginAgentLoop Packages/PluginMessageManager Packages/PluginConversationResume Packages/FactoryLumi
git diff --cached --check
git commit -m "fix(PluginAgentLoop): persist tool results before continuing turns"
```

## 10. Task 7：Resume 按当前 Turn/Attempt 判定

**Files:**

- Modify: `Packages/PluginConversationResume/Sources/PluginConversationResume/Models/ResumeEligibility.swift`
- Modify: `Packages/PluginConversationResume/Sources/PluginConversationResume/Managers/ResumeCoordinator.swift`
- Modify: `Packages/PluginConversationResume/Sources/PluginConversationResume/Models/OrphanToolCallScanner.swift` only if anchor/Job outcome changes orphan classification
- Test: `Packages/PluginConversationResume/Tests/PluginConversationResumeTests/ResumeEligibilityTests.swift`
- Test: `Packages/PluginConversationResume/Tests/PluginConversationResumeTests/StreamAttemptResumeTests.swift`

### Step 1：写失败测试

- 历史旧 Turn 有最终 assistant，当前 Turn 没有：应 resumable，不被旧回复遮蔽。
- 当前 Turn completed anchor + final assistant：不可 Resume，即使 turn record 因崩溃未收尾。
- 当前 attempt interrupted 且只有 committed prefix：可 Resume，理由指向断流恢复。
- 当前 Turn 有 assistant tool call、ToolJob outcomeUnknown：修复文案是结果未知，不能写“未执行”。
- 当前 Turn 有 assistant tool call但 Job 从未创建：可写“执行前中断”的 placeholder。
- 活跃/挂起 Turn 不显示 Resume。
- legacy 无 turnID 消息保留现有判定作为明确 fallback，不误判新数据。

### Step 2：确认失败

```bash
swift test --package-path Packages/PluginConversationResume --filter ResumeEligibilityTests
swift test --package-path Packages/PluginConversationResume --filter StreamAttemptResumeTests
```

当前 `hasFinalAssistantReply` 扫描整个历史，旧回复测试应失败。

### Step 3：最小实现

`ResumeEligibility.Input` 增加当前 turnID 与 latest anchor；只在与 record.turnID 匹配的消息/anchor 上判断 final。legacy fallback 仅在没有新 turn 标识的数据上使用。

`resume()` 仍先修复孤儿 tool call 再开新 Turn；对 outcomeUnknown 不自动重放工具。Resume 结束后由 AgentLoop 创建新 attempt，不续写旧 assistantMessageID。

### Step 4：确认通过

```bash
swift test --package-path Packages/PluginConversationResume
swift test --package-path Packages/PluginAgentLoop
```

### Step 5：独立提交

```bash
git add Packages/PluginConversationResume Packages/PluginAgentLoop
git diff --cached --check
git commit -m "fix(PluginConversationResume): evaluate recovery within the active turn"
```

## 11. Task 8：端到端故障矩阵与验收

**Files:**

- Test: `Packages/FactoryLumi/Tests/FactoryLumiTests/StreamAttemptRecoveryIntegrationTests.swift`
- Test: `Packages/PluginAgentLoop/Tests/PluginAgentLoopTests/StreamAttemptProcessCrashTests.swift`

### Step 1：加入确定性故障点

至少覆盖：

- begin 前/后崩溃。
- checkpoint save 前、save 后通知前崩溃。
- final save 前、save 后工具提交前崩溃。
- tool result Job save 前、save 后 message 前崩溃。
- 下一 attempt begin 前崩溃。
- 旧 stream task 晚于新 attempt 完成。
- 恢复预算耗尽与取消竞争。

至少一条集成测试用 helper process 在故障点退出；其他可用 Store/clock/task fake 保证速度。测试不得依赖真实付费供应商或真实 secret。

### Step 2：确认新增集成测试先失败

```bash
swift test --package-path Packages/FactoryLumi --filter StreamAttemptRecoveryIntegrationTests
swift test --package-path Packages/PluginAgentLoop --filter StreamAttemptProcessCrashTests
```

预期：当前实现缺少至少一个故障点或恢复断言，测试 RED。若全部直接通过，逐项核对它们是否真在独立进程/真实 Store 上覆盖了 Step 1 的故障，而不是重复已有 fake 测试。

### Step 3：最小修复并运行自动测试矩阵

只修复 RED 暴露的具体状态/持久化问题，不重写已有 FSM。随后运行：

```bash
swift test --package-path Packages/KitLLM
swift test --package-path Packages/ProviderAgentLoop
swift test --package-path Packages/PluginAgentLoop
swift test --package-path Packages/ProviderMessage
swift test --package-path Packages/PluginMessageManager
swift test --package-path Packages/ProviderToolManager
swift test --package-path Packages/PluginToolManager
swift test --package-path Packages/PluginConversationResume
swift test --package-path Packages/FactoryLumi
```

再运行以下全包回归与现有 macOS 构建。在测试治理 Task 4 修复脚本退出码之前，`test ! -s` 是必须的门禁，不得只看脚本退出码：

```bash
Scripts/run-all-package-tests.sh
test ! -s .test-logs/FAILED.txt
```

### Step 4：真实 App 验证

1. 普通流式回复：同一 attempt 的 UI 消息 ID 稳定，final 后 Turn 才完成。
2. 多步工具回合：每个 LLM step 是独立 assistant attempt，工具授权/渲染/消息配对正确。
3. 测试代理在 committed checkpoint 后断流：UI 丢弃未提交 tail，显示恢复进度，新 assistant ID，旧回调不覆盖。
4. 连续断流达到预算：出现可操作失败/Resume，没有永远“正在恢复”。
5. 工具执行中断：重启不自动重跑；区分执行前中断与结果未知。
6. 大型工具结果与断流组合：Artifact preview、消息持久化和恢复均不丢配对。
7. 旧版本会话：历史最终回复不会阻止当前 Turn Resume，旧消息正常显示。

### Step 5：独立提交

```bash
git add Packages/FactoryLumi Packages/PluginAgentLoop
git diff --cached --check
git commit -m "test(PluginAgentLoop): cover stream attempt crash recovery"
```

## 12. 完成定义

- 每次 LLM step 都有 durable begin，且 assistantMessageID 在 attempt 内稳定、跨 attempt 不 reused。
- checkpoint/final 的 anchor 与 MessageModel 在同一 ModelContext 一次 save；CAS 拒绝旧 revision。
- final commit 是发布 Turn outcome 和工具执行的前置条件。
- ToolJob 与直接工具执行路径的 result 均已 durable，且 tool message durable 后才创建下一 LLM attempt。
- 断流只从 committed anchor 恢复，未提交 tail 与半成品 tool call 不进入功能历史。
- 旧 attempt 回调、旧 worker、旧 ToolJob 完成事件都不能覆盖新状态。
- 不宣称跨 Store 原子、通用 token 续流或 exactly-once；未知工具副作用不自动重放。
- Resume 只看当前 Turn/Attempt，真实 App 与进程崩溃测试有证据。
