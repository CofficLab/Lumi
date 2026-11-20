# TestPlan — PluginACP

## 包概述

PluginACP 的实现包，包含 14 个主要类型；当前测试覆盖 101 条用例。

平台: macOS 14+
测试文件: 6 个，用例总数: 101

核心组件（源码目录）:
- `Views/`

## 公开 API

包内主要类型（按声明顺序抽取，供定位被测对象）:

- `ACPClientCapabilitiesStore`
- `ACPClientRequester`
- `ACPConfig`
- `ACPFileBridge`
- `ACPFileClientError`
- `ACPLocalization`
- `ACPProtocolHandler`
- `ACPSessionCreating`
- `ACPStdioServer`
- `ACPStreamObserving`
- `ACPTurnRunning`
- `PluginACP`
- `ACPGuideIllustration`
- `ACPSettingsView`

## 关键行为契约（实现约定，非协议要求）

按测试模块归纳，改动对应模块时须保持既有断言成立:

- **ACPClientRequester**（6 条）：由 `testRequestResolvesWithClientResult`、`testTimeoutThrowsAndClearsWaiter`、`testRemoteErrorMessagePropagates` 等用例锁定；改动该模块时优先跑对应测试文件。
- **ACPFileClient**（13 条）：由 `testReadWithoutCapabilityThrows`、`testWriteWithoutCapabilityThrows`、`testReadSendsAbsolutePathAndReturnsContent` 等用例锁定；路径越权判定必须解析符号链接，workspace 内指向外部的 symlink 读写不得放行，workspace 内及经符号链接到达的 root 下的合法文件不得误拒（**回归 #356**）；改动该模块时优先跑对应测试文件。
- **ACPProtocolHandler**（17 条）：由 `testInitializeReturnsHandshakeResult`、`testInitializeAcceptsOlderOrNewerVersion`、`testInitializeRejectsMissingParams` 等用例锁定；改动该模块时优先跑对应测试文件。
- **ACPSessionManager**（6 条）：由 `testCreateSessionMapsToConversation`、`testSessionIDFormat`、`testMultipleSessionsAreIndependent` 等用例锁定；改动该模块时优先跑对应测试文件。
- **ACPTurnCoordinator**（58 条）：由 `testStartTurnInsertsUserMessageAndRunsTurn`、`testCompletedTurnSendsTextAndEndTurnResult`、`testCompletedFinalizesOnlyOnce` 等用例锁定；改动该模块时优先跑对应测试文件。可重试失败与自动重试共享生命周期：重试接管时不得提前收尾，放弃或取消时才返回终态（**#935**）。选项标签先去重再构造 optionId/answers 字典，重复标签不得触发崩溃（**#221**）。失败回合也必须补发已落库工具结果的 completed/failed 终态，不得让工具行永久 pending（**#481**）。工具调用元数据按 `(sessionID, toolCallID)` 隔离：不同会话上报相同 toolCallId 时，授权弹窗必须展示本会话自己的标题/类别/入参，不得被其它会话覆盖或借用，取消收尾也只作用于本会话（**#353**）。首响应超时拒绝必须同时取消底层回合，超时后不得再执行或上报新的工具副作用（**#222**）。流式增量桥按底层流式消息身份（每次 `start` 新建消息）使用独立发送偏移：一个回合内「LLM → 工具 → LLM」的第二段正文必须完整且恰好发送一次，不得沿用第一段偏移被截断或整段丢弃（**#351**）。任何流式通知（正文或思考 token）都证明 LLM 正在产出，必须据此解除首响应 watchdog：健康的长流式回答（含纯思考阶段）不得被误判为「无 LLM 进展」而拒绝并取消底层回合；但装配流式桥本身不解除 watchdog，底层毫无流式活动时仍须照常超时拒绝（**#352**）。`session/cancel` 与 `session/prompt` 同一 burst 到达、runner Task 尚未启动（AgentLoop runtime 未创建、`cancelTurn` 为 no-op）时，取消必须仍然生效：持有并取消 runner Task 句柄，`runTurnTask` 启动前据此跳过模型/工具，由 `cancel()` 的 finalize 以 cancelled 收尾；取消标志随该回合 Task 存续，不得污染同一会话的下一回合，也不得误跳过已合法启动的运行中回合（**#480**）。AskUser 兜底（载荷缺失/选项为空/自由文本降级）由协调器主动结束回合而非客户端取消，wire stopReason 必须映射为 end_turn；只有客户端 `session/cancel` 产生的取消才收尾为 cancelled（**#482**）。回合收尾的补发按 `.started` 登记的 turnID 限定范围：取消（尤其是尚未产生任何内容的空回合）不得回放上一回合的回复文本或历史回合的工具终态，正常结束的文本回填也只取当前回合产生的消息（**#220**）。

