# Durable Conversation Input and Idempotent Promotion Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** 把用户发送从“内存 pending queue + 随机新消息 ID”改为持久 command 账本，保证同一 command 的重试共享一个预分配 userMessageID，并在同一 SwiftData 事务中完成用户消息 promotion。

**Architecture:** `ConversationInputModel` 与 `MessageModel` 加入同一个 MessageStore Schema；MessageSender 是输入状态机唯一所有者，MessageStore 是唯一事务执行者，AgentLoop 只执行已 dispatch 的 Turn。空闲和 busy 输入都先写入 queued，再由同一 drain worker promotion，避免两套写路径。

**Tech Stack:** Swift 6、SwiftData、CryptoKit、Swift Testing、ProviderMessageSender、PluginMessageSender、PluginMessageManager、ProviderAgentLoop、PluginAgentLoop、PluginConversationInput。

---

## 1. 当前问题

`Packages/PluginMessageSender/Sources/PluginMessageSender/Providers/MessageSender.swift` 与 `Packages/ProviderMessageSender/Sources/ProviderMessageSender/DefaultMessageSender.swift` 当前都：

- busy 时只把 `PendingChatMessage` 放进内存 `pendingQueues`。
- drain 时移除内存项，再创建新的随机用户消息 ID。
- queued commit 返回 `userMessageID=nil`。
- 依靠消息插入观察与 Sender 自身跟踪共同启动/等待 Turn。

这意味着进程退出会丢 queued 输入，重试不能可靠去重，durable accept 与 UI 清草稿之间缺少明确边界。

`Packages/PluginMessageManager/Sources/PluginMessageManager/Managers/MessageManager.swift` 的 inserted 只代表进入 write-behind buffer；不能用 inserted 事件冒充账本提交成功。

### 非目标

- 不承诺 LLM 请求或工具副作用 exactly-once。
- 不把 Conversation SQLite、Resume JSON、ToolJob Store 与消息 SwiftData 说成同一事务。
- 不自动重放 `dispatching` / `running` 状态下进程崩溃的输入。
- 不为 queued 输入另建独立 SQLite/JSON 数据库；那无法与 MessageModel 同事务 promotion。
- 不替换 AgentTurnFSM，不让 MessageObserver 与 Sender 双重 dispatch。
- 不在本计划实现 `now/next/later` steering；后续专项复用此账本。

## 2. 公共契约

### 2.1 Command 与 Acceptance

新建 `Packages/ProviderMessageSender/Sources/ProviderMessageSender/ConversationInputCommand.swift`：

```swift
public struct ConversationInputCommand: Codable, Sendable, Equatable {
    public let commandID: UUID
    public let conversationID: UUID
    public let userMessageID: UUID
    public let turnID: UUID
    public let createdAt: Date
    public let content: String
    public let metadata: [String: String]

    public var payloadHash: String { get }
}

public enum ConversationInputState: String, Codable, Sendable {
    case queued
    case promoting
    case promoted
    case dispatching
    case running
    case completed
    case failed
    case cancelled
}

public struct ConversationInputAcceptance: Sendable, Equatable {
    public let commandID: UUID
    public let conversationID: UUID
    public let userMessageID: UUID
    public let turnID: UUID
    public let state: ConversationInputState
    public let revision: Int64
    public let queueSequence: Int64
    public let lastErrorCode: String?

    public var wasQueued: Bool { state == .queued || state == .promoting }
}
```

规则：

1. `commandID` 在用户点击发送时生成；同一次点击的编码失败、保存失败、网络错误重试都复用它。
2. 内容、目标会话、附件 metadata 或 collapsed blocks 任一变化，必须生成新的 commandID。
3. `userMessageID` 与 `turnID` 在首次 accept 前预分配，queued 时也不能为 nil。
4. `payloadHash` 使用 canonical JSON（sorted keys、明确 Date 编码）的 SHA-256；至少覆盖 commandID、conversationID、userMessageID、turnID、createdAt、content、metadata。
5. 同一 commandID 不同 hash 返回 `commandConflict`，绝不能覆盖旧 payload。

