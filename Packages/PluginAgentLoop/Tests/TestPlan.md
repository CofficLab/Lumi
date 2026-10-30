# TestPlan — PluginAgentLoop

## 包概述

PluginAgentLoop 自定义 AgentLoop 插件,替换默认的 `DefaultAgentLoopProvider`。

平台: macOS 14+, iOS 17+
测试文件: 5 个，用例总数: 39

核心组件（源码目录）:
- `Managers/`
- `Observers/`

## 公开 API

包内主要类型（按声明顺序抽取，供定位被测对象）:

- `TurnPhase`
- `ErrorRetryUITestingSupport`
- `PluginAgentLoop`
- `AgentLoopManager`
- `PluginAgentLoopObserverHandle`
- `ToolCallIdentityNormalizer`
- `MessageObserver`
- `ToolJobObserver`
- `ToolManagerObserver`

## 关键行为契约（实现约定，非协议要求）

按测试模块归纳，改动对应模块时须保持既有断言成立:

- **FailedTurnRetryVisibility**（6 条）：由 `failedTurnKeepsCurrentTurnID`、`failedTurnIsRetryable`、`staleTurnIsNotRetryable` 等用例锁定；改动该模块时优先跑对应测试文件。
- **综合**（19 条）：由 `testPluginInitialization`、`testPluginMetadata`、`testMessageFromLLMMessagePreservesToolCalls` 等用例锁定；改动该模块时优先跑对应测试文件。
- **ToolAuthorizationPersistence**（3 条）：由 `rejectionSurvivesTerminalTurnPhase`、`approvalSurvivesMismatchedTurnID`、`resolvedAuthorizationIsNeverLeftPending` 等用例锁定；改动该模块时优先跑对应测试文件。
- **ToolJobCancellation**（5 条）：由 `resumingSuspendedTurnReportsRunning`、`invalidResumeRequestKeepsSuspendedTurnObservable`、`lateLLMResponseAfterCancellationIsIgnored` 等用例锁定；改动该模块时优先跑对应测试文件。
- **ToolJobLoop**（6 条）：由 `toolJobsTransitionThroughWaitingPhase`、`cancellingWaitingToolJobsIgnoresLateCompletion`、`unknownToolJobEventIsIgnoredByReducer` 等用例锁定；改动该模块时优先跑对应测试文件。

## 测试用例清单