## 测试用例清单

| ID | 类别 | 描述 | 前置条件 | 操作步骤 | 预期结果 | 优先级 | 状态 | 测试方法 |
|----|------|------|----------|----------|----------|------|------|----------|
| 1 | ACPClientRequester | testRequestResolvesWithClientResult | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testRequestResolvesWithClientResult` |
| 2 | ACPClientRequester | testTimeoutThrowsAndClearsWaiter | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `testTimeoutThrowsAndClearsWaiter` |
| 3 | ACPClientRequester | testRemoteErrorMessagePropagates | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testRemoteErrorMessagePropagates` |
| 4 | ACPClientRequester | testCancelRequestsForSessionOnlyAffectsThatSession | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testCancelRequestsForSessionOnlyAffectsThatSession` |
| 5 | ACPClientRequester | testResponseAfterCancelIsIgnored | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testResponseAfterCancelIsIgnored` |
| 6 | ACPClientRequester | testAgentIDsStartAboveClientRange | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testAgentIDsStartAboveClientRange` |
| 7 | ACPFileClient | testReadWithoutCapabilityThrows | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testReadWithoutCapabilityThrows` |
| 8 | ACPFileClient | testWriteWithoutCapabilityThrows | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testWriteWithoutCapabilityThrows` |
| 9 | ACPFileClient | testReadSendsAbsolutePathAndReturnsContent | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testReadSendsAbsolutePathAndReturnsContent` |
| 10 | ACPFileClient | testWriteSendsContent | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testWriteSendsContent` |
| 11 | ACPFileClient | testRelativePathRejected | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `testRelativePathRejected` |
| 12 | ACPFileClient | testPathOutsideWorkspaceRejected | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `testPathOutsideWorkspaceRejected` |
| 13 | ACPFileClient | testTraversalEscapeRejected | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `testTraversalEscapeRejected` |
| 14 | ACPFileClient | testClientErrorPropagates | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testClientErrorPropagates` |
| 15 | ACPFileClient | testIsContainedUsesPathComponents | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testIsContainedUsesPathComponents` |
| 16 | ACPProtocolHandler | testInitializeReturnsHandshakeResult | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testInitializeReturnsHandshakeResult` |
| 17 | ACPProtocolHandler | testInitializeAcceptsOlderOrNewerVersion | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testInitializeAcceptsOlderOrNewerVersion` |
| 18 | ACPProtocolHandler | testInitializeRejectsMissingParams | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `testInitializeRejectsMissingParams` |
| 19 | ACPProtocolHandler | testSessionNewCreatesMappedSession | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testSessionNewCreatesMappedSession` |
| 20 | ACPProtocolHandler | testSessionNewRejectsEmptyCwd | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `testSessionNewRejectsEmptyCwd` |
| 21 | ACPProtocolHandler | testSessionNewRejectsMissingParams | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `testSessionNewRejectsMissingParams` |
| 22 | ACPProtocolHandler | testUnknownMethodReturnsMethodNotFound | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testUnknownMethodReturnsMethodNotFound` |
| 23 | ACPProtocolHandler | testNotificationIsIgnored | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testNotificationIsIgnored` |
| 24 | ACPProtocolHandler | testSessionPromptRejectsUnknownSession | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `testSessionPromptRejectsUnknownSession` |
| 25 | ACPProtocolHandler | testSessionNewRejectsRelativeCwd | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `testSessionNewRejectsRelativeCwd` |
| 26 | ACPProtocolHandler | testSessionNewAcceptsMCPServersWithoutFailing | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testSessionNewAcceptsMCPServersWithoutFailing` |
| 27 | ACPProtocolHandler | testMCPServerNameExposedForAllTransports | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testMCPServerNameExposedForAllTransports` |
| 28 | ACPProtocolHandler | testInitializeCapturesFileSystemCapabilities | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testInitializeCapturesFileSystemCapabilities` |
| 29 | ACPProtocolHandler | testInitializeWithoutCapabilitiesKeepsDefaults | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `testInitializeWithoutCapabilitiesKeepsDefaults` |
| 30 | ACPProtocolHandler | testPartialFileSystemCapabilityIsNotBridgeable | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testPartialFileSystemCapabilityIsNotBridgeable` |
| 31 | ACPProtocolHandler | testResponseRoutesToRequesterByID | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testResponseRoutesToRequesterByID` |
| 32 | ACPProtocolHandler | testErrorResponseRoutesToRequester | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testErrorResponseRoutesToRequester` |
| 33 | ACPSessionManager | testCreateSessionMapsToConversation | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testCreateSessionMapsToConversation` |
| 34 | ACPSessionManager | testSessionIDFormat | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testSessionIDFormat` |
| 35 | ACPSessionManager | testMultipleSessionsAreIndependent | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testMultipleSessionsAreIndependent` |
| 36 | ACPSessionManager | testRemoveSessionCleansBothMappings | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testRemoveSessionCleansBothMappings` |
| 37 | ACPSessionManager | testCreateSessionPropagatesFailure | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testCreateSessionPropagatesFailure` |
| 38 | ACPSessionManager | testRecordCarriesCreatedAt | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testRecordCarriesCreatedAt` |
| 39 | ACPTurnCoordinator | testStartTurnInsertsUserMessageAndRunsTurn | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testStartTurnInsertsUserMessageAndRunsTurn` |
| 40 | ACPTurnCoordinator | testCompletedTurnSendsTextAndEndTurnResult | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testCompletedTurnSendsTextAndEndTurnResult` |
| 41 | ACPTurnCoordinator | testCompletedFinalizesOnlyOnce | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testCompletedFinalizesOnlyOnce` |
| 42 | ACPTurnCoordinator | testToolCallsReceivedEmitsToolCallNotification | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testToolCallsReceivedEmitsToolCallNotification` |
| 43 | ACPTurnCoordinator | testFinalizePublishesToolResultUpdates | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testFinalizePublishesToolResultUpdates` |
| 44 | ACPTurnCoordinator | testSuspendedYesNoRequestsPermission | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testSuspendedYesNoRequestsPermission` |
| 45 | ACPTurnCoordinator | testSuspendedChoiceRequestsPermissionWithOptions | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testSuspendedChoiceRequestsPermissionWithOptions` |
| 46 | ACPTurnCoordinator | testSuspendedFreeTextDegradesToTextAndEndsTurn | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testSuspendedFreeTextDegradesToTextAndEndsTurn` |
| 47 | ACPTurnCoordinator | testToolPermissionUsesRealToolCallIDAndStandardOptions | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testToolPermissionUsesRealToolCallIDAndStandardOptions` |
| 48 | ACPTurnCoordinator | testToolPermissionAllowSendsInProgressAndResumes | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testToolPermissionAllowSendsInProgressAndResumes` |
| 49 | ACPTurnCoordinator | testToolPermissionRejectResumesWithRejectAnswer | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `testToolPermissionRejectResumesWithRejectAnswer` |
| 50 | ACPTurnCoordinator | testPermissionCancelledOutcomeCancelsTurn | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testPermissionCancelledOutcomeCancelsTurn` |
| 51 | ACPTurnCoordinator | testPermissionFailureCancelsTurn | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testPermissionFailureCancelsTurn` |
| 52 | ACPTurnCoordinator | testPermissionRequestTimeoutCancelsTurn | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `testPermissionRequestTimeoutCancelsTurn` |
| 53 | ACPTurnCoordinator | testFinalizeMarksPendingToolCallsCancelled | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testFinalizeMarksPendingToolCallsCancelled` |
| 54 | ACPTurnCoordinator | testFinalizeCancelsPendingPermissionRequest | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testFinalizeCancelsPendingPermissionRequest` |
| 55 | ACPTurnCoordinator | testSessionCancelCancelsPendingPermission | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testSessionCancelCancelsPendingPermission` |
| 56 | ACPTurnCoordinator | testCancelSendsCancelledStopReason | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testCancelSendsCancelledStopReason` |
| 57 | ACPTurnCoordinator | testStartTurnRejectsUnknownSession | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `testStartTurnRejectsUnknownSession` |
| 58 | ACPTurnCoordinator | testStartTurnRejectsEmptyText | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `testStartTurnRejectsEmptyText` |
| 59 | ACPTurnCoordinator | testStartTurnRejectsConcurrentTurn | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `testStartTurnRejectsConcurrentTurn` |
| 60 | ACPTurnCoordinator | testWatchdogFiresWhenNoLLMProgress | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testWatchdogFiresWhenNoLLMProgress` |
| 61 | ACPTurnCoordinator | testWatchdogCancelledAfterLLMProgress | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testWatchdogCancelledAfterLLMProgress` |
| 62 | ACPTurnCoordinator | testStreamingEmitsIncrementalChunks | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testStreamingEmitsIncrementalChunks` |
| 63 | ACPTurnCoordinator | testStreamedTurnDoesNotResendFullTextAtFinalize | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testStreamedTurnDoesNotResendFullTextAtFinalize` |
| 64 | ACPTurnCoordinator | testFailedTurnReportsRefusal | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testFailedTurnReportsRefusal` |
| 65 | ACPTurnCoordinator | testCancelledTurnStillReportsCancelledNotRefusal | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testCancelledTurnStillReportsCancelledNotRefusal` |
| 66 | ACPTurnCoordinator | testTextExtraction | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testTextExtraction` |
| 67 | ACPTurnCoordinator | testToolKindInference | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testToolKindInference` |
| 68 | ACPTurnCoordinator | testChoiceOptionsParsing | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testChoiceOptionsParsing` |
| 69 | ACP 文件桥参数 | 超大 limit 返回 nil 而不是崩溃 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `oversizedLimitReturnsNil` |
| 70 | ACP 文件桥参数 | 超大 line 返回 nil 而不是崩溃 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `oversizedLineReturnsNil` |
| 71 | ACP 文件桥参数 | 非有限值返回 nil | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `nonFiniteReturnsNil` |
| 72 | ACP 文件桥参数 | 范围内的整数正常解析 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `inRangeIntegersParse` |
| 73 | ACP 文件桥参数 | 缺失或非数值参数返回 nil | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `missingOrNonNumericReturnsNil` |
| 74 | ACPTurnCoordinator | 重试接管期间失败事件不提前返回终态（**#935**） | 重试生命周期报告该会话正在重试 | 触发可重试失败事件 | 原 prompt 不收尾；重试成功后才返回 endTurn | P1 | ✅ 已覆盖 | `testFailedTurnDefersFinalizeWhileRetryActive` |
| 75 | ACPTurnCoordinator | 重试耗尽时向原 prompt 返回 refusal（**#935**） | 重试接管后发布 gaveUp | 触发放弃事件 | 返回 refusal 并上报原因 | P1 | ✅ 已覆盖 | `testRetryGaveUpReportsRefusal` |
| 76 | ACPTurnCoordinator | 没有重试接管时失败仍立即返回 refusal（**#935**） | 注入的重试生命周期报告未重试 | 触发失败事件 | 立即返回 refusal | P1 | ✅ 已覆盖 | `testFailedTurnWithInactiveRetryStillReportsRefusal` |
| 77 | ACPTurnCoordinator | 重试期间取消会终止重试并返回 cancelled（**#935**） | 可重试失败后进入重试等待 | 调用 `cancel(sessionID:)` | 取消待执行重试、返回 cancelled，迟到完成事件不重复响应 | P1 | ✅ 已覆盖 | `testCancelDuringRetryStopsRetryAndReportsCancelled` |
| 78 | ACPTurnCoordinator | 重复标签必须去重，避免 ACP 用标签构造字典时崩溃（**#221**） | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `testChoiceOptionsDeduplicatesLabels` |
| 79 | ACPTurnCoordinator | 去重后保持标签首次出现顺序（**#221**） | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testChoiceOptionsDedupPreservesFirstOccurrenceOrder` |
| 80 | ACPTurnCoordinator | 字符串与对象形式的同名标签必须一并去重，避免崩溃（**#221**） | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `testChoiceOptionsDedupAcrossStringAndObjectForms` |
| 81 | ACPTurnCoordinator | 去重后标签互异，可安全用作字典键（**#221**） | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testChoiceOptionsLabelsAreUnique` |
| 82 | ACPTurnCoordinator | 失败回合必须补发已落库工具结果，不得永久 pending（**回归 #481**） | 一个工具成功、一个工具错误、一个未出结果，随后 LLM 失败 | 触发 failed 事件收尾 | 成功者 completed、错误者 failed、未出结果者 cancelled，stopReason 为 refusal | P0 | ✅ 已覆盖 | `testFailedTurnPublishesPersistedToolResults` |
| 83 | ACPFileClient | 指向 workspace 外的符号链接读取必须被拒绝（**回归 #356**） | 真实临时 workspace，project/link 指向同级 outside | `readTextFile(link/secret.txt)` | 抛 pathOutsideWorkspace，且不发起 fs 请求 | P0 | ✅ 已覆盖 | `testSymlinkEscapeReadRejected` |
| 84 | ACPFileClient | 指向 workspace 外的符号链接写入必须被拒绝（**回归 #356**） | 真实临时 workspace，project/link 指向同级 outside | `writeTextFile(link/secret.txt)` | 抛 pathOutsideWorkspace，且不发起 fs 请求 | P0 | ✅ 已覆盖 | `testSymlinkEscapeWriteRejected` |
| 85 | ACPFileClient | workspace 内的符号链接正常放行（**回归 #356**） | project/inner 指向 workspace 内的 realdir | `readTextFile(inner/file.txt)` | 正常返回内容并发起 fs 请求，不误拒 | P1 | ✅ 已覆盖 | `testSymlinkInsideWorkspaceStillAllowed` |
| 86 | ACPFileClient | cwd 经符号链接到达时解析 root 后合法文件不误拒（**回归 #356**） | 会话 cwd 为指向 project 的 alias 符号链接 | `readTextFile(alias/file.txt)` | root 与 candidate 均解析后判定包含，正常放行 | P1 | ✅ 已覆盖 | `testRootSymlinkResolvedForContainment` |
| 87 | ACPTurnCoordinator | 两会话同名 toolCallId 时授权弹窗展示本会话入参/类别（**回归 #353**） | 两个独立会话各上报相同 toolCallId、不同工具与入参 | A 进入工具授权 | 弹窗 rawInput/kind 为 A 自己的，不被后上报的 B 覆盖 | P0 | ✅ 已覆盖 | `testToolPermissionMetadataIsolatedPerSession` |
| 88 | ACPTurnCoordinator | 本会话未登记该调用时不得借用其它会话元数据（**回归 #353**） | 仅 B 上报某 toolCallId，A 未上报 | A 以该 id 进入授权 | 回退到问题文本，rawInput/kind 为 nil，不泄漏 B 的入参 | P0 | ✅ 已覆盖 | `testToolPermissionDoesNotLeakOtherSessionMetadata` |
| 89 | ACPTurnCoordinator | 取消会话只收尾本会话未决工具，同名工具不跨会话串扰（**回归 #353**） | 两会话各上报相同 toolCallId 的未决工具 | 取消 A | A 收到 cancelled，B 的同名工具不受影响 | P1 | ✅ 已覆盖 | `testCancelledToolCallsIsolatedPerSession` |
| 90 | ACPTurnCoordinator | 首响应超时必须同时取消底层回合，迟到 cancelled 事件不得重复响应（**#222**） | 看门狗超时无 LLM 进展 | 等待 refusal 响应后再发 cancelled 事件 | cancelTurn 恰好调用一次，响应唯一且保持 refusal | P0 | ✅ 已覆盖 | `testWatchdogTimeoutCancelsUnderlyingTurn` |
| 91 | ACPTurnCoordinator | 超时拒绝后不得再向客户端上报迟到的工具调用（**#222**） | 看门狗超时后模型才回包带工具调用 | 发出 toolCallsReceived 事件 | 不再产生任何新通知或响应 | P0 | ✅ 已覆盖 | `testWatchdogTimeoutIgnoresLateToolCalls` |
| 92 | ACPTurnCoordinator | 第二段更短正文必须完整发出，不得被旧偏移整段丢弃（**回归 #351**） | 一个回合内先流式较长第一段，再 start 新消息 | 流式更短的第二段最终正文 | 两段正文都完整发出 | P0 | ✅ 已覆盖 | `testSecondStreamShorterBodyIsSentFully` |
| 93 | ACPTurnCoordinator | 第二段更长正文必须整段发出，不得截断成后缀（**回归 #351**） | 同上 | 流式更长的第二段正文 | 第二段整段发出而非旧偏移后的后缀 | P0 | ✅ 已覆盖 | `testSecondStreamLongerBodyIsSentCompletely` |
| 94 | ACPTurnCoordinator | 等长不同的第二段正文仍须完整发出（**回归 #351**） | 同上 | 流式与第一段等长但不同的第二段 | 按消息身份重置偏移，第二段完整发出 | P1 | ✅ 已覆盖 | `testSecondStreamEqualLengthBodyIsSentFully` |
| 95 | ACPTurnCoordinator | 偏移按消息重置后收尾去重仍成立，最终正文恰好一次（**回归 #351**） | 两段流式后落库相同最终正文并收尾 | 触发 completed 收尾 | 第二段最终正文恰好流式发送一次，收尾不重发 | P1 | ✅ 已覆盖 | `testSecondStreamFinalBodyNotResentAtFinalize` |
| 96 | ACPTurnCoordinator | 健康长流式正文必须解除首响应 watchdog，不得被误判拒绝（**回归 #352**） | 装配流式桥，turnStartTimeout=0.5s | 流式产出正文后越过超时窗口，再正常收尾 | 窗口内无 refusal、不取消底层回合，最终恰好一次 endTurn | P0 | ✅ 已覆盖 | `testStreamingBodyDisarmsWatchdog` |
| 97 | ACPTurnCoordinator | 纯思考阶段（无正文增量）同样是 LLM 进展，必须解除 watchdog（**回归 #352**） | 装配流式桥，turnStartTimeout=0.5s | 只发思考通知（content 为 nil）后越过超时窗口，再产出正文收尾 | 窗口内无 refusal、不取消底层回合，最终恰好一次 endTurn | P0 | ✅ 已覆盖 | `testThinkingOnlyStreamDisarmsWatchdog` |
| 98 | ACPTurnCoordinator | 装配流式桥但无流式活动时 watchdog 仍须超时拒绝并取消底层回合（**守卫 #352**） | 装配流式桥但底层无任何流式通知 | 等待首响应超时 | 返回 refusal 且 cancelTurn 恰好作用于本会话 | P1 | ✅ 已覆盖 | `testStreamingBridgeWithoutActivityStillTimesOut` |
| 99 | ACPTurnCoordinator | prompt 与 cancel 同一 burst、runner 未启动时取消仍生效，不得跑模型/工具（**回归 #480**） | startTurn 调度 runner Task 后立即 cancel（runtime 未创建） | 等待原 prompt 响应 | runTurn 从未调用，响应唯一且 stopReason 为 cancelled | P0 | ✅ 已覆盖 | `testCancelBeforeRunnerStartDoesNotRunTurn` |
| 100 | ACPTurnCoordinator | 启动前取消不得污染同一会话的下一回合（**守卫 #480**） | 第一回合启动前取消并收尾后，同会话再发新 prompt | 新回合启动并正常收尾 | 新回合 runner 正常启动，stopReason 为 endTurn | P0 | ✅ 已覆盖 | `testCancelBeforeStartDoesNotPoisonNextTurn` |
| 101 | ACPTurnCoordinator | runner 已启动后再取消（运行中取消）仍正常生效，不被启动前判定误跳过（**守卫 #480/#233**） | 等 runner 真正启动后再 cancel | 等待原 prompt 响应 | runTurn 已调用，响应 stopReason 为 cancelled | P1 | ✅ 已覆盖 | `testCancelAfterRunnerStartStillCancelsRunningTurn` |
| 102 | ACPTurnCoordinator | 取消空回合不得回放上一回合的回复文本与历史工具终态（**回归 #220**） | 上一回合已落库回复与已出结果工具；本回合取消在 .started 之前到达 | 等待原 prompt 响应 | stopReason 为 cancelled，无上一回合文本 chunk，无 old_call 终态补发 | P0 | ✅ 已覆盖 | `testCancelledEmptyTurnDoesNotReplayPreviousRound` |
| 103 | ACPTurnCoordinator | 正常结束的文本回填只取当前回合消息，本回合无文本时不取上一回合兜底（**回归 #220**） | .started 登记当前 turnID；本回合只有空 assistant 消息 | 触发 completed 收尾 | endTurn 响应，无上一回合文本 chunk | P0 | ✅ 已覆盖 | `testCompletedTurnBackfillRestrictedToCurrentTurn` |
| 104 | ACPTurnCoordinator | 工具终态补发只覆盖当前回合，历史回合终态不重放（**回归 #220**） | .started 登记当前 turnID；两回合各有已出结果工具 | 触发 completed 收尾 | 当前回合工具补发 completed，历史回合 old_call 不重放，文本回填来自当前回合 | P1 | ✅ 已覆盖 | `testTerminalToolUpdatesRestrictedToCurrentTurn` |
| 105 | ACPTurnCoordinator | 最后一条 assistant 消息带 token 截断 stopReason 时，回合结果必须映射为 max_tokens 而非 end_turn（**回归 #354**） | 落库带 stopReason=length 的 assistant 消息后触发 completed 收尾 | 等待原 prompt 响应 | stopReason 为 maxTokens | P0 | ✅ 已覆盖 | `testTokenLimitTruncationReportsMaxTokens` |

