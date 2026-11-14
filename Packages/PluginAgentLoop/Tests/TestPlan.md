# TestPlan — PluginAgentLoop

## 包概述

PluginAgentLoop 自定义 AgentLoop 插件,替换默认的 `DefaultAgentLoopProvider`。

平台: macOS 14+, iOS 17+
测试文件: 20 个，用例总数: 152

核心组件（源码目录）:
- `Managers/`
- `Observers/`
- `Support/`

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
- `ToolSchemaBuilder`

## 关键行为契约（实现约定，非协议要求）

按测试模块归纳，改动对应模块时须保持既有断言成立:

- **AgentLoopCancelledTurnProtocolHistory**（1 条）：由 `cancelledTurnLeavesCompleteProtocolHistory` 等用例锁定；改动该模块时优先跑对应测试文件。
- **AgentLoopContextProviderResolution**（2 条）：由 `laterRegisteredProviderIsUsed`、`fallsBackToStartupSnapshot` 等用例锁定；改动该模块时优先跑对应测试文件。
- **AgentLoopGeneratedImage**（2 条）：由 `imageOnlyResponseIsNotFailure`、`generatedImagesArePersisted` 等用例锁定；改动该模块时优先跑对应测试文件。
- **AgentLoopMessageAndLifecycle**（24 条）：由 `insertsToolResultMessage`、`appendsPlainError`、`appendsRenderedError` 等用例锁定；改动该模块时优先跑对应测试文件。
- **AgentLoopModelToolCapability**（2 条）：由 `requestOmitsToolsWhenModelDoesNotSupportThem`、`requestKeepsToolsWhenModelSupportsThem` 等用例锁定；改动该模块时优先跑对应测试文件。
- **AgentLoopModelVisionCapability**（2 条）：由 `requestOmitsImagesWhenModelDoesNotSupportVision`、`requestKeepsImagesWhenModelSupportsVision` 等用例锁定；改动该模块时优先跑对应测试文件。
- **FailedTurnRetryVisibility**（6 条）：由 `failedTurnKeepsCurrentTurnID`、`failedTurnIsRetryable`、`staleTurnIsNotRetryable` 等用例锁定；改动该模块时优先跑对应测试文件。
- **HistoryImageDecoding**（8 条）：由 `nonVisionModeDoesNotDecodeUserImages`、`nonVisionModeDoesNotDecodeToolResultImages`、`visionModeStillDecodesImages` 等用例锁定；改动该模块时优先跑对应测试文件。
- **LLMErrorClassification**（16 条）：由 `toolCallValidationErrorIsRecoverable`、`transportFailuresAreRecoverable`、`configurationFailuresAreNotRecoverable` 等用例锁定；改动该模块时优先跑对应测试文件。
- **MultipleSuspensionsResume**（6 条）：由 `resumingOneSuspensionKeepsRemainingActive`、`allSuspensionsMustBeAnsweredBeforeNextLLMRequest`、`singleSuspensionStillContinuesAfterResume`、`resumeFiresTurnStartedHookAgain` 等用例锁定；改动该模块时优先跑对应测试文件。
- **综合**（19 条）：由 `testPluginInitialization`、`testPluginMetadata`、`testMessageFromLLMMessagePreservesToolCalls` 等用例锁定；改动该模块时优先跑对应测试文件。
- **SuspendedInteractionState**（3 条）：由 `askUserSuspensionKeepsNonAuthorizationState`、`permissionSuspensionStillResetsToPending`、`suspensionKindIsDecidedByPayload` 等用例锁定；改动该模块时优先跑对应测试文件。
- **SuspendedToolAuthorizationState**（4 条）：由 `suspensionResetsAuthorizationStateToPending`、`needsUserResponseBranchResetsAuthorizationState`、`suspensionStillPutsTurnIntoAwaitingUser` 等用例锁定；改动该模块时优先跑对应测试文件。
- **SuspendedTurnCancellation**（5 条）：由 `cancellingSuspendedTurnClearsSuspension`、`cancellingSuspendedTurnSettlesAuthorizationPlaceholder`、`cancellingSuspendedTurnDeliversCancelledEvent` 等用例锁定；改动该模块时优先跑对应测试文件。
- **ToolAuthorizationPersistence**（3 条）：由 `rejectionSurvivesTerminalTurnPhase`、`approvalSurvivesMismatchedTurnID`、`resolvedAuthorizationIsNeverLeftPending` 等用例锁定；改动该模块时优先跑对应测试文件。
- **ToolCallIdentityAndHelpersEdgeCase**（26 条）：由 `idsCollectsToolCallIDsFromBothRoles`、`idsIgnoresEmptyToolCallID`、`idsToleratesMessagesWithoutToolCalls` 等用例锁定；改动该模块时优先跑对应测试文件。
- **ToolCallIdentityCompaction**（2 条）：由 `compressedTurnToolCallIDIsStillNormalized`、`otherTurnToolCallIDIsNotReserved` 等用例锁定；改动该模块时优先跑对应测试文件。
- **ToolJobCancellation**（5 条）：由 `resumingSuspendedTurnReportsRunning`、`invalidResumeRequestKeepsSuspendedTurnObservable`、`lateLLMResponseAfterCancellationIsIgnored` 等用例锁定；改动该模块时优先跑对应测试文件。
- **ToolJobLoop**（6 条）：由 `toolJobsTransitionThroughWaitingPhase`、`cancellingWaitingToolJobsIgnoresLateCompletion`、`unknownToolJobEventIsIgnoredByReducer` 等用例锁定；改动该模块时优先跑对应测试文件。
- **ToolSchemaBuilding**（10 条）：由 `toolWithNormalizedTextCarriesIt`、`toolWithoutNormalizedTextLeavesItNil`、`normalizedTextMatchesDirectSerialization` 等用例锁定；改动该模块时优先跑对应测试文件。

