# TestPlan — PluginAgentLoop

## 包概述

PluginAgentLoop 自定义 AgentLoop 插件,替换默认的 `DefaultAgentLoopProvider`。

平台: macOS 14+, iOS 17+
测试文件: 13 个，用例总数: 116

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
- **AgentLoop 消息辅助**（12 条）：由 `insertsToolResultMessage`、`appendsRenderedError`、`findsIncompleteToolCall` 等用例锁定；改动该模块时优先跑 `AgentLoopMessageAndLifecycleTests.swift`。
- **消息与 LLM 消息互转的边界分支**（9 条）：由 `llmMessageCarriesToolErrorFlag`、`llmMessagesSkipsToolCallsWithoutResult`、`llmMessageCarriesRedactedThinking` 等用例锁定；改动历史消息与 LLM 消息互转时优先跑 `ToolCallIdentityAndHelpersEdgeCaseTests.swift`。
- **工具参数裁剪进入模型上下文**（3 条）：由 `llmMessagesScrubsOmittedArguments`、`llmMessagesKeepsUndeclaredArguments`、`contextOmittedArgumentKeysCollectsDeclarations` 锁定；改动历史转 LLM 消息的转换时优先跑 `ToolCallIdentityAndHelpersEdgeCaseTests.swift`。
- **PluginAgentLoop 生命周期**（6 条）：由 `onBootRegistersAgentLoopProvider`、`onBootReplacesExistingProvider`、`pluginMetadata` 等用例锁定；改动该模块时优先跑 `AgentLoopMessageAndLifecycleTests.swift`。
- **AgentLoop 工具观察者**（3 条）：由 `toolJobObserverCancels`、`toolManagerObserverHandlesForeignAgentLoop`、`toolManagerObserverSubscribesAndCancels` 锁定；改动该模块时优先跑 `AgentLoopMessageAndLifecycleTests.swift`。
- **LLM 错误分类与工具 schema 估算**（16 条）：由 `toolCallValidationErrorIsRecoverable`、`contextLimitPhrasesAreDetected`、`estimateSumsNameDescriptionParametersAndOverhead` 等用例锁定；改动该模块时优先跑 `LLMErrorClassificationTests.swift`。
- **挂起回落必须区分授权与交互**（3 条）：由 `askUserSuspensionKeepsNonAuthorizationState`、`permissionSuspensionStillResetsToPending`、`suspensionKindIsDecidedByPayload` 锁定；改动该模块时优先跑 `SuspendedInteractionStateTests.swift`。
- **工具挂起时的授权状态回落**（4 条）：由 `suspensionResetsAuthorizationStateToPending`、`needsUserResponseBranchResetsAuthorizationState`、`completedToolCallKeepsItsAuthorizationState` 等用例锁定；改动该模块时优先跑 `SuspendedToolAuthorizationStateTests.swift`。
- **挂起回合的取消**（5 条）：由 `cancellingSuspendedTurnClearsSuspension`、`cancellingSuspendedTurnDeliversCancelledEvent`、`cancellingDuringResumeDoesNotReviveTurn` 等用例锁定；改动该模块时优先跑 `SuspendedTurnCancellationTests.swift`。
- **同一批次多个挂起点的恢复**（4 条）：由 `resumingOneSuspensionKeepsRemainingActive`、`allSuspensionsMustBeAnsweredBeforeNextLLMRequest`、`singleSuspensionStillContinuesAfterResume`、`resumePublishesRunningEvent` 锁定；恢复一个挂起后必须停在剩余挂起点，全部回答完才允许请求 LLM（**回归 #1026**）；恢复后没有剩余调用时必须重新发布运行事件（**回归 #944**）。
- **Tool 调用身份归一化的边界分支**（7 条）：由 `idsCollectsToolCallIDsFromBothRoles`、`normalizeDetectsCollisionAfterTrim`、`normalizeReturnsResponseUnchangedWithoutToolCalls` 等用例锁定；改动该模块时优先跑 `ToolCallIdentityAndHelpersEdgeCaseTests.swift`。
- **压缩历史下的工具调用身份归一化**（2 条）：由 `compressedTurnToolCallIDIsStillNormalized`、`otherTurnToolCallIDIsNotReserved` 锁定；去重集合必须包含同回合已落库但被上下文压缩掉的 ID（**回归 #1024**）。
- **消息与 LLM 消息互转的边界分支**（7 条）：由 `llmMessagesSkipsToolCallsWithoutResult`、`messageFromLLMMessageFallsBackToSystemForUnknownRole`、`llmMessageDropsInvalidBase64ImageAttachments` 等用例锁定；改动该模块时优先跑 `ToolCallIdentityAndHelpersEdgeCaseTests.swift`。
- **AgentLoop 注入预算**（2 条）：由 `budgetSubtractsPreparedHistory`、`budgetNeverGoesNegative` 锁定；Hook 注入内容的预算必须扣除已准备的历史，且不得为负。
- **AgentLoop 上下文校准**（1 条）：由 `calibrationUsesCacheTotalInput` 锁定；校准必须优先使用 `cacheTotalInputTokenCount`，缺失时才回退 `inputTokenCount`。

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
| 40 | AgentLoop 消息辅助 | 无渲染信息时 error 消息只写默认描述，renderKind/rawErrorDetail 保持为空 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `appendsErrorWithoutRenderInfo` |
| 41 | AgentLoop 消息辅助 | `appendError(content:)` 写入 error 角色消息并携带 turnID | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `appendsPlainError` |
| 42 | AgentLoop 消息辅助 | `appendError(error:)` 透传 renderKind、rawErrorDetail 与思考内容 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `appendsRenderedError` |
| 43 | AgentLoop 消息辅助 | 找到仍缺少结果的工具调用所在 assistant 消息 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `findsIncompleteToolCall` |
| 44 | AgentLoop 消息辅助 | 工具调用已内联结果时不算未完成 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `ignoresResolvedToolCall` |
| 45 | AgentLoop 消息辅助 | 同一回合内已由 tool 消息回填的调用不算未完成 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `ignoresToolFilledCall` |
| 46 | AgentLoop 消息辅助 | 写入 tool 消息并带上结果、错误标记、toolCallID 与 turnID | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `insertsToolResultMessage` |
| 47 | AgentLoop 消息辅助 | 取最近一条带工具调用的 assistant 消息 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `latestAssistantToolCalls` |
| 48 | AgentLoop 消息辅助 | 没有任何工具调用时返回 nil | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `latestAssistantToolCallsWithoutAny` |
| 49 | AgentLoop 消息辅助 | `notifyLLMResponse` 发布 toolCallsReceived 事件并携带全部字段 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `notifiesToolCallsReceived` |
| 50 | AgentLoop 消息辅助 | 消息里没有工具调用时未完成检测返回 nil | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `returnsNilWithoutToolCalls` |
| 51 | AgentLoop 消息辅助 | tool 消息属于其他回合时不视为已回填 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `treatsOtherTurnAsUnfilled` |
| 52 | PluginAgentLoop 生命周期 | 依赖齐备时 onBoot 注册自定义 AgentLoopProviding | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `onBootRegistersAgentLoopProvider` |
| 53 | PluginAgentLoop 生命周期 | onBoot 替换内核中已有的默认 AgentLoopProviding | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `onBootReplacesExistingProvider` |
| 54 | PluginAgentLoop 生命周期 | 缺少必需 Provider 时 onBoot 直接返回且不注册 AgentLoopProviding | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `onBootWithoutProvidersDoesNothing` |
| 55 | PluginAgentLoop 生命周期 | onReady 缺少 Provider 时不抛错 | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `onReadyWithoutProvidersDoesNothing` |
| 56 | PluginAgentLoop 生命周期 | onShutdown 释放观察者且不抛错 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `onShutdownIsSafe` |
| 57 | PluginAgentLoop 生命周期 | 插件元数据稳定（id、order、category、stage、policy） | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `pluginMetadata` |
| 58 | AgentLoop 工具观察者 | ToolJobObserver 订阅后可安全取消，重复取消为空操作 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `toolJobObserverCancels` |
| 59 | AgentLoop 工具观察者 | AgentLoop 不是 AgentLoopManager 时 ToolManagerObserver 不崩溃 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `toolManagerObserverHandlesForeignAgentLoop` |
| 60 | AgentLoop 工具观察者 | ToolManagerObserver 订阅真实 ToolManager 后可重复取消 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `toolManagerObserverSubscribesAndCancels` |
| 61 | LLM 错误分类与工具 schema 估算 | 工具调用参数非法视为可恢复 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `toolCallValidationErrorIsRecoverable` |
| 62 | LLM 错误分类与工具 schema 估算 | 流式中断与解码失败视为可恢复 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `transportFailuresAreRecoverable` |
| 63 | LLM 错误分类与工具 schema 估算 | 认证与配置类错误不可恢复 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `configurationFailuresAreNotRecoverable` |
| 64 | LLM 错误分类与工具 schema 估算 | HTTP 错误一律不可恢复，即使摘要含 context | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `httpStatusIsNeverRecoverable` |
| 65 | LLM 错误分类与工具 schema 估算 | 未知错误类型不可恢复 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `unknownErrorIsNotRecoverable` |
| 66 | LLM 错误分类与工具 schema 估算 | 各种上下文超限措辞都能被识别 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `contextLimitPhrasesAreDetected` |
| 67 | LLM 错误分类与工具 schema 估算 | 超限判断忽略大小写 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `contextLimitDetectionIsCaseInsensitive` |
| 68 | LLM 错误分类与工具 schema 估算 | 无关的 HTTP 错误不算超限 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `unrelatedHTTPErrorsAreNotContextLimit` |
| 69 | LLM 错误分类与工具 schema 估算 | 非 HTTP 错误不算超限 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `nonHTTPErrorsAreNotContextLimit` |
| 70 | LLM 错误分类与工具 schema 估算 | 超限判断与可恢复判断互不干扰 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `contextLimitAndRecoverableAreIndependent` |
| 71 | LLM 错误分类与工具 schema 估算 | 没有工具时估算为 0 | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `estimateIsZeroForEmptySchemas` |
| 72 | LLM 错误分类与工具 schema 估算 | 工具 schema 估算等于名称、描述、参数与固定开销之和 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `estimateSumsNameDescriptionParametersAndOverhead` |
| 73 | LLM 错误分类与工具 schema 估算 | 多个工具的估算等于单工具估算之和 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `estimateAccumulatesAcrossSchemas` |
| 74 | LLM 错误分类与工具 schema 估算 | 参数无法序列化时降级为文本估算而不崩溃 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `estimateFallsBackWhenParametersAreNotSerializable` |
| 75 | LLM 错误分类与工具 schema 估算 | 畸形工具不影响同批次其它工具的估算 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `malformedSchemaDoesNotBreakBatchEstimation` |
| 76 | LLM 错误分类与工具 schema 估算 | 空名称与描述仍计入固定开销 | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `estimateAlwaysIncludesFixedOverhead` |
| 77 | 挂起回落必须区分授权与交互 | ask_user 挂起不得被标成待授权 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `askUserSuspensionKeepsNonAuthorizationState` |
| 78 | 挂起回落必须区分授权与交互 | 授权挂起仍然回落为待授权 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `permissionSuspensionStillResetsToPending` |
| 79 | 挂起回落必须区分授权与交互 | 挂起类型由载荷的 kind 字段决定 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `suspensionKindIsDecidedByPayload` |
| 80 | 工具挂起时的授权状态回落 | 工具挂起时授权状态回落为 pendingAuthorization | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `suspensionResetsAuthorizationStateToPending` |
| 81 | 工具挂起时的授权状态回落 | needsUserResponse 分支同样回落为 pendingAuthorization | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `needsUserResponseBranchResetsAuthorizationState` |
| 82 | 工具挂起时的授权状态回落 | 挂起后回合停在等待用户输入 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `suspensionStillPutsTurnIntoAwaitingUser` |
| 83 | 工具挂起时的授权状态回落 | 正常完成的工具调用不回落授权状态 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `completedToolCallKeepsItsAuthorizationState` |
| 84 | 挂起回合的取消 | 取消挂起回合后状态收敛到 cancelled 且挂起点消失 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `cancellingSuspendedTurnClearsSuspension` |
| 85 | 挂起回合的取消 | 取消挂起回合时残留的授权占位写成 userRejected 终态 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `cancellingSuspendedTurnSettlesAuthorizationPlaceholder` |
| 86 | 挂起回合的取消 | 取消挂起回合时终态事件必须投递出去 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `cancellingSuspendedTurnDeliversCancelledEvent` |
| 87 | 挂起回合的取消 | ask_user 挂起点不被误写成工具授权终态 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `cancellingAskUserTurnKeepsAuthorizationStateUntouched` |
| 88 | 挂起回合的取消 | 恢复回合过程中被取消，回合不得复活 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `cancellingDuringResumeDoesNotReviveTurn` |
| 89 | Tool 调用身份归一化的边界分支 | ids(in:) 收集 assistant 工具调用与 tool 结果的 ID | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `idsCollectsToolCallIDsFromBothRoles` |
| 90 | Tool 调用身份归一化的边界分支 | ids(in:) 忽略空字符串 toolCallID | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `idsIgnoresEmptyToolCallID` |
| 91 | Tool 调用身份归一化的边界分支 | ids(in:) 容忍没有工具调用的消息 | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `idsToleratesMessagesWithoutToolCalls` |
| 92 | Tool 调用身份归一化的边界分支 | 空白工具调用 ID 会被替换为生成的唯一 ID | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `normalizeReplacesWhitespaceOnlyID` |
| 93 | Tool 调用身份归一化的边界分支 | 带前后空白的有效 ID 归一化为 trim 后的值 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `normalizeTrimsSurroundingWhitespaceOfValidID` |
| 94 | Tool 调用身份归一化的边界分支 | 归一化按 trim 后的 ID 判定冲突 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `normalizeDetectsCollisionAfterTrim` |
| 95 | Tool 调用身份归一化的边界分支 | 没有工具调用时归一化原样返回响应 | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `normalizeReturnsResponseUnchangedWithoutToolCalls` |
| 96 | 消息与 LLM 消息互转的边界分支 | 没有结果的 assistant 工具调用不参与图片收集 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `llmMessagesSkipsToolCallsWithoutResult` |
| 97 | 消息与 LLM 消息互转的边界分支 | 没有工具调用的 assistant 消息跳过图片收集 | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `llmMessagesSkipsAssistantWithoutToolCalls` |
| 98 | 消息与 LLM 消息互转的边界分支 | 未知 LLM 角色恢复为消息时回落到 system | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `messageFromLLMMessageFallsBackToSystemForUnknownRole` |
| 99 | 消息与 LLM 消息互转的边界分支 | 合法 LLM 角色原样保留 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `messageFromLLMMessagePreservesKnownRoles` |
| 100 | 消息与 LLM 消息互转的边界分支 | 非 user 角色的图片不会写回附件 metadata | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `messageFromLLMMessageSkipsMetadataForNonUserRole` |
| 101 | 消息与 LLM 消息互转的边界分支 | 非法 base64 的图片附件被安全丢弃 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `llmMessageDropsInvalidBase64ImageAttachments` |
| 102 | 消息与 LLM 消息互转的边界分支 | 没有 toolCallID 的 tool 消息不会获得图片 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `llmMessageToolWithoutToolCallIDGetsNoImages` |
| 103 | 消息与 LLM 消息互转 | 持久化的 redacted thinking 会进入下一轮 LLMMessage | 构造带 `redactedThinkingData` 的 assistant 消息 | 读取 `llmMessage` | `redactedThinking` 按顺序还原 opaque data | P1 | ✅ 已覆盖 | `llmMessageCarriesRedactedThinking` |
| 104 | AgentLoop 注入预算 | 钩子注入预算等于输入上限扣除已准备历史 | 输入上限 = 历史估算 + 1200 | 调用 `injectedContentTokenBudget` | 返回 1200，历史不被重复计入 | P1 | ✅ 已覆盖 | `budgetSubtractsPreparedHistory` |
| 105 | AgentLoop 注入预算 | 历史占满输入上限时注入预算收敛为 0 | 输入上限小于历史估算 | 调用 `injectedContentTokenBudget` | 返回 0，不会出现负预算 | P2 | ✅ 已覆盖 | `budgetNeverGoesNegative` |
| 106 | AgentLoop 上下文校准 | 校准优先使用缓存总输入（**回归 #968**） | 响应分别带 cacheTotal、仅 input、两者皆无 | 调用 `reportedInputTokenCount(for:)` | 依次返回 30,000、input 值、nil | P1 | ✅ 已覆盖 | `calibrationUsesCacheTotalInput` |
| 107 | 工具参数裁剪进入模型上下文 | show_html 的 html 原文不再进入模型上下文（**回归 #1053**） | assistant 历史含带标记的 show_html 调用与一次普通调用 | 调用 `llmMessages(from:omittedArgumentKeys:)` | html 被替换为占位符、其余参数与调用配对不变 | P0 | ✅ 已覆盖 | `llmMessagesScrubsOmittedArguments` |
| 108 | 工具参数裁剪进入模型上下文 | 没有裁剪声明时工具参数保持原样 | 历史含 show_html 调用但未传裁剪表 | 调用 `llmMessages(from:)` | 参数逐字保留 | P1 | ✅ 已覆盖 | `llmMessagesKeepsUndeclaredArguments` |
| 109 | 工具参数裁剪进入模型上下文 | 按工具名收集裁剪声明，未声明的工具不出现 | 两个工具，仅一个声明裁剪键 | 调用 `contextOmittedArgumentKeys(for:)` | 只返回声明了键的工具 | P1 | ✅ 已覆盖 | `contextOmittedArgumentKeysCollectsDeclarations` |
| 110 | 同一批次多个挂起点的恢复 | 恢复一个挂起后停在剩余挂起点，不发起 LLM 请求（**回归 #1026**） | 两个 ask_user 同时挂起，active 是第二个 | 回答第二个挂起 | 回合停在第一个挂起点并投递挂起事件，LLM 请求次数为 0 | P0 | ✅ 已覆盖 | `resumingOneSuspensionKeepsRemainingActive` |
| 111 | 同一批次多个挂起点的恢复 | 依次回答全部挂起后才发起下一次 LLM 请求 | 两个 ask_user 同时挂起 | 先回答第二个，再回答第一个 | 两条调用都有 role=tool 结果，之后才请求 LLM 并完成回合 | P1 | ✅ 已覆盖 | `allSuspensionsMustBeAnsweredBeforeNextLLMRequest` |
| 112 | 同一批次多个挂起点的恢复 | 只有一个挂起时行为不变，直接继续回合 | 仅一个 ask_user 挂起 | 回答该挂起 | 不产生额外挂起事件，直接请求 LLM 并完成回合 | P1 | ✅ 已覆盖 | `singleSuspensionStillContinuesAfterResume` |
| 113 | 压缩历史下的工具调用身份归一化 | 同回合较早的 `ls_0` 已被压缩出上下文，provider 再次返回 `ls_0` 时必须换新 ID（**回归 #1024**） | 同回合 assistant/tool 消息含 `ls_0`，压缩历史不含 | 调用 `performLLMRequest` | 响应与落库消息使用新 ID，不再命中旧 Job | P1 | ✅ 已覆盖 | `compressedTurnToolCallIDIsStillNormalized` |
| 114 | 压缩历史下的工具调用身份归一化 | 其他回合使用过的 ID 不参与本回合去重 | 其他回合含 `ls_0`，本回合未使用 | 调用 `performLLMRequest` | 响应保留 `ls_0` | P1 | ✅ 已覆盖 | `otherTurnToolCallIDIsNotReserved` |
| 115 | 消息与 LLM 消息互转的边界分支 | 回归 #955：工具失败标志在历史转换与钩子回写中不丢失 | 构造 `isError: true` 的 tool 消息与 LLM 消息 | 转成 `LLMMessage`，再用 `messageFromLLMMessage` 回写 | 两处都保留失败标志，非错误消息为 false | P0 | ✅ 已覆盖 | `llmMessageCarriesToolErrorFlag` |
| 116 | 同一批次多个挂起点的恢复 | 恢复后必须重新声明运行中，避免会话状态停在 suspended（**回归 #944**） | 仅一个 ask_user 挂起，回答后没有剩余工具调用 | 回答该挂起 | 恢复路径同步发布回合运行事件，订阅方可将状态置回 running | P0 | ✅ 已覆盖 | `resumePublishesRunningEvent` |

> 说明：全部 **116 条场景**已在本包 `swift test` 中实跑通过。
> 用例名与描述取自 `Tests/` 下的真实 `@Test` 声明，改动测试时须同步本表。

## 覆盖率统计

- P0: 已覆盖 27 / 27
- P1: 已覆盖 77 / 77
- P2: 已覆盖 12 / 12
- **合计: 116 / 116**（仅表示清单场景，非源码覆盖率）

## 优先级说明

- **P0**: 描述/名称含崩溃、泄漏、截断、丢失、竞态、超时、必须、不得、重试等失效类信号的用例（27 条）
- **P1**: 其余功能性用例（77 条）
- **P2**: 稳定常量、占位、文案、空集合等边界用例（12 条）

## 跨平台说明

- Package 声明: macOS 14+, iOS 17+
- 116 条用例位于 `Tests/`，需在目标平台执行 `swift test`

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