> 说明：全部 **105 条场景**已在本包 `swift test` 中实跑通过。
> 用例名与描述取自 `Tests/` 下的真实 `@Test` 声明，改动测试时须同步本表。

> 变异验证（**#353**，`ACPTurnCoordinator.toolCallMetadata` 按 `(sessionID, toolCallID)` 隔离）：
> - **M1** 还原为裸 `String` 键（`toolCallMetadata[call.id]`，元数据带 `sessionID`，授权按裸 ID 查询、收尾按 `value.sessionID` 过滤）→ `testToolPermissionMetadataIsolatedPerSession`、`testToolPermissionDoesNotLeakOtherSessionMetadata`、`testCancelledToolCallsIsolatedPerSession` 三条全部转红（B 覆盖 A：弹窗展示 B 的入参/类别、A 借用 B 的元数据、取消 A 时 A 的未决工具漏发 cancelled）。
> - 还原完整修复（复合键 `ToolCallKey`，授权按 `(sessionID, toolCallID)` 查询、收尾按 `key.sessionID` 过滤）→ 89 条全绿。

> 变异验证（**#356**，`ACPFileClient.resolvedPath`）：
> - **M1** 去掉符号链接解析（直接按 `standardizedFileURL` 词法路径判定包含）→ `testSymlinkEscapeReadRejected`、`testSymlinkEscapeWriteRejected` 转红（越权 symlink 被放行），`testSymlinkInsideWorkspaceStillAllowed` 仍绿。
> - **M2** 只解析 candidate、root 保持词法（`let realRoot = root`）→ `testRootSymlinkResolvedForContainment` 转红（cwd 经 alias symlink 到达时合法文件被误判越界），两条越权用例仍绿。
> - 还原完整修复（candidate 与 root 均 `resolvingSymlinksInPath()`，返回值仍为归一化原路径）→ 86 条全绿。

