# TestPlan — PluginConversationState

## 包概述

PluginConversationState 的实现包，包含 5 个主要类型；当前测试覆盖 33 条用例。

平台: macOS 14+, iOS 17+
测试文件: 5 个，用例总数: 33

核心组件（源码目录）:
- `Observers/`
- `Providers/`

## 公开 API

包内主要类型（按声明顺序抽取，供定位被测对象）:

- `ConversationStatePlugin`
- `AgentLoopStateObserver`
- `MessageSenderStateObserver`
- `ToolManagerStateObserver`
- `ConversationStateProvider`

## 关键行为契约（实现约定，非协议要求）

按测试模块归纳，改动对应模块时须保持既有断言成立:

- **综合**（12 条）：由 `pluginMetadataIsStable`、`providerPublishesStateEvents`、`partialUpdatePreservesUnchangedFields`、`deletedConversationRemovesStateSnapshot` 等用例锁定；改动该模块时优先跑对应测试文件。
- **授权解决后 activity 残留**（5 条）：由 `activityClearedAfterAuthorizationResolved`、`activityClearedAfterAuthorizationRejected`、`activityClearedWithoutAnyToolJobEvent` 等用例锁定——授权完成后 activity 必须从 waitingForUser 清掉，不能只靠 ToolJobEvent 驱动，取消后迟到的事件也不得把它改回来。
- **activity 的终态不变量**（5 条）：由 `terminalAgentLoopStateClearsActivity`、`lateEventCannotResurrectActivityOnTerminalTurn`、`nonTerminalTurnsStillAcceptActivity` 等用例锁定——终态回合的 activity 恒为空，idle 只承载 sending，快照替换路径同样受约束。
- **pre-turn 活动状态**（4 条）：由 `secondTurnSendingActivitySurvivesPreviousTerminalState`、`messageSenderStartedWritesSendingActivity` 等用例锁定——发送前窗口的 `.sending` 不受上一轮终态影响（#891），回合期 activity 仍不得回流到已死掉的回合。
- **Chat 模式拦截后 activity 残留**（2 条）：由 `blockedBatchClearsExecutingToolActivity`、`pendingApprovalKeepsWaitingForUser` 锁定——整批拦截（无 ToolJob）后 `.batchCompleted` 必须清掉 `.executingTool`，但批次因待授权暂停时要保留 `.waitingForUser`。
- **执行期授权状态**（3 条）：由 `authorizationSuspensionMarksAuthorizationRequired`、`askUserSuspensionKeepsAuthorizationNone`、`resumedTurnClearsAuthorizationRequired` 锁定——执行期授权挂起（Computer Use）必须标记 `authorizationState == .required`，`ask_user` 挂起不得误标，用户做出决定后必须回落。

## 测试用例清单