附件在 accept 前通过现有编码器写入 metadata。编码期间草稿不清理；崩溃发生在 durable accept 前时，UI 仍持有原始快照，不要求账本保存尚未 accept 的草稿。

### 2.2 Sender API

在 `MessageSendingProviding` 新增 requirement：

```swift
func prepareConversationInput(
    content: String,
    imageAttachments: [UserImageAttachment],
    fileAttachments: [UserFileAttachment],
    collapsedBlocks: [CollapsedContentBlock],
    conversationID: UUID?,
    commandID: UUID
) async throws -> ConversationInputCommand

func submitConversationInput(
    _ command: ConversationInputCommand
) async throws -> ConversationInputAcceptance

func conversationInputState(
    commandID: UUID
) async -> ConversationInputAcceptance?
```

`prepare` 负责：固定目标会话、trim/校准 collapsed blocks、按现有顺序编码附件、分配 userMessageID/turnID、写入 origin metadata。`submit` 只负责 durable accept 和触发统一 drain，不等待整个 Agent Turn 完成。

旧 `MessageSendCommit` 与同步 commit API 只在迁移期间保留。全部调用点迁移后删除旧内存队列写路径；最终不能同时存在“新账本”和“旧 pendingQueues”两个事实源。

### 2.3 Store 能力

新建 `ConversationInputManaging`（ProviderMessageSender 或更合适的 ProviderMessage 层，选择以不形成依赖环为准）：

```swift
public protocol ConversationInputManaging: AnyObject {
    func acceptConversationInput(
        _ command: ConversationInputCommand
    ) async throws -> ConversationInputAcceptance

    func promoteNextConversationInput(
        conversationID: UUID,
        workerID: UUID
    ) async throws -> ConversationInputPromotion?

    func transitionConversationInput(
        commandID: UUID,
        expected: Set<ConversationInputState>,
        expectedRevision: Int64,
        to: ConversationInputState,
        workerID: UUID?,
        errorCode: String?
    ) async throws -> ConversationInputAcceptance

    func conversationInputAcceptances(
        conversationID: UUID
    ) async -> [ConversationInputAcceptance]
}
```

如果 protocol 需要引用 MessageStore 私有 promotion 类型，把 `ConversationInputPromotion` 也放 Provider 层，包含 command、预分配 Message 和是否由本次调用提交。Provider 不 import PluginMessageManager。

## 3. 持久模型与状态机

新建 `Packages/PluginMessageManager/Sources/PluginMessageManager/Models/ConversationInputModel.swift`，至少字段：

```text
commandID: String，unique
conversationID: String，indexed
userMessageID: String，unique
turnID: String，indexed
createdAt: Date
queueSequence: Int64
payloadJSON: Data
payloadHash: String
state: String
revision: Int64
workerID: String?
leaseUpdatedAt: Date?
dispatchAttemptCount: Int
lastErrorCode: String?
updatedAt: Date
```

`MessageStore.makeContainer` 的 Schema 必须同时包含 `MessageModel.self` 与 `ConversationInputModel.self`，使用同一个 `ModelConfiguration` 和 `messages.sqlite`。后续 StreamAttemptAnchor 也加入这里，不能再建第二个消息库。

### 状态转换

```text
queued ──acquire lease──> promoting ──commit message+ledger──> promoted
  │                         │                                  │
  │                         └─save失败/过期 lease→ queued       ├─CAS→ dispatching ──startTurn已调用→ running
  │                                                             │                    │
  └─CAS cancel→ cancelled                                       │                    ├→ completed
                                                                │                    ├→ failed
                                                                │                    └→ cancelled
                                                                └─启动恢复且尚未 dispatch→ dispatching

dispatching/running 在进程消失后 = outcomeUnknown，不自动再次 dispatch
```

实现可将 `outcomeUnknown` 表示为 `failed` + 稳定 `lastErrorCode="dispatch_outcome_unknown"`，不必增加 UI 枚举；但恢复逻辑必须区分它与“尚未调用 AgentLoop”。

### CAS 与终态规则