> 变异验证（**#222**，`armWatchdog` 超时路径）：
> - **M1** 移除超时分支的 `agentLoop.cancelTurn`（只 finalize 发 refusal）→ `testWatchdogTimeoutCancelsUnderlyingTurn`、`testWatchdogTimeoutIgnoresLateToolCalls` 双双转红（底层回合未被取消）。
> - 还原修复（先取消再收尾）→ 91 条全绿。

> 变异验证（**#351**，`ACPStreamingBridge.flush` 按流式消息身份重置发送偏移）：
> - **M1** 移除「检测到新消息 id 就把 `sentLength` 归零」整段（沿用每会话单一偏移）→ `testSecondStreamShorterBodyIsSentFully`（第二段 "Done" 被整段丢弃）、`testSecondStreamLongerBodyIsSentCompletely`（只发旧偏移后的后缀 " much longer final answer"）、`testSecondStreamEqualLengthBodyIsSentFully`（等长 "BBBB" 被丢弃）、`testSecondStreamFinalBodyNotResentAtFinalize`（最终正文 0 次发送）四条全部转红。
> - 还原完整修复（按 `acpStreamingMessageID` 变化重置偏移）→ 95 条全绿。

> 变异验证（**#352**，流式活动解除首响应 watchdog）：
> - **M1** 去掉协调器 `streaming?.onProgress` 到 `markLLMProgress` 的接线（流式通知不再标记进展）→ `testStreamingBodyDisarmsWatchdog`、`testThinkingOnlyStreamDisarmsWatchdog` 双双转红（健康流式被 watchdog 误判 refusal 并取消底层回合）。
> - **M2** 去掉 `ACPStreamingBridge.flush` 开头的 `onProgress?(conversationID)`（桥不再上报任何流式活动）→ 同样两条转红；`testStreamingBridgeWithoutActivityStillTimesOut` 保持绿（无活动仍照常超时）。
> - 还原完整修复（flush 先上报进展再算增量，协调器据此 `markLLMProgress`）→ 98 条全绿。