| ID | 类别 | 描述 | 前置条件 | 操作步骤 | 预期结果 | 优先级 | 状态 | 测试方法 |
|----|------|------|----------|----------|----------|------|------|----------|
| 1 | FailedTurnRetryVisibility | 回合失败后 currentTurnID 仍返回失败回合的 ID | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `failedTurnKeepsCurrentTurnID` |
| 2 | FailedTurnRetryVisibility | 失败回合可重试：currentTurnID 与错误消息的 turnID 一致时判定成立 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `failedTurnIsRetryable` |
| 3 | FailedTurnRetryVisibility | 过期回合不可重试：currentTurnID 已推进到新回合 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `staleTurnIsNotRetryable` |
| 4 | FailedTurnRetryVisibility | idle 会话没有当前回合，不可重试 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `idleConversationHasNoRetryableTurn` |
| 5 | FailedTurnRetryVisibility | 终态 phase 同样保留回合身份，不影响 completed 回合的读取 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `completedTurnKeepsCurrentTurnID` |
| 6 | FailedTurnRetryVisibility | 失败回合不接收新 Tool Job，终态回合身份不会让旧 Job 复活 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `terminalTurnDoesNotResurrectToolJobs` |
| 7 | 综合 | testPluginInitialization | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testPluginInitialization` |
| 8 | 综合 | testPluginMetadata | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testPluginMetadata` |
| 9 | 综合 | willSendToLLM message restoration preserves assistant tool calls | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testMessageFromLLMMessagePreservesToolCalls` |
| 10 | 综合 | provider-reused tool-call IDs are normalized across the conversation | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testToolCallIdentityNormalizerAvoidsConversationCollisions` |
| 11 | 综合 | duplicate tool-call IDs within one provider response are normalized | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testToolCallIdentityNormalizerAvoidsResponseCollisions` |
| 12 | 综合 | 可恢复的 LLM 工具协议错误会重试当前回合 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `testRetryableLLMFailureRetriesCurrentTurn` |
| 13 | 综合 | 重试入口只接受匹配的失败回合 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `testRetryTurnRequiresMatchingFailedTurn` |
| 14 | 综合 | LLM 失败结果保留原始错误供专用渲染器使用 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testLLMFailureKeepsStructuredError` |
| 15 | 综合 | LLM 成功响应会清除工具协议恢复状态 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testSuccessfulLLMResponseClearsRecoveryState` |
| 16 | 综合 | 用户图片附件会转换为 LLM 图片 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testMessageToLLMMessagePreservesUserImage` |
| 17 | 综合 | 工具结果图片关联到 tool 消息而不是 assistant | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testToolResultImageIsAttachedToToolMessage` |
| 18 | 综合 | 用户文本文件附件会转换为 LLM 用户正文 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testMessageToLLMMessagePreservesUserFile` |
| 19 | 综合 | LLM 图片恢复为消息时会保留附件 metadata | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testMessageFromLLMMessagePreservesUserImage` |
| 20 | 综合 | 挂起 ask_user 时发送新消息会跳过挂起点并恢复原回合 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testMessageObserverResumesSuspendedTurnWhenUserContinuesChatting` |
| 21 | 综合 | AgentLoop 始终把当前对话的供应商和模型传给请求 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testAgentLoopUsesConversationProviderAndModel` |
| 22 | 综合 | 流式 LLM chunk 同时保留 reasoning 和普通内容 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testAgentLoopStreamsReasoningAndContentFromSameChunk` |
| 23 | 综合 | 挂起高风险工具审批时发送新消息不会绕过审批 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testMessageObserverDoesNotSkipNonAskUserSuspension` |
| 24 | 综合 | 应用重启后授权完成事件会从历史 assistant 消息恢复 Loop | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testHistoricalAuthorizedCompletionRehydratesLoop` |
| 25 | 综合 | 正常挂起回合收到授权完成事件后会继续剩余工具 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testAuthorizedCompletionResumesSuspendedLoop` |
| 26 | ToolAuthorizationPersistence | 回合已结束时，用户拒绝的终态仍必须写回消息 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `rejectionSurvivesTerminalTurnPhase` |
| 27 | ToolAuthorizationPersistence | turnID 不一致时，用户授权的终态仍必须写回消息 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `approvalSurvivesMismatchedTurnID` |
| 28 | ToolAuthorizationPersistence | 授权终态不会因为状态机缺失而停留在等待授权形态 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `resolvedAuthorizationIsNeverLeftPending` |
| 29 | ToolJobCancellation | 恢复中的 awaitingUser 阶段对外显示为 running | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `resumingSuspendedTurnReportsRunning` |
| 30 | ToolJobCancellation | 拒绝无效恢复请求后仍发布有效的挂起状态 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `invalidResumeRequestKeepsSuspendedTurnObservable` |
| 31 | ToolJobCancellation | 取消回合后迟到的 LLM 响应不会复活回合 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `lateLLMResponseAfterCancellationIsIgnored` |
| 32 | ToolJobCancellation | 工具失败和超时都会回写错误并恢复 AgentLoop | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `terminalToolErrorsWakeAgentLoop` |
| 33 | ToolJobCancellation | 取消后的迟到 Job 终态事件不会写回结果 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `lateToolJobCompletionAfterCancellationIsIgnored` |
| 34 | ToolJobLoop | 工具 Job 创建后进入等待态，全部完成后才恢复请求 LLM | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `toolJobsTransitionThroughWaitingPhase` |
| 35 | ToolJobLoop | 取消等待中的工具 Job 后不会被迟到完成事件重新唤醒 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `cancellingWaitingToolJobsIgnoresLateCompletion` |
| 36 | ToolJobLoop | 未知工具 Job 不会修改等待中的 pending 集合 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `unknownToolJobEventIsIgnoredByReducer` |
| 37 | ToolJobLoop | 审批挂起期间其他 Job 完成时保留挂起点并消费结果 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `completedSiblingJobDuringApprovalRemovesOnlyItsPendingCall` |
| 38 | ToolJobLoop | Job 完成事件会回写 assistant 工具调用并恢复下一轮 LLM | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `completedToolJobResumesAgentLoop` |
| 39 | ToolJobLoop | 取消 Agent 回合时会先取消对应的 Tool Job | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `cancellingAgentTurnCancelsAssociatedJobs` |

> 说明：全部 **39 条场景**已在本包 `swift test` 中实跑通过。
> 用例名与描述取自 `Tests/` 下的真实 `@Test` 声明，改动测试时须同步本表。

## 覆盖率统计

- P0: 已覆盖 10 / 10
- P1: 已覆盖 29 / 29
- P2: 已覆盖 0 / 0
- **合计: 39 / 39**（仅表示清单场景，非源码覆盖率）

## 优先级说明

- **P0**: 描述/名称含崩溃、泄漏、截断、丢失、竞态、超时、必须、不得、重试等失效类信号的用例（10 条）
- **P1**: 其余功能性用例（29 条）
- **P2**: 稳定常量、占位、文案、空集合等边界用例（0 条）

## 跨平台说明

- Package 声明: macOS 14+, iOS 17+
- 39 条用例位于 `Tests/`，需在目标平台执行 `swift test`

## 测试执行

```bash
cd Packages/PluginAgentLoop
swift test
```

## 维护规则

1. **新增公开 API** → 先在 TestPlan 登记测试用例，再写实现
2. **Bug 修复** → 追加回归用例，标注触发条件
3. **删除用例** → 在 commit message 说明理由
4. **状态同步** → 实现后更新 TestPlan，标记 ✅ 并填写测试方法名
5. **改名同步** → 重命名 `@Test` 函数后必须同步本表，否则 `Scripts/verify-testplan.py` 会报「登记方法在源码不存在」