- `revision` 每次转换递增；调用方必须把上一次 `ConversationInputAcceptance.revision` 原样传给 `expectedRevision`。Store 只有在 expected state、`expectedRevision`、`workerID` 同时匹配时才更新，成功返回递增后的新 revision。
- `workerID` 是本次 CAS 要求匹配的当前 lease owner，不是可任意写入的新 owner。queued cancel 传 nil；promoting/promoted/dispatching/running 的 worker 操作传当前 worker。lease 获取/接管只由 `promoteNextConversationInput` 完成，终态或 lease release 由 Store 清 worker。
- CAS 失败抛出带当前 acceptance 的 `inputRevisionConflict`（或等价 typed error），不得返回“成功”或覆盖新状态；调用方重新读取后再决定是共享已提交结果、结束等待还是放弃旧回调。
- queued cancel 与 promotion 竞争只能有一个胜者。
- `promoted` 之后不能用“取消 pending”删除用户消息；要停止后续执行只能走 AgentLoop cancel。
- 同一 command 在 completed/failed/cancelled 再 submit，只返回当前终态及其 revision，不自动重试。
- 旧 worker 的完成回调必须携带它上次看到的 revision；不得把后续 retry/new state 回退。

## 4. Task 1：Command canonicalization 与新协议类型

**Files:**

- Create: `Packages/ProviderMessageSender/Sources/ProviderMessageSender/ConversationInputCommand.swift`
- Create: `Packages/ProviderMessageSender/Sources/ProviderMessageSender/ConversationInputManaging.swift`
- Modify: `Packages/ProviderMessageSender/Sources/ProviderMessageSender/MessageSendingProviding.swift`
- Modify: `Packages/ProviderMessageSender/Package.swift` only if CryptoKit or a Provider dependency requires manifest changes
- Test: `Packages/ProviderMessageSender/Tests/ProviderMessageSenderTests/ConversationInputCommandTests.swift`
- Test: `Packages/ProviderMessageSender/Tests/ProviderMessageSenderTests/MessageSendingProvidingTests.swift`

### Step 1：写失败测试

1. 相同 command 两次编码 hash 相同；metadata 插入顺序不影响 hash。
2. content、conversationID、metadata、IDs 任一变化 hash 不同。
3. queued acceptance 的 userMessageID/turnID 非空。
4. 新 protocol 方法通过 `any MessageSendingProviding` 调用具体实现，而不是静态默认实现。
5. command round-trip 保留 collapsed blocks/附件 metadata 原文。

### Step 2：确认失败

```bash
swift test --package-path Packages/ProviderMessageSender --filter ConversationInputCommandTests
swift test --package-path Packages/ProviderMessageSender --filter MessageSendingProvidingTests
```

### Step 3：最小实现

实现纯值类型、canonical encoder 和 protocol requirements。默认实现只允许用于迁移期转发；不能用一个每次生成新 UUID 的默认实现破坏幂等。

### Step 4：确认通过

```bash
swift test --package-path Packages/ProviderMessageSender
swift test --package-path Packages/PluginMessageSender
```

此时 Plugin 可暂时编译失败作为迁移信号，但本 Task 提交前必须保持全包可编译。迁移期默认实现只能复用旧编码逻辑完成 `prepare`，不得用旧内存发送路径伪造 durable `submit` acceptance；未迁移的 `submit` 必须抛 `durableInputUnavailable`，Factory 也暂不切换到新 API。两个生产 Sender 完成持久实现前，旧发送入口保持原行为；后续 Task 删除旧路径。

### Step 5：独立提交

```bash
git add Packages/ProviderMessageSender Packages/PluginMessageSender
git diff --cached --check
git commit -m "feat(ProviderMessageSender): define durable conversation input commands"
```

## 5. Task 2：同库 Ledger 与 durable accept

**Files:**

- Create: `Packages/PluginMessageManager/Sources/PluginMessageManager/Models/ConversationInputModel.swift`
- Create: `Packages/PluginMessageManager/Sources/PluginMessageManager/Service/MessageStore+ConversationInput.swift`
- Modify: `Packages/PluginMessageManager/Sources/PluginMessageManager/Service/MessageStore.swift`
- Modify: `Packages/PluginMessageManager/Sources/PluginMessageManager/Managers/MessageManager.swift`
- Modify: `Packages/ProviderMessage/Sources/ProviderMessage/DefaultMessageManager.swift` only if it also conforms to the new capability
- Test: `Packages/PluginMessageManager/Tests/PluginMessageManagerTests/ConversationInputStoreTests.swift`
- Test: `Packages/PluginMessageManager/Tests/PluginMessageManagerTests/MessageStoreMigrationTests.swift`

