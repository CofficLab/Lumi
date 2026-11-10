# TestPlan — ProviderMessageSender

## 包概述

ProviderMessageSender Lumi 编辑器 Provider。

平台: macOS 14+, iOS 17+
测试文件: 3 个，用例总数: 26

## 公开 API

包内主要类型（按声明顺序抽取，供定位被测对象）:

- `DefaultMessageSender`
- `DefaultMessageSenderObserverHandle`
- `MessageSenderEvent`
- `SendingStateObserverHandle`

## 关键行为契约（实现约定，非协议要求）

按测试模块归纳，改动对应模块时须保持既有断言成立:

- **综合**（9 条）：由 `commitsUserMessageBeforeStartingTurn`、`preservesQueueBeforeDeferredTurnStart`、`sendsMessageThroughLoop` 等用例锁定；改动该模块时优先跑对应测试文件。

- **DefaultMessageSender 回合中再发送的守门**（9 条）：由 `suspendedTurnQueuesNextMessage`、`externallyDrivenTurnQueuesNextMessage` 等用例锁定；改动该模块时优先跑对应测试文件。
- **ProviderMessageSender**（4 条）：由 `commitsCollapsedBlocksIntoMetadata`、`rebasesCollapsedBlocksAfterTrim` 等用例锁定；改动该模块时优先跑对应测试文件。
- **DefaultMessageSender 附件读取门禁**（3 条）：由 `attachmentReadCountTracksBeginAndEnd`、`waitResumesWhenLastReadEnds`、`waitReturnsImmediatelyWhenIdle` 锁定；改动该模块时优先跑对应测试文件。

## 测试用例清单