> 变异验证（**#480**，启动前取消不丢失）：
> - **M1** 去掉 `runTurnTask` 开头的 `if Task.isCancelled { return }` 启动前判定 → `testCancelBeforeRunnerStartDoesNotRunTurn`、`testCancelBeforeStartDoesNotPoisonNextTurn` 转红（被取消的回合仍调用 runTurn 跑模型/工具）。
> - **M2** 去掉 `cancel()` 里的 `runnerTasks[sessionID]?.cancel()`（不取消尚未启动的 runner Task）→ 同样两条转红（Task 未被取消，`Task.isCancelled` 为 false，runner 照常启动）。
> - 还原完整修复（startTurn 持有句柄、cancel 取消句柄、runTurnTask 启动前据 `Task.isCancelled` 跳过）→ 101 条全绿。
> #482 回归：内核只有 `cancelTurn` 一种停回合手段且固定产生 `.cancelled`，AskUser 兜底停回合被误报为客户端取消（wire stopReason=cancelled）。修复增加 `gracefulStopConversations` 标记集合：三处兜底改经 `stopTurnGracefully` 打标再取消，`.cancelled` 事件与回合作业两处收尾先 `consumeGracefulStop` 消费标记，命中则按 end_turn 收尾。
> 变异验证（**#482**，兜底停回合误报为取消）：把 free_text 分支改回直接 `agentLoop.cancelTurn` → `testSuspendedFreeTextDegradesToTextAndEndsTurn` 转红（stopReason 实际为 cancelled）；还原后 101 条全绿。