### Step 1：写失败测试

- accept 返回前真实 `context.save()` 已成功；注入 save 失败时抛错，不能仅发布 inserted。
- 同一 command 顺序/并发 accept 100 次只有一条 ledger，返回相同 IDs。
- 同 commandID 不同 payloadHash 返回 conflict，原 payload 不变。
- queued 记录包含完整附件/collapsed metadata，重启新 Store 可读取。
- 旧版本只有 MessageModel 的 database fixture 能轻量迁移，历史消息不变。
- accept 不直接调用 AgentLoop、不插入用户消息；空闲输入也先 queued。

测试 save failure 应通过 Store 内部 seam/注入 context factory，不依赖真的磁盘满。若当前 MessageStore 不利于注入，最小 refactor 为 internal initializer，生产 public initializer 不变。

### Step 2：确认失败

```bash
swift test --package-path Packages/PluginMessageManager --filter ConversationInputStoreTests
swift test --package-path Packages/PluginMessageManager --filter MessageStoreMigrationTests
```

### Step 3：最小实现

- Schema 加入 ConversationInputModel。
- accept 在 Store lock 内使用独立 ModelContext，按 commandID fetch；不存在则 insert queued 并 save；存在则校验 hash 并返回当前状态。
- `queueSequence` 由 Store 在同一串行边界分配，保证 accept 顺序稳定。
- 成功 save 后才由 MessageManager 发布账本投影变化；这里不发送 MessageChange.inserted，因为用户消息尚未 promotion。
- DefaultMessageManager 若是无持久测试实现，可使用明确 in-memory ledger，但生产 Factory 必须注入持久实现。

### Step 4：确认通过

```bash
swift test --package-path Packages/PluginMessageManager
swift test --package-path Packages/ProviderMessage
swift test --package-path Packages/ProviderMessageSender
```

### Step 5：独立提交

```bash
git add Packages/PluginMessageManager Packages/ProviderMessage Packages/ProviderMessageSender
git diff --cached --check
git commit -m "feat(PluginMessageManager): persist conversation input commands"
```

## 6. Task 3：原子 Promotion 与稳定用户消息

**Files:**

- Modify: `Packages/PluginMessageManager/Sources/PluginMessageManager/Service/MessageStore+ConversationInput.swift`
- Modify: `Packages/PluginMessageManager/Sources/PluginMessageManager/Models/MessageModel.swift` only if origin metadata/index mapping requires it
- Modify: `Packages/PluginMessageManager/Sources/PluginMessageManager/Managers/MessageManager.swift`
- Test: `Packages/PluginMessageManager/Tests/PluginMessageManagerTests/ConversationInputPromotionTests.swift`
- Test: `Packages/PluginMessageManager/Tests/PluginMessageManagerTests/ConversationInputCrashRecoveryTests.swift`

### Step 1：写失败测试

覆盖以下顺序：

1. queued 获取 promoting lease，保存 lease；模拟崩溃，无 MessageModel。
2. 新 worker 接管过期 promoting，使用原 userMessageID。
3. 同一 promotion transaction 内 fetch-or-insert MessageModel、ledger 置 promoted、revision+1，只调用一次 save。
4. save 前失败：消息与 promoted 状态都不可见，可重试。
5. save 后、返回值前模拟崩溃：重放按 userMessageID 找到原消息，不插入第二条。
6. 两个 worker 同时 promote 同一 command：一个成功，另一个读取已提交结果。
7. 同会话多条 command 按 queueSequence FIFO；不同会话不互相阻塞。
8. queued cancel 与 promotion 并发：最终要么 cancelled 且无消息，要么 promoted 且取消返回当前状态。
9. worker A 以旧 expectedRevision 完成/释放 lease 时，worker B 已接管并推进 revision：A 收到 `inputRevisionConflict`，B 的 state、revision、workerID 与 payload 均不变。
10. 每次 accept/transition 返回的 acceptance 都带当前 revision、queueSequence、lastErrorCode；UI 清空内存投影后可按 queueSequence 重建顺序。

