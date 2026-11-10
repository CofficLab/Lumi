# TestPlan — PluginMessageSender

## 包概述

PluginMessageSender 是编辑器里「发送 / 停止」这条链路的实现包。它不持有任何 UI，
只负责把用户的一次发送动作，翻译成「用户消息落库 + AgentLoop 回合跟踪 + 停止」，
并把结果通过 Provider 契约广播出去。UI 层（输入框、发送按钮、停止按钮）通过订阅
`MessageSenderEvent` 与 `isSending` 观察者决定按钮形态，因此本包是发送/停止行为的
唯一事实来源。

核心组件:
- `MessageSenderPlugin` - 装配插件（`onBoot` 解析依赖并注册 provider，`onShutdown` 拆除监听）
- `MessageSender` - `MessageSendingProviding` 的默认实现（提交、入队、回合跟踪、停止）
- `AgentLoopObserver` - 把 AgentLoop 生命周期事件转发给 `MessageSender`
- `MessageSenderObserverHandleImpl` - 事件订阅令牌（cancel 后不再回调）

## 公开 API

### MessageSenderPlugin
- `id` / `order`(= 9) / `metadata`（`policy: .required`，随宿主必装）
- `onBoot(kernel:)` - 解析 `ConversationManaging` / `MessageManaging` / `AgentLoopProviding`，
  任一缺失则记日志并 return（**不注册、也不抛错**）
- `onShutdown(kernel:)` - 取消 AgentLoop 监听

### MessageSender（`MessageSendingProviding`）
- 状态：`isSending`、`pendingImageAttachments`、`pendingFileAttachments`、`pendingQueues`
- 附件读取门禁：`pendingAttachmentReadCount`、`beginAttachmentRead()`、
  `endAttachmentRead()`、`waitForAttachmentReads()`
- 订阅：`addMessageSenderObserver(_:)`、`addSendingStateObserver(_:)`
- 提交：`commitUserMessage(_:conversationID:)`、
  `commitUserMessage(_:imageAttachments:fileAttachments:conversationID:)`、
  `commitUserMessageInBackground(...)`
- 发送：`sendMessage(_:conversationID:)`、`startTurn(for:)`
- 停止：`cancelCurrentRequest()`
- 恢复：`resumeTurn(in:request:)`
- 队列：`pendingMessages(for:)`、`cancelPendingMessage(id:in:)`
- 内部入口：`handleAgentLoopEvent(_:)`（由 `AgentLoopObserver` 调用）

### 关键行为契约（实现约定，非协议要求）
- **空内容短路**：`trimmed` 为空且无附件时 `commitUserMessage` 返回 nil，不写库
- **同会话串行**：发送中再次发送 → 进 `pendingQueues`，当前回合结束后由
  `drainPendingQueue` 依次发出；**用户消息立即入库**（不等待回合）
- **提交与回合分离**：`commit` 阶段同步完成，`startTurn` 才建立回合跟踪任务
- **迟到事件防护**：`suspended` 事件需同时校验 state / turnID / suspensionID 才生效
- **停止语义**：`cancelCurrentRequest()` 取消跟踪任务 + `agentLoop.cancelTurn` +
  广播 `.cancelled`，仅当无任何活动任务时才复位 `isSending = false`
- **读取门禁**：`beginAttachmentRead()` / `endAttachmentRead()` 维护在途计数，
  `waitForAttachmentReads()` 只在最后一个读取结束时唤醒，多余的 `end` 不变负（回归 #1023）