| ID | 类别 | 描述 | 前置条件 | 操作步骤 | 预期结果 | 优先级 | 状态 | 测试方法 |
|----|------|------|----------|----------|----------|------|------|----------|
| 1 | 综合 | 用户消息提交完成后即可读取，回合执行可随后启动 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `commitsUserMessageBeforeStartingTurn` |
| 2 | 综合 | 提交后回合尚未调度时，连续发送仍进入队列 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `preservesQueueBeforeDeferredTurnStart` |
| 3 | 综合 | 发送消息会创建会话、落用户消息并运行 Agent Loop | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `sendsMessageThroughLoop` |
| 4 | 综合 | 发送回合通过观察者发出 started 和 completed | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `sendsTurnEvents` |
| 5 | 综合 | 附件挂起池随消息送出并编码进 metadata | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `sendsAttachments` |
| 6 | 综合 | 仅附件也可以发送，且正文保持为空 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `sendsAttachmentOnlyMessage` |
| 7 | 综合 | 同一会话发送中时新消息进入 pending 队列，回合结束后依次发出 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `queuesWhileSending` |
| 8 | 综合 | resumeTurn 转发到 AgentLoop（无匹配挂起点时抛出明确错误） | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `resumesTurn` |
| 9 | 综合 | 并发带附件发送按触发顺序落库 | 第一条编码慢、第二条编码快 | 先后触发两次 `commitUserMessageInBackground` | 时间线先出现第一条，第二条进入待发队列（顺序不反转） | P0 | ✅ 已覆盖 | `concurrentAttachmentSendsKeepCallOrder` |
| 10 | DefaultMessageSender 回合中再发送的守门 | 回合挂起期间再次发送应进入待发队列 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `suspendedTurnQueuesNextMessage` |
| 11 | DefaultMessageSender 回合中再发送的守门 | 外部拉起的回合期间再次发送应进入待发队列 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `externallyDrivenTurnQueuesNextMessage` |
| 12 | DefaultMessageSender 回合中再发送的守门 | ask_user 挂起期间的新消息直接落库，不入队 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `askUserSuspensionLetsNewMessageLandImmediately` |
| 13 | DefaultMessageSender 回合中再发送的守门 | 授权挂起期间的新消息进入待发队列 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `authorizationSuspensionQueuesNewMessage` |
| 14 | DefaultMessageSender 回合中再发送的守门 | 回合到达终态后队列排空 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `terminalOutcomeDrainsQueue` |
| 15 | DefaultMessageSender 回合中再发送的守门 | 回合挂起时队列不排空 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `suspendedOutcomeDoesNotDrainQueue` |
| 16 | DefaultMessageSender 回合中再发送的守门 | resumeTurn 完成后队列排空 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `resumeTurnDrainsQueueOnTerminalOutcome` |
| 17 | DefaultMessageSender 回合中再发送的守门 | 会话空闲时发送仍然直接落库 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `idleConversationSendsImmediately` |
| 18 | ProviderMessageSender | 折叠块随用户消息落库，区间落在正文范围内 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `commitsCollapsedBlocksIntoMetadata` |
| 19 | ProviderMessageSender | 正文被 trim 后折叠块区间同步平移 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `rebasesCollapsedBlocksAfterTrim` |
| 20 | ProviderMessageSender | 不携带折叠块时 metadata 里没有折叠块 key | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `omitsCollapsedBlocksKeyWhenAbsent` |
| 21 | ProviderMessageSender | 排队中的消息在回放时保留折叠块 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `preservesCollapsedBlocksThroughQueue` |
| 22 | ProviderMessageSender | 折叠块覆盖的首尾空白被 trim 时只裁短区间，不丢弃整块 | 正文首尾带换行，块覆盖全文 | 提交用户消息 | 正文 trim 后仍保留同一个 chip 区间 | P0 | ✅ 已覆盖 | `clipsCollapsedBlockWhenTrimRemovesSurroundingWhitespace` |
| 23 | DefaultMessageSender 回合中再发送的守门 | ask_user 挂起但队列非空时，新消息排在已有消息之后 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `askUserSuspensionDoesNotBypassQueuedMessages` |
| 24 | DefaultMessageSender 附件读取门禁 | 附件读取计数随 begin / end 增减，多余的 end 不会变负 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `attachmentReadCountTracksBeginAndEnd` |
| 25 | DefaultMessageSender 附件读取门禁 | 最后一个附件读取结束时唤醒等待中的发送入口 | 一次在途读取 + 等待任务 | `endAttachmentRead()` 后等待任务恢复 | 结束前未恢复，结束后恢复 | P0 | ✅ 已覆盖 | `waitResumesWhenLastReadEnds` |
| 26 | DefaultMessageSender 附件读取门禁 | 没有在途读取时等待立即返回 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `waitReturnsImmediatelyWhenIdle` |

> 说明：全部 **26 条场景**已在本包 `swift test` 中实跑通过。
> 用例名与描述取自 `Tests/` 下的真实 `@Test` 声明，改动测试时须同步本表。

## 覆盖率统计

- P0: 已覆盖 3 / 3
- P1: 已覆盖 23 / 23
- P2: 已覆盖 0 / 0
- **合计: 26 / 26**（仅表示清单场景，非源码覆盖率）

## 优先级说明

- **P0**: 描述/名称含崩溃、泄漏、截断、丢失、竞态、超时、必须、不得、重试等失效类信号的用例（2 条）
- **P1**: 其余功能性用例（22 条）
- **P2**: 稳定常量、占位、文案、空集合等边界用例（0 条）

## 跨平台说明

- Package 声明: macOS 14+, iOS 17+
- 24 条用例位于 `Tests/`，需在目标平台执行 `swift test`

## 测试执行

```bash
cd Packages/ProviderMessageSender
swift test
```

## 维护规则

1. **新增公开 API** → 先在 TestPlan 登记测试用例，再写实现
2. **Bug 修复** → 追加回归用例，标注触发条件
3. **删除用例** → 在 commit message 说明理由
4. **状态同步** → 实现后更新 TestPlan，标记 ✅ 并填写测试方法名
5. **改名同步** → 重命名 `@Test` 函数后必须同步本表，否则 `Scripts/verify-testplan.py` 会报「登记方法在源码不存在」
