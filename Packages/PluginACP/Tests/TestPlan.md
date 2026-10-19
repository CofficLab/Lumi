# TestPlan — PluginACP

## 包概述

PluginACP 的实现包，包含 14 个主要类型；当前测试覆盖 68 条用例。

平台: macOS 14+
测试文件: 5 个，用例总数: 68

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
- **ACPFileClient**（9 条）：由 `testReadWithoutCapabilityThrows`、`testWriteWithoutCapabilityThrows`、`testReadSendsAbsolutePathAndReturnsContent` 等用例锁定；改动该模块时优先跑对应测试文件。
- **ACPProtocolHandler**（17 条）：由 `testInitializeReturnsHandshakeResult`、`testInitializeAcceptsOlderOrNewerVersion`、`testInitializeRejectsMissingParams` 等用例锁定；改动该模块时优先跑对应测试文件。
- **ACPSessionManager**（6 条）：由 `testCreateSessionMapsToConversation`、`testSessionIDFormat`、`testMultipleSessionsAreIndependent` 等用例锁定；改动该模块时优先跑对应测试文件。
- **ACPTurnCoordinator**（30 条）：由 `testStartTurnInsertsUserMessageAndRunsTurn`、`testCompletedTurnSendsTextAndEndTurnResult`、`testCompletedFinalizesOnlyOnce` 等用例锁定；改动该模块时优先跑对应测试文件。

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
| 46 | ACPTurnCoordinator | testSuspendedFreeTextDegradesToTextAndCancel | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testSuspendedFreeTextDegradesToTextAndCancel` |
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

> 说明：全部 **68 条场景**已在本包 `swift test` 中实跑通过。
> 用例名与描述取自 `Tests/` 下的真实 `@Test` 声明，改动测试时须同步本表。

## 覆盖率统计

- P0: 已覆盖 14 / 14
- P1: 已覆盖 53 / 53
- P2: 已覆盖 1 / 1
- **合计: 68 / 68**（仅表示清单场景，非源码覆盖率）

## 优先级说明

- **P0**: 描述/名称含崩溃、泄漏、截断、丢失、竞态、超时、必须、不得、重试等失效类信号的用例（14 条）
- **P1**: 其余功能性用例（53 条）
- **P2**: 稳定常量、占位、文案、空集合等边界用例（1 条）

## 跨平台说明

- Package 声明: macOS 14+
- 68 条用例位于 `Tests/`，需在目标平台执行 `swift test`

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