### Step 2：确认失败

```bash
swift test --package-path Packages/PluginMessageManager --filter ConversationInputPromotionTests
swift test --package-path Packages/PluginMessageManager --filter ConversationInputCrashRecoveryTests
```

### Step 3：最小实现

严格按以下 transaction 顺序实现 `promoteNext`：

1. Store lock 内创建/使用本次 ModelContext，读取下一条 queued 或合法接管 promoting。
2. 校验 payloadHash、queueSequence、revision 和 worker lease。
3. 按预分配 userMessageID fetch-or-insert MessageModel；映射 command 原始 content/metadata/createdAt，绝不生成新 ID。
4. ledger 置 promoted，清 worker，revision+1。
5. 只调用一次 `context.save()`。
6. save 成功后返回不可变 promotion 值；MessageManager 才更新内存时间线并发送 `.inserted` / `.persisted` 对应事件。

Lease 获取自身可以先单独 save；上述“只 save 一次”特指用户消息与 promoted 状态的事务，不得把它误写成整个生命周期只有一次 save。

### Step 4：确认通过

```bash
swift test --package-path Packages/PluginMessageManager
swift test --package-path Packages/ProviderMessage
```

### Step 5：独立提交

```bash
git add Packages/PluginMessageManager Packages/ProviderMessage
git diff --cached --check
git commit -m "fix(PluginMessageManager): atomically promote durable conversation inputs"
```

## 7. Task 4：共享 Sender Drain 与 AgentLoop 单点 Dispatch

**Files:**

- Create: `Packages/ProviderMessageSender/Sources/ProviderMessageSender/MessageSenderCoordinator.swift`
- Create: `Packages/ProviderMessageSender/Sources/ProviderMessageSender/ConversationInputProjection.swift`
- Modify: `Packages/PluginMessageSender/Sources/PluginMessageSender/Providers/MessageSender.swift`
- Modify: `Packages/PluginAgentLoop/Sources/PluginAgentLoop/Observers/MessageObserver.swift`
- Modify: `Packages/ProviderAgentLoop/Sources/ProviderAgentLoop/AgentLoopProviding.swift`
- Modify: `Packages/PluginAgentLoop/Sources/PluginAgentLoop/Managers/AgentLoopProvider+Turn.swift`
- Test: `Packages/ProviderMessageSender/Tests/ProviderMessageSenderTests/MessageSenderCoordinatorTests.swift`
- Test: `Packages/PluginMessageSender/Tests/PluginMessageSenderTests/DurableMessageSenderTests.swift`
- Test: `Packages/PluginAgentLoop/Tests/PluginAgentLoopTests/MessageObserverTests.swift`

### Step 1：写失败测试

- 空闲 submit 也经过 queued → promoting → promoted → dispatching → running。
- busy 时多条输入按 FIFO 逐条 promotion，前一条 Turn 终态后才 dispatch 下一条。
- MessageObserver 看到带 conversation-input origin 的用户消息时不调用 runTurn；Sender 调用一次稳定 turnID 的 startTurn。
- 非 command 来源（ACP/测试/旧恢复路径）插入用户消息仍走原 Observer 行为。
- 同一 command 重复 submit 不增加 dispatchAttempt，不创建第二个 Turn。
- 旧 Turn 的迟到完成事件只结束匹配 turnID 的 ledger，不误推进新 command。
- pending UI projection 可从 ledger 重建，内存缓存被清空也不丢顺序。

### Step 2：确认失败

```bash
swift test --package-path Packages/ProviderMessageSender --filter MessageSenderCoordinatorTests
swift test --package-path Packages/PluginMessageSender --filter DurableMessageSenderTests
swift test --package-path Packages/PluginAgentLoop --filter MessageObserverTests
```

### Step 3：最小实现

`MessageSenderCoordinator` 统一拥有 draining set、当前 Turn 跟踪、continuation 与 ledger projection。Plugin MessageSender 保留附件挂起池和公开外观，但发送/排队/取消 pending 委托 coordinator。