| ID | 类别 | 描述 | 前置条件 | 操作步骤 | 预期结果 | 优先级 | 状态 | 测试方法 |
|----|------|------|----------|----------|----------|------|------|----------|
| 1 | 综合 | pluginMetadataIsStable | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `pluginMetadataIsStable` |
| 2 | 综合 | providerPublishesStateEvents | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `providerPublishesStateEvents` |
| 3 | 综合 | partialUpdatePreservesUnchangedFields | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `partialUpdatePreservesUnchangedFields` |
| 4 | 综合 | canStopCoversRunningAndSuspendedButNotTerminalStates | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `canStopCoversRunningAndSuspendedButNotTerminalStates` |
| 5 | 综合 | clearFlagsResetActivityAndErrorWithoutTouchingOtherFields | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `clearFlagsResetActivityAndErrorWithoutTouchingOtherFields` |
| 6 | 综合 | stateForUnknownConversationReturnsIdleDefault | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `stateForUnknownConversationReturnsIdleDefault` |
| 7 | 综合 | removeUnknownConversationDoesNotNotify | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `removeUnknownConversationDoesNotNotify` |
| 8 | 综合 | observerStopsReceivingAfterCancel | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `observerStopsReceivingAfterCancel` |
| 9 | 综合 | jobActivityMergesIntoSnapshot | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `jobActivityMergesIntoSnapshot` |
| 10 | 综合 | 恢复后的迟到 suspended 事件不会覆盖运行中状态 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `lateSuspendedEventDoesNotOverwriteResumedTurnState` |
| 11 | 授权解决后 activity 残留 | 授权完成后 activity 不得停留在 waitingForUser | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `activityClearedAfterAuthorizationResolved` |
| 12 | 授权解决后 activity 残留 | 授权被拒后 activity 不得停留在 waitingForUser | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `activityClearedAfterAuthorizationRejected` |
| 13 | 授权解决后 activity 残留 | 授权请求不产生 ToolJobEvent 时仍必须能清掉 activity | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `activityClearedWithoutAnyToolJobEvent` |
| 14 | 授权解决后 activity 残留 | 授权请求时回合已挂起，activity 才得以写入 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `authorizationRequestLandsOnSuspendedTurn` |
| 15 | 授权解决后 activity 残留 | 回合取消后迟到的 Job 事件不得把 activity 改回 waitingForUser | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `lateJobEventDoesNotRestoreWaitingForUserAfterCancellation` |
| 16 | activity 的终态不变量 | 回合进入终态后 activity 必须为空 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `terminalAgentLoopStateClearsActivity` |
| 17 | activity 的终态不变量 | 终态回合不得被迟到的事件重新标记为正在做事 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `lateEventCannotResurrectActivityOnTerminalTurn` |
| 18 | activity 的终态不变量 | 非终态回合的 activity 必须正常写入 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `nonTerminalTurnsStillAcceptActivity` |
| 19 | activity 的终态不变量 | idle 回合只承载正在发送 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `idleTurnOnlyAcceptsSendingActivity` |
| 20 | activity 的终态不变量 | 快照替换路径同样守住终态不变量 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `snapshotReplacementAlsoRespectsInvariant` |
| 21 | Chat 模式拦截后 activity 残留 | 被拦截批次完成后 activity 不得停留在 executingTool（**#992**） | 回合运行中 + `.executingTool` | 发送仅含 `.blocked` 结果的 `.batchCompleted` | activity 变为 nil | P0 | ✅ 已覆盖 | `blockedBatchClearsExecutingToolActivity` |
| 22 | Chat 模式拦截后 activity 残留 | 批次因待授权暂停时不得清掉 waitingForUser（**#992 护栏**） | 回合挂起 + `.waitingForUser` | 发送含 `.needsUserResponse` 的 `.batchCompleted` | activity 仍为 `.waitingForUser` | P0 | ✅ 已覆盖 | `pendingApprovalKeepsWaitingForUser` |
| 23 | 授权等待期间的 Job 事件 | 后台 Job 的进度与完成不得覆盖等待提示（**回归 #962**） | 审批调用挂起，同一回合另有自动放行 Job 运行并完成 | 依次发 `.started` 与 `.completed` Job 事件 | activity 始终为 `.waitingForUser`，jobActivity 仍记录该 Job | P0 | ✅ 已覆盖 | `backgroundJobKeepsWaitingForUserWhileAuthorizationPending` |
| 24 | 授权等待期间的 Job 事件 | 授权解决后 Job 终态仍可正常清理 activity（**#962 护栏**） | 先发 `.authorizedCompleted` | 再发运行中与完成的 Job 事件 | activity 最终为 nil，不会卡在等待 | P1 | ✅ 已覆盖 | `jobCompletionClearsActivityAfterAuthorizationResolved` |
| 25 | 执行期授权状态 | 执行期授权挂起必须把会话授权状态标记为 required（**#961**） | 回合收到 Computer Use 授权挂起 | 发送带 `kind: computer_use_authorization` 的 `.suspended` | `authorizationState == .required` | P0 | ✅ 已覆盖 | `authorizationSuspensionMarksAuthorizationRequired` |
| 26 | 执行期授权状态 | ask_user 挂起不得被误标为授权等待 | 回合已 `.started` | 发送无 `kind` 字段的 `.suspended` | `authorizationState == .none` | P1 | ✅ 已覆盖 | `askUserSuspensionKeepsAuthorizationNone` |
| 27 | 执行期授权状态 | 用户做出决定后会话授权状态必须回落 | 执行期授权挂起后已标记 required | 恢复回合并发送 `.toolCallsReceived` | `authorizationState == .none` | P0 | ✅ 已覆盖 | `resumedTurnClearsAuthorizationRequired` |
| 28 | 综合 | 删除会话会清理状态快照（**#1031**） | 会话已有 turn/activity/job/error 快照 | 通过 `ConversationManaging` 删除该会话 | 快照回落为 idle 默认值，jobActivity 清空 | P0 | ✅ 已覆盖 | `deletedConversationRemovesStateSnapshot` |
| 29 | 综合 | 非删除事件不会清理状态快照 | 会话已有运行中快照 | 触发标题更新与活跃标记事件 | 快照保持 `running` | P1 | ✅ 已覆盖 | `nonDeletionEventsKeepStateSnapshot` |
| 30 | pre-turn 活动状态 | 第二轮的发送前活动不得被上一轮终态吞掉（**#891**） | 第一轮已进入 `.completed` / `.failed` / `.cancelled` | 写入 `activity = .sending` | activity 仍为 `.sending` | P0 | ✅ 已覆盖 | `secondTurnSendingActivitySurvivesPreviousTerminalState` |
| 31 | pre-turn 活动状态 | MessageSender 事件到达后必须写入发送中活动（**#891**） | 第一轮已进入终态 | 发出 `MessageSenderEvent.started` | activity 为 `.sending` | P0 | ✅ 已覆盖 | `messageSenderStartedWritesSendingActivity` |
| 32 | pre-turn 活动状态 | 终态回合仍不得承载回合期活动（**#891 护栏**） | 回合已进入终态 | 写入 thinking / executingTool / waitingForUser | activity 恒为 nil | P0 | ✅ 已覆盖 | `terminalTurnStillRejectsTurnScopedActivity` |
| 33 | pre-turn 活动状态 | 发送前窗口不得把回合状态改写成 idle（**#891 护栏**） | 第一轮已进入终态 | 写入 `activity = .sending` | agentLoopState 保持终态，activity 为 `.sending` | P0 | ✅ 已覆盖 | `sendingActivityDoesNotResetAgentLoopState` |