> 变异验证（**#220**，回合收尾补发按 turnID 限定范围）：
> - **M1** 去掉 `finalize` 中 `!cancelled, !failed` 的 `!cancelled`（取消回合也回填最终文本）→ `testCancelledEmptyTurnDoesNotReplayPreviousRound` 转红（无 turnID 时空回合回填取到上一回合整段回复）。
> - **M2** 去掉 `publishFinalContent` 的 turnID 过滤 → `testCompletedTurnBackfillRestrictedToCurrentTurn` 转红（上一回合文本被兜底回放）；`testCancelledEmptyTurnDoesNotReplayPreviousRound` 与 `testTerminalToolUpdatesRestrictedToCurrentTurn` 保持绿。
> - **M3** 去掉 `publishTerminalToolUpdates` 的 turnID 过滤 → `testTerminalToolUpdatesRestrictedToCurrentTurn` 转红（历史回合 old_call 终态被重放）；另两条保持绿。
> - **M4** 去掉「取消且回合未登记 turnID 时跳过 `publishTerminalToolUpdates`」的守卫 → `testCancelledEmptyTurnDoesNotReplayPreviousRound` 转红（全量扫描重放 old_call 终态，文本回放断言不触发）。
> - 还原完整修复 → 105 条全绿。

## 覆盖率统计

- P0: 已覆盖 35 / 35
- P1: 已覆盖 69 / 69
- P2: 已覆盖 1 / 1
- **合计: 105 / 105**（仅表示清单场景，非源码覆盖率）

## 优先级说明

- **P0**: 描述/名称含崩溃、泄漏、截断、丢失、竞态、超时、必须、不得、重试等失效类信号的用例（35 条）
- **P1**: 其余功能性用例（69 条）
- **P2**: 稳定常量、占位、文案、空集合等边界用例（1 条）

## 跨平台说明

- Package 声明: macOS 14+
- 105 条用例位于 `Tests/`，需在目标平台执行 `swift test`

## 测试执行

```bash
cd Packages/PluginACP
swift test
```

## 维护规则

1. **新增公开 API** → 先在 TestPlan 登记测试用例，再写实现
2. **Bug 修复** → 追加回归用例，标注触发条件
3. **删除用例** → 在 commit message 说明理由
4. **状态同步** → 实现后更新 TestPlan，标记 ✅ 并填写测试方法名
5. **改名同步** → 重命名 `@Test` 函数后必须同步本表，否则 `Scripts/verify-testplan.py` 会报「登记方法在源码不存在」