新增 `AgentTurnStartRequest`（conversationID、turnID、userMessageID、commandID）和 `startTurn(_ request:)`；旧 `startTurn(for:)` 可转发并生成新 turnID 供非 command 来源使用。

dispatch 顺序必须是：

1. promoted durable commit 已完成。
2. MessageManager 更新投影并发布消息事件。
3. MessageObserver 对 command-origin 消息去重。
4. Sender CAS promoted → dispatching 并持久化；只有此状态成功才调用 AgentLoop。
5. AgentLoop 接受 startTurn 后 Sender 标 running；后续用 turnID 映射终态。

`dispatching` 状态保存成功与 AgentLoop 调用之间不是事务，启动恢复必须按 outcome unknown 处理，不能自动再次 startTurn。

### Step 4：确认通过

```bash
swift test --package-path Packages/ProviderAgentLoop
swift test --package-path Packages/PluginAgentLoop
swift test --package-path Packages/ProviderMessageSender
swift test --package-path Packages/PluginMessageSender
swift test --package-path Packages/PluginMessageManager
```

### Step 5：独立提交

```bash
git add Packages/ProviderAgentLoop Packages/PluginAgentLoop Packages/ProviderMessageSender Packages/PluginMessageSender Packages/PluginMessageManager
git diff --cached --check
git commit -m "fix(PluginMessageSender): dispatch durable inputs from one owner"
```

## 8. Task 5：DefaultMessageSender 迁移与旧内存队列删除

**Files:**

- Modify: `Packages/ProviderMessageSender/Sources/ProviderMessageSender/DefaultMessageSender.swift`
- Modify: `Packages/PluginMessageSender/Sources/PluginMessageSender/Providers/MessageSender.swift`
- Modify: `Packages/ProviderMessageSender/Sources/ProviderMessageSender/MessageSendingProviding.swift`
- Modify: all remaining callers found by searching `commitUserMessage`, `pendingQueues`, `MessageSendCommit`
- Test: `Packages/ProviderMessageSender/Tests/ProviderMessageSenderTests/DefaultMessageSenderDurableTests.swift`
- Test: `Packages/PluginMessageSender/Tests/PluginMessageSenderTests/MessageSenderRegressionTests.swift`

### Step 1：写失败/等价测试

对 Plugin 与 Default 两个实现运行同一组 contract tests：

- 纯文本、附件、collapsed blocks、自动创建会话、显式指定会话。
- 连续后台附件编码不会反转点击顺序；保留 Default 现有 `backgroundCommitTail` 等价串行保证，并移入共享 coordinator。
- queued acceptance 始终有稳定 userMessageID/turnID。
- pending cancel 只作用 queued；promoted 消息不会被 deleteMessage。
- cancelCurrentRequest、resumeTurn、sendMessage 等待 outcome 的现有行为不变。
- 全仓不再存在可写的 `pendingQueues` 作为事实源；`PendingChatMessage` 只能是由 ledger 生成的投影。

### Step 2：确认迁移前测试失败

```bash
swift test --package-path Packages/ProviderMessageSender --filter DefaultMessageSenderDurableTests
swift test --package-path Packages/PluginMessageSender --filter MessageSenderRegressionTests
```

### Step 3：最小实现

两个 Sender 都使用同一个 `MessageSenderCoordinator`。迁移所有调用点后删除旧同步 commit 的内存写入实现和随机重建 pending 消息逻辑，不保留“失败时回退旧内存队列”的兼容分支。