## 测试用例清单

| ID | 类别 | 描述 | 前置条件 | 操作步骤 | 预期结果 | 优先级 | 状态 | 测试方法 |
|----|------|------|----------|----------|----------|------|------|----------|
| 1 | AgentLoopCancelledTurnProtocolHistory | 取消挂起的回合后，每个 tool_call 都有对应的 tool 消息 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `cancelledTurnLeavesCompleteProtocolHistory` |
| 2 | AgentLoopContextProviderResolution | onBoot 后注册的真实上下文 Provider 会被后续请求使用 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `laterRegisteredProviderIsUsed` |
| 3 | AgentLoopContextProviderResolution | 内核注册表里没有上下文 Provider 时回退到启动阶段的快照 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `fallsBackToStartupSnapshot` |
| 4 | AgentLoopGeneratedImage | 只生成图片的响应不被判为空响应失败 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `imageOnlyResponseIsNotFailure` |
| 5 | AgentLoopGeneratedImage | 生成的图片随助手消息落库 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `generatedImagesArePersisted` |
| 6 | AgentLoopMessageAndLifecycle | insertToolResultMessage 写入 tool 消息并带上结果与调用 id | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `insertsToolResultMessage` |
| 7 | AgentLoopMessageAndLifecycle | appendError(content:) 写入 error 角色消息 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `appendsPlainError` |
| 8 | AgentLoopMessageAndLifecycle | appendError(error:) 透传渲染信息与思考内容 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `appendsRenderedError` |
| 9 | AgentLoopMessageAndLifecycle | 未完成渲染信息的错误只写默认描述 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `appendsErrorWithoutRenderInfo` |
| 10 | AgentLoopMessageAndLifecycle | incompleteToolCallMessage 找到仍缺少结果的工具调用 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `findsIncompleteToolCall` |
| 11 | AgentLoopMessageAndLifecycle | 工具调用已有结果时不算未完成 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `ignoresResolvedToolCall` |
| 12 | AgentLoopMessageAndLifecycle | 同一回合内已由 tool 消息回填的调用不算未完成 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `ignoresToolFilledCall` |
| 13 | AgentLoopMessageAndLifecycle | tool 消息属于其他回合时不视为已回填 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `treatsOtherTurnAsUnfilled` |
| 14 | AgentLoopMessageAndLifecycle | 没有工具调用时返回 nil | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `returnsNilWithoutToolCalls` |
| 15 | AgentLoopMessageAndLifecycle | latestAssistantToolCalls 取最近一条带工具调用的 assistant 消息 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `latestAssistantToolCalls` |
| 16 | AgentLoopMessageAndLifecycle | latestAssistantToolCalls 在没有工具调用时返回 nil | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `latestAssistantToolCallsWithoutAny` |
| 17 | AgentLoopMessageAndLifecycle | notifyLLMResponse 发布 toolCallsReceived 事件 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `notifiesToolCallsReceived` |
| 18 | AgentLoopMessageAndLifecycle | 插件元数据稳定 | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `pluginMetadata` |
| 19 | AgentLoopMessageAndLifecycle | 缺少必需 Provider 时 onBoot 直接返回且不注册 AgentLoopProviding | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `onBootWithoutProvidersDoesNothing` |
| 20 | AgentLoopMessageAndLifecycle | 依赖齐备时 onBoot 注册自定义 AgentLoopProviding | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `onBootRegistersAgentLoopProvider` |
| 21 | AgentLoopMessageAndLifecycle | onBoot 会替换内核中已有的默认 AgentLoopProviding | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `onBootReplacesExistingProvider` |
| 22 | AgentLoopMessageAndLifecycle | onReady 缺少 Provider 时不抛错 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `onReadyWithoutProvidersDoesNothing` |
| 23 | AgentLoopMessageAndLifecycle | onShutdown 释放观察者且不抛错 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `onShutdownIsSafe` |
| 24 | AgentLoopMessageAndLifecycle | ToolJobObserver 订阅后可安全取消，重复取消为空操作 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `toolJobObserverCancels` |
| 25 | AgentLoopMessageAndLifecycle | ToolManagerObserver 在 AgentLoop 不是 AgentLoopManager 时不崩溃 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `toolManagerObserverHandlesForeignAgentLoop` |
| 26 | AgentLoopMessageAndLifecycle | ToolManagerObserver 订阅真实 ToolManager 后可取消 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `toolManagerObserverSubscribesAndCancels` |
| 27 | AgentLoopMessageAndLifecycle | 注入预算等于输入上限扣除已准备历史 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `budgetSubtractsPreparedHistory` |
| 28 | AgentLoopMessageAndLifecycle | 历史占满输入上限时注入预算收敛为 0 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `budgetNeverGoesNegative` |
| 29 | AgentLoopMessageAndLifecycle | 上下文校准优先使用缓存总输入（回归 #968） | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `calibrationUsesCacheTotalInput` |
| 30 | AgentLoopModelToolCapability | 模型声明不支持工具时请求不带工具 Schema | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `requestOmitsToolsWhenModelDoesNotSupportThem` |
| 31 | AgentLoopModelToolCapability | 模型声明支持工具时请求仍带工具 Schema | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `requestKeepsToolsWhenModelSupportsThem` |
| 32 | AgentLoopModelVisionCapability | 模型声明不支持视觉时请求不带图片 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `requestOmitsImagesWhenModelDoesNotSupportVision` |
| 33 | AgentLoopModelVisionCapability | 模型声明支持视觉时请求保留图片 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `requestKeepsImagesWhenModelSupportsVision` |
| 34 | FailedTurnRetryVisibility | 回合失败后 currentTurnID 仍返回失败回合的 ID | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `failedTurnKeepsCurrentTurnID` |
| 35 | FailedTurnRetryVisibility | 失败回合可重试：currentTurnID 与错误消息的 turnID 一致时判定成立 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `failedTurnIsRetryable` |
| 36 | FailedTurnRetryVisibility | 过期回合不可重试：currentTurnID 已推进到新回合 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `staleTurnIsNotRetryable` |
| 37 | FailedTurnRetryVisibility | idle 会话没有当前回合，不可重试 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `idleConversationHasNoRetryableTurn` |
| 38 | FailedTurnRetryVisibility | 终态 phase 同样保留回合身份，不影响 completed 回合的读取 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `completedTurnKeepsCurrentTurnID` |
| 39 | FailedTurnRetryVisibility | 失败回合不接收新 Tool Job，终态回合身份不会让旧 Job 复活 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `terminalTurnDoesNotResurrectToolJobs` |
| 40 | HistoryImageDecoding | 非视觉模式（includesImages 为 false）不解码用户图片附件 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `nonVisionModeDoesNotDecodeUserImages` |
| 41 | HistoryImageDecoding | 非视觉模式（includesImages 为 false）不解码工具结果图片 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `nonVisionModeDoesNotDecodeToolResultImages` |
| 42 | HistoryImageDecoding | 视觉模式（includesImages 为 true）照常解码图片 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `visionModeStillDecodesImages` |
| 43 | HistoryImageDecoding | 工具结果图片在视觉模式下会被处理 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `visionModeDecodesToolResultImages` |
| 44 | HistoryImageDecoding | 非视觉模式的消息内容与视觉模式一致（除图片外） | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `nonVisionModeKeepsEverythingExceptImages` |
| 45 | HistoryImageDecoding | 默认参数保持原有行为（携带图片） | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `defaultBehaviourKeepsImages` |
| 46 | HistoryImageDecoding | 历史转换不在主线程上执行 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `historyConversionRunsOffMainThread` |
| 47 | HistoryImageDecoding | 离主线程转换的结果与同步转换完全一致 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `offMainActorConversionMatchesSyncConversion` |
| 48 | LLMErrorClassification | 工具调用参数非法视为可恢复 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `toolCallValidationErrorIsRecoverable` |
| 49 | LLMErrorClassification | 流式中断与解码失败视为可恢复 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `transportFailuresAreRecoverable` |
| 50 | LLMErrorClassification | 认证与配置类错误不可恢复 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `configurationFailuresAreNotRecoverable` |
| 51 | LLMErrorClassification | HTTP 错误一律不可恢复，即使摘要含 context | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `httpStatusIsNeverRecoverable` |
| 52 | LLMErrorClassification | 未知错误类型不可恢复 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `unknownErrorIsNotRecoverable` |
| 53 | LLMErrorClassification | 各种上下文超限措辞都能被识别 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `contextLimitPhrasesAreDetected` |
| 54 | LLMErrorClassification | 超限判断忽略大小写 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `contextLimitDetectionIsCaseInsensitive` |
| 55 | LLMErrorClassification | 无关的 HTTP 错误不算超限 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `unrelatedHTTPErrorsAreNotContextLimit` |
| 56 | LLMErrorClassification | 非 HTTP 错误不算超限 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `nonHTTPErrorsAreNotContextLimit` |
| 57 | LLMErrorClassification | 超限判断与可恢复判断互不干扰 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `contextLimitAndRecoverableAreIndependent` |
| 58 | LLMErrorClassification | 没有工具时估算为 0 | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `estimateIsZeroForEmptySchemas` |
| 59 | LLMErrorClassification | 工具 schema 估算等于各部分之和且可累加 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `estimateSumsNameDescriptionParametersAndOverhead` |
| 60 | LLMErrorClassification | 多个工具的估算等于单工具估算之和 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `estimateAccumulatesAcrossSchemas` |
| 61 | LLMErrorClassification | 参数无法序列化时降级为文本估算而不崩溃 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `estimateFallsBackWhenParametersAreNotSerializable` |
| 62 | LLMErrorClassification | 畸形工具不影响同批次其它工具的估算 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `malformedSchemaDoesNotBreakBatchEstimation` |
| 63 | LLMErrorClassification | 空名称与描述仍计入固定开销 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `estimateAlwaysIncludesFixedOverhead` |
| 64 | MultipleSuspensionsResume | 恢复一个挂起后停在剩余挂起点，不发起 LLM 请求 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `resumingOneSuspensionKeepsRemainingActive` |
| 65 | MultipleSuspensionsResume | 依次回答全部挂起后才发起下一次 LLM 请求 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `allSuspensionsMustBeAnsweredBeforeNextLLMRequest` |
| 66 | MultipleSuspensionsResume | 只有一个挂起时行为不变，直接继续回合 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `singleSuspensionStillContinuesAfterResume` |
| 67 | MultipleSuspensionsResume | 恢复后必须重新声明运行中 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `resumePublishesRunningEvent` |
| 68 | 综合 | testPluginInitialization | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testPluginInitialization` |
| 69 | 综合 | testPluginMetadata | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testPluginMetadata` |
| 70 | 综合 | willSendToLLM message restoration preserves assistant tool calls | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testMessageFromLLMMessagePreservesToolCalls` |
| 71 | 综合 | provider-reused tool-call IDs are normalized across the conversation | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testToolCallIdentityNormalizerAvoidsConversationCollisions` |
| 72 | 综合 | duplicate tool-call IDs within one provider response are normalized | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testToolCallIdentityNormalizerAvoidsResponseCollisions` |
| 73 | 综合 | 可恢复的 LLM 工具协议错误会重试当前回合 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `testRetryableLLMFailureRetriesCurrentTurn` |
| 74 | 综合 | 重试入口只接受匹配的失败回合 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `testRetryTurnRequiresMatchingFailedTurn` |
| 75 | 综合 | LLM 失败结果保留原始错误供专用渲染器使用 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testLLMFailureKeepsStructuredError` |
| 76 | 综合 | LLM 成功响应会清除工具协议恢复状态 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testSuccessfulLLMResponseClearsRecoveryState` |
| 77 | 综合 | 用户图片附件会转换为 LLM 图片 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testMessageToLLMMessagePreservesUserImage` |
| 78 | 综合 | 工具结果图片关联到 tool 消息而不是 assistant | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testToolResultImageIsAttachedToToolMessage` |
| 79 | 综合 | 用户文本文件附件会转换为 LLM 用户正文 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testMessageToLLMMessagePreservesUserFile` |
| 80 | 综合 | LLM 图片恢复为消息时会保留附件 metadata | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testMessageFromLLMMessagePreservesUserImage` |
| 81 | 综合 | 挂起 ask_user 时发送新消息会跳过挂起点并恢复原回合 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testMessageObserverResumesSuspendedTurnWhenUserContinuesChatting` |
| 82 | 综合 | AgentLoop 始终把当前对话的供应商和模型传给请求 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testAgentLoopUsesConversationProviderAndModel` |
| 83 | 综合 | 流式 LLM chunk 同时保留 reasoning 和普通内容 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testAgentLoopStreamsReasoningAndContentFromSameChunk` |
| 84 | 综合 | 挂起高风险工具审批时发送新消息不会绕过审批 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testMessageObserverDoesNotSkipNonAskUserSuspension` |
| 85 | 综合 | 应用重启后授权完成事件会从历史 assistant 消息恢复 Loop | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testHistoricalAuthorizedCompletionRehydratesLoop` |
| 86 | 综合 | 正常挂起回合收到授权完成事件后会继续剩余工具 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testAuthorizedCompletionResumesSuspendedLoop` |
| 87 | SuspendedInteractionState | ask_user 挂起不得被标成待授权 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `askUserSuspensionKeepsNonAuthorizationState` |
| 88 | SuspendedInteractionState | 授权挂起仍然回落为待授权 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `permissionSuspensionStillResetsToPending` |
| 89 | SuspendedInteractionState | 挂起类型由载荷的 kind 字段决定 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `suspensionKindIsDecidedByPayload` |
| 90 | SuspendedToolAuthorizationState | 工具挂起时授权状态回落为 pendingAuthorization | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `suspensionResetsAuthorizationStateToPending` |
| 91 | SuspendedToolAuthorizationState | needsUserResponse 分支同样回落为 pendingAuthorization | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `needsUserResponseBranchResetsAuthorizationState` |
| 92 | SuspendedToolAuthorizationState | 挂起后回合停在等待用户输入 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `suspensionStillPutsTurnIntoAwaitingUser` |
| 93 | SuspendedToolAuthorizationState | 正常完成的工具调用不回落授权状态 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `completedToolCallKeepsItsAuthorizationState` |
| 94 | SuspendedTurnCancellation | 取消挂起回合后状态收敛到 cancelled 且挂起点消失 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `cancellingSuspendedTurnClearsSuspension` |
| 95 | SuspendedTurnCancellation | 取消挂起回合时残留的授权占位写成 userRejected 终态 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `cancellingSuspendedTurnSettlesAuthorizationPlaceholder` |
| 96 | SuspendedTurnCancellation | 取消挂起回合时终态事件必须投递出去 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `cancellingSuspendedTurnDeliversCancelledEvent` |
| 97 | SuspendedTurnCancellation | ask_user 挂起点不被误写成工具授权终态 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `cancellingAskUserTurnKeepsAuthorizationStateUntouched` |
| 98 | SuspendedTurnCancellation | 恢复回合过程中被取消，回合不得复活 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `cancellingDuringResumeDoesNotReviveTurn` |
| 99 | ToolAuthorizationPersistence | 回合已结束时，用户拒绝的终态仍必须写回消息 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `rejectionSurvivesTerminalTurnPhase` |
| 100 | ToolAuthorizationPersistence | turnID 不一致时，用户授权的终态仍必须写回消息 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `approvalSurvivesMismatchedTurnID` |
| 101 | ToolAuthorizationPersistence | 授权终态不会因为状态机缺失而停留在等待授权形态 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `resolvedAuthorizationIsNeverLeftPending` |
| 102 | ToolCallIdentityAndHelpersEdgeCase | ids(in:) 收集 assistant 工具调用与 tool 结果的 ID | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `idsCollectsToolCallIDsFromBothRoles` |
| 103 | ToolCallIdentityAndHelpersEdgeCase | ids(in:) 忽略空字符串 toolCallID | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `idsIgnoresEmptyToolCallID` |
| 104 | ToolCallIdentityAndHelpersEdgeCase | ids(in:) 容忍没有工具调用的消息 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `idsToleratesMessagesWithoutToolCalls` |
| 105 | ToolCallIdentityAndHelpersEdgeCase | 空白工具调用 ID 会被替换为生成的唯一 ID | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `normalizeReplacesWhitespaceOnlyID` |
| 106 | ToolCallIdentityAndHelpersEdgeCase | 带前后空白的有效 ID 归一化为 trim 后的值 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `normalizeTrimsSurroundingWhitespaceOfValidID` |
| 107 | ToolCallIdentityAndHelpersEdgeCase | 归一化按 trim 后的 ID 判定冲突 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `normalizeDetectsCollisionAfterTrim` |
| 108 | ToolCallIdentityAndHelpersEdgeCase | 没有工具调用时归一化原样返回响应 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `normalizeReturnsResponseUnchangedWithoutToolCalls` |
| 109 | ToolCallIdentityAndHelpersEdgeCase | 回归 #1166：ID 无冲突时归一化仍保留 redactedThinking | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `normalizePreservesRedactedThinking` |
| 110 | ToolCallIdentityAndHelpersEdgeCase | 回归 #1166：ID 被替换时归一化仍保留 redactedThinking | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `normalizePreservesRedactedThinkingWhenIDReplaced` |
| 111 | ToolCallIdentityAndHelpersEdgeCase | 回归 #1166：归一化保留 images | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `normalizePreservesImages` |
| 112 | ToolCallIdentityAndHelpersEdgeCase | 回归 #1166：归一化保留全部非身份字段 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `normalizeKeepsEveryNonIdentityField` |
| 113 | ToolCallIdentityAndHelpersEdgeCase | 没有结果的 assistant 工具调用不参与图片收集 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `llmMessagesSkipsToolCallsWithoutResult` |
| 114 | ToolCallIdentityAndHelpersEdgeCase | 回归 #955：工具消息的失败标志会传入 LLM 消息并由钩子回写保留 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `llmMessageCarriesToolErrorFlag` |
| 115 | ToolCallIdentityAndHelpersEdgeCase | 没有工具调用的 assistant 消息跳过图片收集 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `llmMessagesSkipsAssistantWithoutToolCalls` |
| 116 | ToolCallIdentityAndHelpersEdgeCase | 未知 LLM 角色恢复为消息时回落到 system | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `messageFromLLMMessageFallsBackToSystemForUnknownRole` |
| 117 | ToolCallIdentityAndHelpersEdgeCase | 合法 LLM 角色原样保留 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `messageFromLLMMessagePreservesKnownRoles` |
| 118 | ToolCallIdentityAndHelpersEdgeCase | 非 user 角色的图片不会写回附件 metadata | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `messageFromLLMMessageSkipsMetadataForNonUserRole` |
| 119 | ToolCallIdentityAndHelpersEdgeCase | 非法 base64 的图片附件被安全丢弃 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `llmMessageDropsInvalidBase64ImageAttachments` |
| 120 | ToolCallIdentityAndHelpersEdgeCase | 持久化的 redacted thinking 会进入下一轮 LLMMessage | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `llmMessageCarriesRedactedThinking` |
| 121 | ToolCallIdentityAndHelpersEdgeCase | 没有 toolCallID 的 tool 消息不会获得图片 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `llmMessageToolWithoutToolCallIDGetsNoImages` |
| 122 | ToolCallIdentityAndHelpersEdgeCase | show_html 的 html 原文不再进入模型上下文 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `llmMessagesScrubsOmittedArguments` |
| 123 | ToolCallIdentityAndHelpersEdgeCase | 没有裁剪声明时工具参数保持原样 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `llmMessagesKeepsUndeclaredArguments` |
| 124 | ToolCallIdentityAndHelpersEdgeCase | 按工具名收集裁剪声明，未声明的工具不出现 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `contextOmittedArgumentKeysCollectsDeclarations` |
| 125 | ToolCallIdentityAndHelpersEdgeCase | 恢复提示插在最新 user 之前，稳定历史前缀逐字节不变 | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `recoveryHintAnchorsBeforeLatestUser` |
| 126 | ToolCallIdentityAndHelpersEdgeCase | 有尾随 system 消息时仍锚定最新 user | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `recoveryHintAnchorsOnLatestUserWithTrailingSystem` |
| 127 | ToolCallIdentityAndHelpersEdgeCase | 没有 user 消息时回退到末尾 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `recoveryHintAppendsWhenNoUser` |
| 128 | ToolCallIdentityCompaction | 被压缩掉的同回合工具调用 ID 仍会被归一化 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `compressedTurnToolCallIDIsStillNormalized` |
| 129 | ToolCallIdentityCompaction | 其他回合的工具调用 ID 不参与本回合去重 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `otherTurnToolCallIDIsNotReserved` |
| 130 | ToolJobCancellation | 恢复中的 awaitingUser 阶段对外显示为 running | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `resumingSuspendedTurnReportsRunning` |
| 131 | ToolJobCancellation | 拒绝无效恢复请求后仍发布有效的挂起状态 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `invalidResumeRequestKeepsSuspendedTurnObservable` |
| 132 | ToolJobCancellation | 取消回合后迟到的 LLM 响应不会复活回合 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `lateLLMResponseAfterCancellationIsIgnored` |
| 133 | ToolJobCancellation | 工具失败和超时都会回写错误并恢复 AgentLoop | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `terminalToolErrorsWakeAgentLoop` |
| 134 | ToolJobCancellation | 取消后的迟到 Job 终态事件不会写回结果 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `lateToolJobCompletionAfterCancellationIsIgnored` |
| 135 | ToolJobLoop | 工具 Job 创建后进入等待态，全部完成后才恢复请求 LLM | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `toolJobsTransitionThroughWaitingPhase` |
| 136 | ToolJobLoop | 取消等待中的工具 Job 后不会被迟到完成事件重新唤醒 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `cancellingWaitingToolJobsIgnoresLateCompletion` |
| 137 | ToolJobLoop | 未知工具 Job 不会修改等待中的 pending 集合 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `unknownToolJobEventIsIgnoredByReducer` |
| 138 | ToolJobLoop | 审批挂起期间其他 Job 完成时保留挂起点并消费结果 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `completedSiblingJobDuringApprovalRemovesOnlyItsPendingCall` |
| 139 | ToolJobLoop | Job 完成事件会回写 assistant 工具调用并恢复下一轮 LLM | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `completedToolJobResumesAgentLoop` |
| 140 | ToolJobLoop | 取消 Agent 回合时会先取消对应的 Tool Job | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `cancellingAgentTurnCancelsAssociatedJobs` |
| 141 | ToolSchemaBuilding | 提供规范化文本的工具会带上它 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `toolWithNormalizedTextCarriesIt` |
| 142 | ToolSchemaBuilding | 未提供规范化文本的工具不带它 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `toolWithoutNormalizedTextLeavesItNil` |
| 143 | ToolSchemaBuilding | 规范化文本与直接序列化结果一致 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `normalizedTextMatchesDirectSerialization` |
| 144 | ToolSchemaBuilding | 工具的 schema 参数与直接解析一致 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `parametersMatchDirectParsing` |
| 145 | ToolSchemaBuilding | 带规范化文本时 token 估算结果与不带时完全相同 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `tokenEstimateIsIdenticalWithAndWithoutNormalizedText` |
| 146 | ToolSchemaBuilding | 规范化文本与序列化路径的字节数一致 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `normalizedAndSerializedByteCountsMatch` |
| 147 | ToolSchemaBuilding | 多个工具的估算结果等于各自估算之和 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `tokenEstimateIsSumOfIndividualEstimates` |
| 148 | ToolSchemaBuilding | 畸形 schema 降级为文本估算而不崩溃 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `malformedSchemaFallsBackToTextEstimation` |
| 149 | ToolSchemaBuilding | schema 数组的组装不在主线程上执行 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `schemaBuildingRunsOffMainThread` |
| 150 | ToolSchemaBuilding | 离主线程组装的 schema 与逐个组装完全一致 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `offMainActorSchemasMatchSequentialBuild` |
| 151 | MultipleSuspensionsResume | 恢复后同一回合再次触发 turnStarted 钩子（回归 #805） | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `resumeFiresTurnStartedHookAgain` |
| 152 | MultipleSuspensionsResume | 恢复后重新挂起时，turnStarted 先于新的 suspended 终态（回归 #805） | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `resumeThenResuspendKeepsHookOrder` |

> 说明：全部 **152 条场景**已在本包 `swift test` 中实跑通过。
> 用例名与描述取自 `Tests/` 下的真实 `@Test` 声明，改动测试时须同步本表。

## 覆盖率统计

- P0: 已覆盖 25 / 25
- P1: 已覆盖 122 / 122
- P2: 已覆盖 5 / 5
- **合计: 152 / 152**（仅表示清单场景，非源码覆盖率）

## 优先级说明

- **P0**: 描述/名称含崩溃、泄漏、截断、丢失、竞态、超时、必须、不得、重试等失效类信号的用例（25 条）
- **P1**: 其余功能性用例（122 条）
- **P2**: 稳定常量、占位、文案、空集合等边界用例（5 条）

## 跨平台说明

- Package 声明: macOS 14+, iOS 17+
- 152 条用例位于 `Tests/`，需在目标平台执行 `swift test`

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