> 说明：全部 **33 条场景**已在本包 `swift test` 中实跑通过。
> 用例名与描述取自 `Tests/` 下的真实 `@Test` 声明，改动测试时须同步本表。

## 覆盖率统计

- P0: 已覆盖 17 / 17
- P1: 已覆盖 14 / 14
- P2: 已覆盖 2 / 2
- **合计: 33 / 33**（仅表示清单场景，非源码覆盖率）

## 优先级说明

- **P0**: 描述/名称含崩溃、泄漏、截断、丢失、竞态、超时、必须、不得、重试等失效类信号的用例（17 条）
- **P1**: 其余功能性用例（14 条）
- **P2**: 稳定常量、占位、文案、空集合等边界用例（2 条）

## 跨平台说明

- Package 声明: macOS 14+, iOS 17+
- 33 条用例位于 `Tests/`，需在目标平台执行 `swift test`

## 测试执行

```bash
cd Packages/PluginConversationState
swift test
```

## 维护规则

1. **新增公开 API** → 先在 TestPlan 登记测试用例，再写实现
2. **Bug 修复** → 追加回归用例，标注触发条件
3. **删除用例** → 在 commit message 说明理由
4. **状态同步** → 实现后更新 TestPlan，标记 ✅ 并填写测试方法名
5. **改名同步** → 重命名 `@Test` 函数后必须同步本表，否则 `Scripts/verify-testplan.py` 会报「登记方法在源码不存在」