如果第三方/test fake 需要更新，直接实现新协议；不要用静默丢 metadata 或每次生成新 commandID 的 shim。

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
git commit -m "refactor(ProviderMessageSender): replace memory queues with durable projections"
```

只暂存实际修改文件；额外调用点按 `git diff --name-only` 精确添加。

## 9. Task 6：启动恢复、取消与未知 Dispatch

**Files:**

- Create: `Packages/ProviderMessageSender/Sources/ProviderMessageSender/ConversationInputRecovery.swift`
- Modify: `Packages/ProviderMessageSender/Sources/ProviderMessageSender/MessageSenderCoordinator.swift`
- Modify: `Packages/PluginMessageSender/Sources/PluginMessageSender/Providers/MessageSender.swift`
- Modify: `Packages/PluginConversationResume/Sources/PluginConversationResume/Managers/ResumeCoordinator.swift` only to consume outcomeUnknown metadata
- Test: `Packages/ProviderMessageSender/Tests/ProviderMessageSenderTests/ConversationInputRecoveryTests.swift`
- Test: `Packages/PluginConversationResume/Tests/PluginConversationResumeTests/ConversationInputRecoveryTests.swift`

### Step 1：写失败测试

| 启动时状态 | 预期恢复 |
|---|---|
| queued | 重新进入统一 drain |
| promoting 无消息且 lease 过期 | 回 queued 后 promotion |
| promoting 已有预分配消息 | fetch-or-insert 完成同一 commit，不重复 |
| promoted | 尚未 CAS dispatching，因此可安全继续 dispatch |
| dispatching | 标 dispatch_outcome_unknown，等待用户明确处理，不自动 startTurn |
| running 且 Resume 记录仍 running | 交给现有崩溃 Resume 判定，不新增第二个 Turn |
| completed/failed/cancelled | 保持终态，重复 submit 只返回状态 |

另测 queued cancel 重启后仍 cancelled；`outcomeUnknown` 的 UI 文案明确“可能已发送给模型，重试前请确认”。

### Step 2：确认失败

```bash
swift test --package-path Packages/ProviderMessageSender --filter ConversationInputRecoveryTests
swift test --package-path Packages/PluginConversationResume --filter ConversationInputRecoveryTests
```

### Step 3：最小实现

恢复扫描在 Sender 启动且观察者装配完成后执行。每会话只启动一个 recovery/drain task。对 dispatching 不猜测 LLM 是否收到请求；提供显式用户重试入口时，创建新的恢复动作并记录 `retryOfCommandID`，不要把原 terminal command 直接重置为 queued。

Resume JSON/Caches 仍只是派生状态，账本才是 queued/promoted 输入的唯一事实。

### Step 4：确认通过

```bash
swift test --package-path Packages/ProviderMessageSender
swift test --package-path Packages/PluginMessageSender
swift test --package-path Packages/PluginConversationResume
```

### Step 5：独立提交

```bash
git add Packages/ProviderMessageSender Packages/PluginMessageSender Packages/PluginConversationResume
git diff --cached --check
git commit -m "fix(ProviderMessageSender): recover durable inputs without replaying dispatch"
```

## 10. Task 7：UI 草稿与附件快照

**Files:**

- Modify: `Packages/PluginConversationInput/Sources/PluginConversationInput/ViewModels/ConversationInputViewModel.swift`
- Modify: `Packages/PluginConversationInput/Sources/PluginConversationInput/ViewModels/SendActionBarViewModel.swift`
- Modify: relevant view only where send/cancel pending callbacks changed
- Test: `Packages/PluginConversationInput/Tests/PluginConversationInputTests/ConversationInputDurableSendTests.swift`
- Test: `Packages/PluginConversationInput/Tests/PluginConversationInputTests/SendActionBarViewModelTests.swift`

### Step 1：写失败测试

- 点击发送时生成 commandID 和完整 draft snapshot；异步编码期间正文继续显示或进入明确 sending 状态，不清空。
- durable accept 成功后才清正文和对应附件；失败恢复完全相同的正文、附件、collapsed ranges 与 commandID。
- 用户在编码期间编辑文本产生新 revision；旧 accept 成功不能清新草稿。
- 用户改目标会话/附件后点击重试必须生成新 commandID；同快照失败重试复用旧 ID。
- queued 项重启后仍显示；取消只取消 ledger queued 项。
- 快速双击发送同一 UI action 只生成一个逻辑 command（按钮去重），但用户明确再次发送相同内容是新 command。

### Step 2：确认失败

```bash
swift test --package-path Packages/PluginConversationInput --filter ConversationInputDurableSendTests
swift test --package-path Packages/PluginConversationInput --filter SendActionBarViewModelTests
```

### Step 3：最小实现

UI 持有 `draftRevision` 与 in-flight snapshot。prepare/submit 失败不丢 snapshot；成功清草稿前比较 revision。附件池只移除 snapshot 中实际发送的项，不能清掉发送期间新加入的附件。

不在 View 中直接读写 ledger 或生成数据库实体；所有操作通过 MessageSendingProviding。

### Step 4：确认通过

```bash
swift test --package-path Packages/PluginConversationInput
swift test --package-path Packages/PluginMessageSender
swift test --package-path Packages/ProviderMessageSender
```

### Step 5：独立提交

```bash
git add Packages/PluginConversationInput Packages/PluginMessageSender Packages/ProviderMessageSender
git diff --cached --check
git commit -m "fix(PluginConversationInput): clear drafts only after durable acceptance"
```

## 11. Task 8：Factory 装配、迁移与端到端验收

**Files:**

- Modify: `Packages/FactoryLumi/Sources/FactoryLumi` existing MessageManager/MessageSender composition only
- Test: `Packages/FactoryLumi/Tests/FactoryLumiTests/DurableConversationInputAssemblyTests.swift`
- Test: `Packages/FactoryLumi/Tests/FactoryLumiTests/FreshInstallFirstMessageAssemblyTests.swift`

### Step 1：写失败装配测试

验证生产 MessageSender 与 MessageManager 使用同一个持久 ConversationInput 能力；不存在 Default fallback 覆盖真实 Plugin；首次消息、附件消息、busy queue、重启恢复均走真实 Store。

### Step 2：确认失败并最小实现

```bash
swift test --package-path Packages/FactoryLumi --filter DurableConversationInputAssemblyTests
swift test --package-path Packages/FactoryLumi --filter FreshInstallFirstMessageAssemblyTests
```

只修改 composition root，不让 Sender 自行 new MessageStore，避免两个 ModelContainer/数据库路径。

### Step 3：运行相关测试矩阵

```bash
swift test --package-path Packages/ProviderMessage
swift test --package-path Packages/PluginMessageManager
swift test --package-path Packages/ProviderAgentLoop
swift test --package-path Packages/PluginAgentLoop
swift test --package-path Packages/ProviderMessageSender
swift test --package-path Packages/PluginMessageSender
swift test --package-path Packages/PluginConversationInput
swift test --package-path Packages/PluginConversationResume
swift test --package-path Packages/FactoryLumi
```

### Step 4：真实 App 验证

1. 新安装发送首条纯文本与带附件消息，durable accept 后 UI 清空，消息只出现一次。
2. busy 时连续发送三条，顺序与点击一致；强制退出后重开，queued 仍在并按 FIFO 继续。
3. 在 promotion 前后分别用测试故障注入退出，重开后 userMessageID 不变且无重复。
4. queued 取消与正在 promotion 的项各一次，状态不反转。
5. dispatching 故障注入后重开，UI 显示结果未知，不自动发第二次 LLM 请求。
6. 同会话与不同会话并发发送，身份不串线，项目路径和选模型路由使用 command 所属会话。
7. 旧版本消息库升级后所有历史消息、附件、Resume 与渲染正常。

### Step 5：独立提交

```bash
git add Packages/FactoryLumi
git diff --cached --check
git commit -m "test(FactoryLumi): verify durable conversation input assembly"
```

## 12. 完成定义与禁止的伪实现

完成必须证明：

- queued 输入可重启恢复，且 accept 成功代表真实 durable save。
- commandID 去重、payload conflict、稳定 userMessageID/turnID、FIFO 与 CAS 都有测试。
- MessageModel + ConversationInputModel 的 promotion 在同一 ModelContext 一次 save 中提交。
- Sender 独占 command dispatch，MessageObserver 不双启动。
- 两个 Sender 实现共享 coordinator，旧内存 pendingQueues 不再是事实源。
- dispatching/running 崩溃不自动重放，UI 能解释结果未知。
- 旧消息与功能数据不受影响，UI 草稿只在 durable accept 后清理。

禁止用以下方式“完成”：

- 把 ledger 放到另一个数据库文件，再用顺序调用宣称原子。
- accept 只写内存数组或等 inserted 事件就返回成功。
- catch 错误后回退旧随机 ID 内存队列。
- 重启时对所有非 terminal command 无脑 startTurn。
- 用“exactly-once Agent Turn/LLM/Tool”描述本方案。