- **装配**（1 条）：由 `pluginRegistersMessageSendingProvider` 等用例锁定；改动该模块时优先跑对应测试文件。
- **降级**（1 条）：由 `pluginNoOpsWithoutDependencies` 等用例锁定；改动该模块时优先跑对应测试文件。
- **链路**（1 条）：由 `registeredSenderSendsMessage` 等用例锁定；改动该模块时优先跑对应测试文件。
- **回归**（1 条）：由 `senderIgnoresStaleSuspensionEvent` 等用例锁定；改动该模块时优先跑对应测试文件。
- **提交**（2 条）：由 `blankContentIsIgnored`（参数化 4 例）`、`attachmentOnlySubmissionIsAccepted` 等用例锁定；改动该模块时优先跑对应测试文件。
- **队列**（2 条）：由 `consecutiveSendsAreQueuedAndDrained`、`drainingQueueStartsFollowUpTurn`、`cancellingPendingMessageRemovesSingleEntry`、`cancellingLastPendingEntryRemovesQueue` 等用例锁定；改动该模块时优先跑对应测试文件。
- **附件**（1 条）：由 `attachmentPoolMutationsBroadcastChanges`、`fileAttachmentPoolMutationsBroadcastChanges`、`sendingClearsSentAttachments`、`attachmentsAddedDuringSendSurvive` 等用例锁定；改动该模块时优先跑对应测试文件。
- **停止**（2 条）：由 `cancelCurrentRequestCancelsActiveTurn`、`cancelClearsPendingTurnStarts`、`cancelWithoutActiveTurnIsNoOp` 等用例锁定；改动该模块时优先跑对应测试文件。
- **观察**（2 条）：由 `sendingStateObserverFiresOnlyOnRealChanges`、`sendingStateObserverStopsAfterCancel`、`messageSenderObserverStopsAfterCancel` 等用例锁定；改动该模块时优先跑对应测试文件。
- **恢复**（1 条）：由 `resumeTurnSuccessBranches`（参数化 3 例）、`resumeTurnFailureBranch` 等用例锁定；改动该模块时优先跑对应测试文件。
- **会话**（1 条）：由 `nilConversationFallsBackToSelection`、`nilConversationCreatesAndSelectsNewConversation`、`explicitConversationWins` 等用例锁定；改动该模块时优先跑对应测试文件。
- **并发**（1 条）：由 `concurrentConversationsKeepGlobalSendingFlag` 等用例锁定；改动该模块时优先跑对应测试文件。
- **插件**（1 条）：由 `shutdownRemovesAgentLoopObserver`、`repeatedShutdownIsSafe` 等用例锁定；改动该模块时优先跑对应测试文件。
- **MessageSender 回合中再发送的守门**（10 条）：由 `suspendedTurnQueuesNextMessage`、`suspendedTurnClearsSenderBusyFlag` 等用例锁定；改动该模块时优先跑对应测试文件。
- **MessageSender 停止与附件**（5 条）：由 `cancelStopsTurnUnknownToSender`、`cancelStopsSuspendedTurn`、`cancelDuringTurnStartupWindowDoesNotReportError` 等用例锁定；改动该模块时优先跑对应测试文件。

## 测试用例清单

| ID | 类别 | 描述 | 前置条件 | 操作步骤 | 预期结果 | 优先级 | 状态 | 测试方法 |
|----|------|------|----------|----------|----------|------|------|----------|
| 1 | 装配 | `onBoot` 解析三项 Provider 并注册自带 `MessageSender` | 注册 Conversation / Message / AgentLoop 替身 | 走 `kernel.start(plugins:)` 真实装配路径 | provider 可解析、类型为 `MessageSender`、归属本插件（可被卸载撤回） | P0 | ✅ 已覆盖 | `pluginRegistersMessageSendingProvider` |
| 2 | 降级 | 缺依赖时 `onBoot` 不抛错且不注册（no-op） | 空内核 | 调 `plugin.onBoot(kernel:)` | 不抛错，`MessageSendingProviding` 解析为 nil | P0 | ✅ 已覆盖 | `pluginNoOpsWithoutDependencies` |
| 3 | 链路 | 注册后 `sendMessage` 走完整链路：用户消息 → 回合 → 回复 | 完整依赖 + 消息插入即触发回合的 AgentLoop 替身 | `sendMessage("hello", conversationID: nil)` | 消息序列为 `["hello", "response"]`，结束后 `isSending == false` | P0 | ✅ 已覆盖 | `registeredSenderSendsMessage` |
| 4 | 回归 | 回合已恢复时忽略迟到的旧 `suspended` 事件 | AgentLoop 替身处于 `.running` 且带 activeTurnID/suspension | 投递同 suspensionID 的 `.suspended` | 不产生 `turnCompleted`（迟到事件不结束发送任务、不启动队列下一条） | P0 | ✅ 已覆盖 | `senderIgnoresStaleSuspensionEvent` |
| 5 | 提交 | 空内容 / 纯空白内容短路，不写库、不建回合 | 直接构造 `MessageSender` | 对 `""` / 空格 / 换行 / 制表符求提交 | 均返回 nil，消息列表不变，`isSending == false`，未触发回合 | P0 | ✅ 已覆盖 | `blankContentIsIgnored`（参数化 4 例） |
| 6 | 提交 | 有附件时即使正文为空也允许提交 | 构造带图片 + 文件附件的 sender | 提交空正文 + 两个附件 | 返回非 nil commit，`wasQueued == false`，metadata 中附件可完整解码回来 | P1 | ✅ 已覆盖 | `attachmentOnlySubmissionIsAccepted` |
| 7 | 队列 | 同会话发送中再次发送 → 入队，回合结束后自动发出 | 已有活动回合的 sender | 连续提交两条 → 投递 `.completed` → 等待回合结束 | 第二条 `wasQueued`（`userMessageID == nil`）且队列可见；回合结束后两条按序落库、队列归空、`isSending` 仍为 true（新一轮已开启）；`.started` 各广播一次 | P0 | ✅ 已覆盖 | `consecutiveSendsAreQueuedAndDrained`、`drainingQueueStartsFollowUpTurn` |
| 8 | 队列 | `cancelPendingMessage` 移除指定条目并广播变化 | 队列中有 2 条 | 移除其中 1 条；再移除最后 1 条；重复移除 | 队列按剩余条目收敛；每次移除广播一次；队列已空时不再广播 | P1 | ✅ 已覆盖 | `cancellingPendingMessageRemovesSingleEntry`、`cancellingLastPendingEntryRemovesQueue` |
| 9 | 附件 | 附件挂起池的增 / 删 / 清空，并在发送后清空已送出的附件 | 构造 sender | 添加图片+文件 → 发送 → 检查池与消息 metadata | 发送后池被清空；metadata 含附件编码；`attachmentsChanged` 仅在实际变化时触发；发送期间用户新增的附件不被误清 | P1 | ✅ 已覆盖 | `attachmentPoolMutationsBroadcastChanges`、`fileAttachmentPoolMutationsBroadcastChanges`、`sendingClearsSentAttachments`、`attachmentsAddedDuringSendSurvive` |
| 10 | 停止 | `cancelCurrentRequest` 取消活动回合并广播 `.cancelled` | 存在活动回合且该会话为选中会话 | 调 `cancelCurrentRequest` | `agentLoop.cancelTurn` 被调用、`turnCompleted(.cancelled)` 广播、`isSending == false`；未开始回合跟踪的 `pendingTurnStarts` 同样被清 | P0 | ✅ 已覆盖 | `cancelCurrentRequestCancelsActiveTurn`、`cancelClearsPendingTurnStarts` |
| 11 | 停止 | 无活动回合时点击停止是安全 no-op | 无 selectedConversation / 无活动任务 | 调 `cancelCurrentRequest` 三次 | 不崩溃，不误调 `cancelTurn`，`isSending` 观察者零回调 | P1 | ✅ 已覆盖 | `cancelWithoutActiveTurnIsNoOp` |
| 12 | 观察 | `isSending` 观察者仅在状态真实变化时触发，cancel 后停止 | 独立 sender | 订阅 → 提交 → 开启回合 → 结束 | 提交阶段零回调；状态变化各回调一次；cancel 后不再回调，重复 cancel 安全 | P1 | ✅ 已覆盖 | `sendingStateObserverFiresOnlyOnRealChanges`、`sendingStateObserverStopsAfterCancel` |
| 13 | 观察 | `addMessageSenderObserver` 的 token cancel 后不再收到事件 | 独立 sender | 订阅两个 token → 全部 cancel → 触发事件 | cancel 后无回调；重复 cancel 安全 | P2 | ✅ 已覆盖 | `messageSenderObserverStopsAfterCancel` |
| 14 | 恢复 | `resumeTurn` 成功/失败分别广播 `turnCompleted` / `turnFailed` 并复位 `isSending` | AgentLoop 替身可配置结果或抛错 | 调 `resumeTurn` 覆盖 completed / suspended / cancelled 与失败 | 事件序列为 `.started` + `.turnCompleted`；失败时为 `.started` + `.turnFailed` 并抛出原错误；`isSending` 最终为 false | P1 | ✅ 已覆盖 | `resumeTurnSuccessBranches`（参数化 3 例）、`resumeTurnFailureBranch` |
| 15 | 会话 | 未指定会话时落到选中会话；无选中则新建并自动选中；显式指定优先 | 空会话管理器 | 分别提交 `nil` 与显式 ID | 消息写入正确会话；新建会话自动成为 selected；显式指定不被选中态覆盖 | P1 | ✅ 已覆盖 | `nilConversationFallsBackToSelection`、`nilConversationCreatesAndSelectsNewConversation`、`explicitConversationWins` |
| 16 | 并发 | 两个会话并发发送，任一结束不得提前复位全局 `isSending` | 两个会话各有一个活动回合 | 先结束其中一个，再结束另一个 | 第一个结束后 `isSending` 仍为 true；两者都结束后才复位 | P1 | ✅ 已覆盖 | `concurrentConversationsKeepGlobalSendingFlag` |
| 17 | 插件 | `onShutdown` 拆除 AgentLoop 监听，不再有事件转发 | 已 boot 的插件 | shutdown 后投递 AgentLoop 事件 | AgentLoop 观察者数量归零，sender 不再收到回调；重复 shutdown 安全 | P2 | ✅ 已覆盖 | `shutdownRemovesAgentLoopObserver`、`repeatedShutdownIsSafe` |
| 18 | MessageSender 回合中再发送的守门 | 回合挂起期间再次发送应进入待发队列 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `suspendedTurnQueuesNextMessage` |
| 19 | MessageSender 回合中再发送的守门 | 回合挂起后发送器不再认为会话在发送 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `suspendedTurnClearsSenderBusyFlag` |
| 20 | MessageSender 回合中再发送的守门 | 外部拉起的回合期间再次发送应进入待发队列 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `externallyDrivenTurnQueuesNextMessage` |
| 21 | MessageSender 回合中再发送的守门 | ask_user 挂起期间的新消息直接落库，不入队 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `askUserSuspensionLetsNewMessageLandImmediately` |
| 22 | MessageSender 回合中再发送的守门 | 授权挂起期间的新消息进入待发队列 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `authorizationSuspensionQueuesNewMessage` |
| 23 | MessageSender 回合中再发送的守门 | 回合到达终态后队列排空 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `terminalOutcomeDrainsQueue` |
| 24 | MessageSender 回合中再发送的守门 | 回合挂起时队列不排空 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `suspendedOutcomeDoesNotDrainQueue` |
| 25 | MessageSender 回合中再发送的守门 | resumeTurn 完成后队列排空 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `resumeTurnDrainsQueueOnTerminalOutcome` |
| 26 | MessageSender 回合中再发送的守门 | 会话空闲时发送仍然直接落库 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `idleConversationSendsImmediately` |
| 27 | MessageSender 停止与附件 | AgentLoop 在跑但 sender 没有账本时仍然取消回合 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `cancelStopsTurnUnknownToSender` |
| 28 | MessageSender 停止与附件 | 挂起等待用户时也能取消回合 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `cancelStopsSuspendedTurn` |
| 29 | MessageSender 停止与附件 | sender 与 AgentLoop 都认为没有活回合时仍然不取消 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `cancelWithoutAnyActiveTurnIsNoOp` |
| 30 | MessageSender 回合中再发送的守门 | ask_user 挂起但队列非空时，新消息排在已有消息之后 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `askUserSuspensionDoesNotBypassQueuedMessages` |
| 31 | MessageSender 附件读取门禁 | 附件读取计数随 begin / end 增减，多余的 end 不会变负 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `attachmentReadCountTracksBeginAndEnd` |
| 32 | MessageSender 附件读取门禁 | 最后一个附件读取结束时唤醒等待中的发送入口 | 一次在途读取 + 等待任务 | `endAttachmentRead()` 后等待任务恢复 | 结束前未恢复，结束后恢复 | P0 | ✅ 已覆盖 | `waitResumesWhenLastReadEnds` |
| 33 | MessageSender 停止与附件 | 启动窗口内取消回合跟踪任务不产生错误消息 | 直接调用 `beginTurn` 停在「Task 已创建未执行」窗口 | 取消该 Task 并等待结束 | 无 `turnFailed` 广播、消息列表无 `.error` 消息、`isSending == false` | P0 | ✅ 已覆盖 | `cancelDuringTurnStartupWindowDoesNotReportError` |
| 34 | MessageSender 停止与附件 | 启动窗口内停止广播 cancelled 且不产生错误消息 | 同上，走公开入口 `cancelCurrentRequest` | 取消后等待任务结束 | 转交 `agentLoop.cancelTurn`、广播 `turnCompleted(.cancelled)`、无错误消息、仅保留用户消息 | P0 | ✅ 已覆盖 | `cancelCurrentRequestDuringStartupWindowDoesNotReportError` |

> 说明：ID 1–4 为原有套件。ID 5–17 由 `MessageSenderCommitTests`、
> `MessageSenderCancellationTests`、`MessageSenderObservationTests` 三个新套件补齐，
> 本表 34 行覆盖 45 个测试方法（参数化用例已展开说明），已在 macOS 上实跑通过。
>
> 实现中两条易错约定已在用例里显式锁定：
> - **提交与回合分离**：`commitUserMessage` 只写库并登记 `pendingTurnStarts`，
>   `isSending` 直到 `startTurn` 进入 `beginTurn` 才置 true。因此队列用例需先
>   `waitUntil { sender.isSending }` 再投递 AgentLoop 事件，否则事件会早于
>   回合跟踪任务建立而被存入 `completedOutcomes`。
> - **`isSending` 的回合级作用域**：该标志由 `currentTasks` / `pendingTurnStarts`
>   是否为空共同决定，故跨会话并发时单个会话结束不会提前复位（ID 16）。

## 覆盖率统计

- P0: 已覆盖 10 / 10
- P1: 已覆盖 22 / 22
- P2: 已覆盖 2 / 2
- **合计: 34 / 34**（仅表示清单场景，非源码覆盖率）

## 优先级说明

- **P0**: 插件装配与降级、完整发送链路、空内容短路、同会话串行队列、停止取消语义
- **P1**: 附件池、观察者回调、resume 分支、会话解析、跨会话并发
- **P2**: 订阅令牌 cancel、插件 shutdown 的资源释放

## 跨平台说明

- 纯 Foundation / KernelCore 逻辑，macOS 14+ 与 iOS 17+ 行为一致
- 本包无 SwiftUI 视图，测试不依赖渲染或窗口
- 所有被测类型为 `@MainActor`，测试套件同样标注 `@MainActor` 并在主线程执行

## 测试执行

```bash
cd Packages/PluginMessageSender
swift test
```

## 维护规则

1. **新增公开 API** → 先在 TestPlan 登记测试用例，再写实现
2. **Bug 修复** → 追加回归用例，标注触发条件（ID 4 即迟到 suspended 事件的回归）
3. **删除用例** → 在 commit message 说明理由
4. **状态同步** → 实现后更新 TestPlan，标记 ✅ 并填写测试方法名
