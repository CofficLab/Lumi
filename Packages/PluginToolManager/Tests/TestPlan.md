# TestPlan — PluginToolManager

## 包概述

PluginToolManager 的实现包，包含 14 个主要类型；当前测试覆盖 97 条用例。

平台: macOS 14+, iOS 17+
测试文件: 8 个，用例总数: 97

核心组件（源码目录）:
- `Capabilities/`
- `Managers/`
- `Observers/`
- `Support/`
- `Tools/`
- `ViewModels/`
- `Views/`

## 公开 API

包内主要类型（按声明顺序抽取，供定位被测对象）:

- `PluginToolManager`
- `ToolManagerServiceObserverHandle`
- `ToolManagerCapability`
- `ToolExecutionManager`
- `ToolExecutionOutcome`
- `ToolInteractionPayload`
- `ToolInteractionPayload`
- `ToolManagerEventManager`
- `ToolCallsObserver`
- `WorkspacePathResolver`
- `EditFileTool`
- `GlobTool`
- `ListDirectoryTool`
- `ReadFileTool`

## 关键行为契约（实现约定，非协议要求）

按测试模块归纳，改动对应模块时须保持既有断言成立:

- **综合**（27 条）：由 `toolManagerBatchStopsAtApproval`、`authorizedToolReusesExistingResultInsteadOfExecutingAgain`、`unknownToolSkipsAuthorizationAndReturnsNotFoundResult` 等用例锁定；改动该模块时优先跑对应测试文件。
- **ShellDesktopSandbox**（15 条）：由 `desktopSandboxAllowsTerminalCommandsAndNestedChildren`、`desktopSandboxRejectsAppleEventsFromNestedInterpreter`、`compiledHelperInheritsDesktopServiceDenials` 等用例锁定；改动该模块时优先跑对应测试文件。
- **ToolExecutionScheduling**（7 条）：由 `toolContextResolvesProjectForOwningConversation`、`readOnlyJobsRunInParallelWithPerTurnLimit`、`sideEffectJobsCreateAnOrderingBarrier` 等用例锁定；改动该模块时优先跑对应测试文件。
- **ShellCommandRisk**（10 条）：由 `readOnlyCommandsStayLow`、`networkExfiltrationAndDownloadExecuteAreHigh`、`shellToolUsesChainAwareRisk` 等用例锁定；改动风险评估时优先跑 `ShellCommandRiskTests`。
- **ToolJobPersistence**（3 条）：由 `executionLifecycleIsPersisted`、`unfinishedJobsAreSettledAfterRestart`、`deletingConversationCancelsJobsAndClearsRecords` 等用例锁定；改动该模块时优先跑对应测试文件。

## 测试用例清单

| ID | 类别 | 描述 | 前置条件 | 操作步骤 | 预期结果 | 优先级 | 状态 | 测试方法 |
|----|------|------|----------|----------|----------|------|------|----------|
| 1 | 综合 | toolManagerBatchStopsAtApproval | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `toolManagerBatchStopsAtApproval` |
| 2 | 综合 | authorizedToolReusesExistingResultInsteadOfExecutingAgain | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `authorizedToolReusesExistingResultInsteadOfExecutingAgain` |
| 3 | 综合 | unknownToolSkipsAuthorizationAndReturnsNotFoundResult | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `unknownToolSkipsAuthorizationAndReturnsNotFoundResult` |
| 4 | 综合 | toolManagerPluginReplacesFallbackAndRegistersBuiltinTools | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `toolManagerPluginReplacesFallbackAndRegistersBuiltinTools` |
| 5 | 综合 | shellToolUsesTheCurrentWorkspaceRoot | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `shellToolUsesTheCurrentWorkspaceRoot` |
| 6 | 综合 | shellToolUsesTheOwningConversationProjectWhenProvided | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `shellToolUsesTheOwningConversationProjectWhenProvided` |
| 7 | 综合 | shellToolStreamsOutputBeforeCommandCompletes | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `shellToolStreamsOutputBeforeCommandCompletes` |
| 8 | 综合 | toolJobSubmitsWithoutWaitingAndPublishesTerminalEvents | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `toolJobSubmitsWithoutWaitingAndPublishesTerminalEvents` |
| 9 | 综合 | cancellingToolJobFinishesItExactlyOnce | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `cancellingToolJobFinishesItExactlyOnce` |
| 10 | 综合 | timedOutShellJobPublishesTimedOutTerminalState | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `timedOutShellJobPublishesTimedOutTerminalState` |
| 11 | 综合 | duplicateToolJobSubmissionReusesTheExistingJob | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `duplicateToolJobSubmissionReusesTheExistingJob` |
| 12 | 综合 | duplicateToolCallIDAcrossTurnsCreatesIndependentJobs | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `duplicateToolCallIDAcrossTurnsCreatesIndependentJobs` |
| 13 | 综合 | toolCallsObserverSubmitsWithoutWaitingForToolCompletion | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `toolCallsObserverSubmitsWithoutWaitingForToolCompletion` |
| 14 | 综合 | toolCallsObserverDoesNotDropBlockedOrApprovalCalls | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `toolCallsObserverDoesNotDropBlockedOrApprovalCalls` |
| 15 | 综合 | autonomousModeAutoApprovesForcedApprovalTools | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `autonomousModeAutoApprovesForcedApprovalTools` |
| 16 | 综合 | buildModeStillRequiresApprovalForForcedApprovalTools | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `buildModeStillRequiresApprovalForForcedApprovalTools` |
| 17 | 综合 | autoExecutePolicyRunsForcedApprovalToolWithoutApproval | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `autoExecutePolicyRunsForcedApprovalToolWithoutApproval` |
| 18 | 综合 | toolCallsObserverRunsForcedApprovalToolsInAutonomousMode | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `toolCallsObserverRunsForcedApprovalToolsInAutonomousMode` |
| 19 | 综合 | globToolUsesTheCurrentWorkspaceRootWhenPathIsOmitted | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `globToolUsesTheCurrentWorkspaceRootWhenPathIsOmitted` |
| 20 | 综合 | listDirectoryToolUsesTheCurrentWorkspaceRootWhenPathIsOmitted | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `listDirectoryToolUsesTheCurrentWorkspaceRootWhenPathIsOmitted` |
| 21 | 综合 | readFileToolResolvesRelativePathFromTheCurrentWorkspaceRoot | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `readFileToolResolvesRelativePathFromTheCurrentWorkspaceRoot` |
| 22 | 综合 | writeFileToolResolvesRelativePathFromTheCurrentWorkspaceRoot | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `writeFileToolResolvesRelativePathFromTheCurrentWorkspaceRoot` |
| 23 | 综合 | editFileToolResolvesRelativePathFromTheCurrentWorkspaceRoot | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `editFileToolResolvesRelativePathFromTheCurrentWorkspaceRoot` |
| 24 | 综合 | toolManagerEventManagerDispatchesAndCancelsObservers | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `toolManagerEventManagerDispatchesAndCancelsObservers` |
| 25 | 综合 | conversationProjectPathIsIsolatedAcrossSwitchedConversations | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `conversationProjectPathIsIsolatedAcrossSwitchedConversations` |
| 26 | 综合 | fileToolsIgnoreConversationPathAndUseGlobalWorkspaceRoot | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `fileToolsIgnoreConversationPathAndUseGlobalWorkspaceRoot` |
| 27 | 综合 | unboundConversationFallsBackToGlobalWorkspaceRoot | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `unboundConversationFallsBackToGlobalWorkspaceRoot` |
| 28 | ShellDesktopSandbox | desktopSandboxAllowsTerminalCommandsAndNestedChildren | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `desktopSandboxAllowsTerminalCommandsAndNestedChildren` |
| 29 | ShellDesktopSandbox | desktopSandboxRejectsAppleEventsFromNestedInterpreter | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `desktopSandboxRejectsAppleEventsFromNestedInterpreter` |
| 30 | ShellDesktopSandbox | compiledHelperInheritsDesktopServiceDenials | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `compiledHelperInheritsDesktopServiceDenials` |
| 31 | ShellDesktopSandbox | unsandboxedArgumentsSkipTheWrapper | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `unsandboxedArgumentsSkipTheWrapper` |
| 32 | ShellDesktopSandbox | unsandboxedDefaultsToOff | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `unsandboxedDefaultsToOff` |
| 33 | ShellDesktopSandbox | unsandboxedAlwaysRequiresExplicitApproval | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `unsandboxedAlwaysRequiresExplicitApproval` |
| 34 | ShellDesktopSandbox | unsandboxedRaisesRiskLevelToHigh | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `unsandboxedRaisesRiskLevelToHigh` |
| 35 | ShellDesktopSandbox | unsandboxedIsAdvertisedInSchemaAndDescription | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `unsandboxedIsAdvertisedInSchemaAndDescription` |
| 36 | ShellDesktopSandbox | outputBudgetFallsBackToDefault | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `outputBudgetFallsBackToDefault` |
| 37 | ShellDesktopSandbox | outputBudgetHonoursAnExplicitValue | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `outputBudgetHonoursAnExplicitValue` |
| 38 | ShellDesktopSandbox | outputBudgetIsClampedToTheCeiling | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `outputBudgetIsClampedToTheCeiling` |
| 39 | ShellDesktopSandbox | maxOutputBytesIsAdvertisedInSchema | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `maxOutputBytesIsAdvertisedInSchema` |
| 40 | ShellDesktopSandbox | truncatedOutputIsReportedToTheModel | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `truncatedOutputIsReportedToTheModel` |
| 41 | ShellDesktopSandbox | truncatedStderrIsReportedSeparately | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `truncatedStderrIsReportedSeparately` |
| 42 | ShellDesktopSandbox | untruncatedOutputHasNoNotice | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `untruncatedOutputHasNoNotice` |
| 43 | ToolExecutionScheduling | 工具上下文使用发起对话绑定的项目，不受当前选中对话影响 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `toolContextResolvesProjectForOwningConversation` |
| 44 | ToolExecutionScheduling | 只读工具在同一回合并行执行，且不超过四个 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `readOnlyJobsRunInParallelWithPerTurnLimit` |
| 45 | ToolExecutionScheduling | 副作用工具会阻断后续只读工具 | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `sideEffectJobsCreateAnOrderingBarrier` |
| 46 | ToolExecutionScheduling | 副作用工具按提交顺序串行执行 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `sideEffectJobsRemainOrdered` |
| 47 | ToolExecutionScheduling | 不同会话之间不互相阻塞 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `differentConversationsCanRunInParallel` |
| 48 | ToolExecutionScheduling | 未声明能力的自定义工具默认串行 | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `customToolsDefaultToSerialSideEffect` |
| 49 | ToolExecutionScheduling | 内置工具声明了正确的调度能力 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `builtinToolsDeclareSchedulingCapabilities` |
| 50 | ToolJobPersistence | ToolExecutionManager 持久化 Job 生命周期和结果 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `executionLifecycleIsPersisted` |
| 51 | ToolJobPersistence | 启动时未完成的 Job 被安全标记为失败且不自动重跑 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `unfinishedJobsAreSettledAfterRestart` |
| 52 | ToolJobPersistence | 删除会话会取消运行中的 Job 并阻止迟到持久化 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `deletingConversationCancelsJobsAndClearsRecords` |
| 53 | ShellCommandRisk | 只读命令与无副作用参数判低风险 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `readOnlyCommandsStayLow` |
| 54 | ShellCommandRisk | 引号与转义内的分隔符不拆分命令链 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `quotedAndEscapedSeparatorsStayLow` |
| 55 | ShellCommandRisk | 网络外发与下载即执行判高风险 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `networkExfiltrationAndDownloadExecuteAreHigh` |
| 56 | ShellCommandRisk | 嵌套命令替换与解释器间接执行判高风险 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `nestedSubstitutionAndInterpreterExecutionAreHigh` |
| 57 | ShellCommandRisk | 只读命令替换不误判 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `nestedReadOnlySubstitutionStaysLow` |
| 58 | ShellCommandRisk | 破坏性操作、提权与敏感路径判高风险 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `destructivePrivilegeAndSensitivePathsAreHigh` |
| 59 | ShellCommandRisk | 白名单之外的命令 fail-safe 判高风险 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `unknownCommandsFailSafeToHigh` |
| 60 | ShellCommandRisk | 安全重定向与畸形输入边界 | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `harmlessRedirectionAndMalformedInputs` |
| 61 | ShellCommandRisk | 超长输入不崩溃且判高风险 | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `oversizedInputDoesNotCrash` |
| 62 | ShellCommandRisk | ShellTool 接入链式风险分析 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `shellToolUsesChainAwareRisk` |
| 63 | ToolJobPersistence | 启动恢复终态 Job 后发布 restored 批量快照（**回归 #544**） | Job 记录库中已有终态记录 | 挂载记录库等待恢复 | 观察者收到一次 `.restored`，且可按会话查到该 Job | P1 | ✅ 已覆盖 | `restorePublishesSnapshotEvent` |
| 64 | 工具参数安全 | globToolThrowsWhenPatternIsMissing | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `globToolThrowsWhenPatternIsMissing` |
| 65 | 工具参数安全 | listDirectoryToolThrowsWhenDirectoryDoesNotExist | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `listDirectoryToolThrowsWhenDirectoryDoesNotExist` |
| 66 | 工具参数安全 | readFileAcceptsLimitLargerThanFileLength | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `readFileAcceptsLimitLargerThanFileLength` |
| 67 | 工具参数安全 | readFileCapsRepresentableOversizedLimit | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `readFileCapsRepresentableOversizedLimit` |
| 68 | 工具参数安全 | readFileDisplayDescriptionSurvivesIllegalArguments | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `readFileDisplayDescriptionSurvivesIllegalArguments` |
| 69 | 工具参数安全 | readFileHandlesIntMinOffsetWithoutOverflow | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `readFileHandlesIntMinOffsetWithoutOverflow` |
| 70 | 工具参数安全 | readFileHandlesNegativeOffsetCountingFromEnd | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `readFileHandlesNegativeOffsetCountingFromEnd` |
| 71 | 工具参数安全 | readFilePermissionRiskLevelSurvivesIllegalArguments | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `readFilePermissionRiskLevelSurvivesIllegalArguments` |
| 72 | 工具参数安全 | readFileRejectsLimitAboveIntMaxFromJSON | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `readFileRejectsLimitAboveIntMaxFromJSON` |
| 73 | 工具参数安全 | readFileRejectsNegativeLimitInsteadOfTrapping | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `readFileRejectsNegativeLimitInsteadOfTrapping` |
| 74 | 工具参数安全 | readFileRejectsNonFiniteLimit | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `readFileRejectsNonFiniteLimit` |
| 75 | 工具参数安全 | readFileRejectsOutOfRangeLimitFromJSON | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `readFileRejectsOutOfRangeLimitFromJSON` |
| 76 | 工具参数安全 | readFileRejectsUnrepresentableOffset | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `readFileRejectsUnrepresentableOffset` |
| 77 | 工具参数安全 | readFileRejectsZeroLimit | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `readFileRejectsZeroLimit` |
| 78 | 工具参数安全 | readFileReportsOffsetBeyondEndOfFile | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `readFileReportsOffsetBeyondEndOfFile` |
| 79 | 工具参数安全 | shellDisplayDescriptionAndRiskSurviveIllegalArguments | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `shellDisplayDescriptionAndRiskSurviveIllegalArguments` |
| 80 | 工具参数安全 | shellOutputBudgetFallsBackForUnrepresentableValues | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `shellOutputBudgetFallsBackForUnrepresentableValues` |
| 81 | 工具参数安全 | shellOutputBudgetIsClampedToCeiling | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `shellOutputBudgetIsClampedToCeiling` |
| 82 | 工具参数安全 | shellRejectsNegativeTimeoutAsArgumentError | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `shellRejectsNegativeTimeoutAsArgumentError` |
| 83 | 工具参数安全 | shellRejectsUnrepresentableTimeoutAsArgumentError | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `shellRejectsUnrepresentableTimeoutAsArgumentError` |
| 84 | 工具参数安全 | shellStillRunsWithAValidTimeout | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `shellStillRunsWithAValidTimeout` |
| 85 | 工具管理视图 | logAutoSelectsFirstRecord | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `logAutoSelectsFirstRecord` |
| 86 | 工具管理视图 | onlyToolModeWorksWithoutLogStore | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `onlyToolModeWorksWithoutLogStore` |
| 87 | 工具管理视图 | selectedToolFallsBackWhenToolDisappears | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `selectedToolFallsBackWhenToolDisappears` |
| 88 | 工具管理视图 | selectedToolSurvivesReload | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `selectedToolSurvivesReload` |
| 89 | 工具管理视图 | selectModeSwitchesMode | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `selectModeSwitchesMode` |
| 90 | 工具管理视图 | statEntryExposesErrorRate | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `statEntryExposesErrorRate` |
| 91 | 工具管理视图 | statsAutoSelectFirstEntry | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `statsAutoSelectFirstEntry` |
| 92 | 工具管理视图 | toolEntriesFlattenGroupsInOrder | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `toolEntriesFlattenGroupsInOrder` |
| 93 | 工具管理视图 | toolListAutoSelectsFirstTool | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `toolListAutoSelectsFirstTool` |
| 94 | 工具管理视图 | refreshDuringPaginationDropsStalePage | 120 条记录、翻页请求延迟 300ms | 翻页进行中刷新日志 | 刷新不被挡住，列表保持 50 条，旧翻页结果被丢弃，两个加载标记都归零 | P1 | ✅ 已覆盖 | `refreshDuringPaginationDropsStalePage` |

| 95 | 工具恢复 | resolveUserResponseReexecutesAfterAuthorization | 低风险工具首次执行返回 awaitingUserResponse | 用户回答 computer_use.allow_for_task | 必须重新执行工具拿到真实结果，不得复用挂起的授权回执，执行计数为 2 | P0 | ✅ 已覆盖 | `resolveUserResponseReexecutesAfterAuthorization` |
| 96 | 工具恢复 | resolveUserResponseRejectionDoesNotReexecute | 低风险工具首次执行返回 awaitingUserResponse | 用户回答 computer_use.deny | 返回失败结果并带上拒绝说明，执行计数保持 1 | P1 | ✅ 已覆盖 | `resolveUserResponseRejectionDoesNotReexecute` |
| 97 | 工具恢复 | resolveUserResponseKeepsAnswerOnlyBehaviourByDefault | 未声明恢复动作的挂起工具 | 用户给出普通回答 | 回答文本直接作为工具结果，不重新执行 | P1 | ✅ 已覆盖 | `resolveUserResponseKeepsAnswerOnlyBehaviourByDefault` |

> 说明：全部 **97 条场景**已在本包 `swift test` 中实跑通过。
> 用例名与描述取自 `Tests/` 下的真实 `@Test` 声明，改动测试时须同步本表。

## 覆盖率统计

- P0: 已覆盖 6 / 6
- P1: 已覆盖 85 / 85
- P2: 已覆盖 6 / 6
- **合计: 97 / 97**（仅表示清单场景，非源码覆盖率）

## 优先级说明

- **P0**: 描述/名称含崩溃、泄漏、截断、丢失、竞态、超时、必须、不得、重试等失效类信号的用例（6 条）
- **P1**: 其余功能性用例（85 条）
- **P2**: 稳定常量、占位、文案、空集合等边界用例（6 条）

## 跨平台说明

- Package 声明: macOS 14+, iOS 17+
- 97 条用例位于 `Tests/`，需在目标平台执行 `swift test`

## 测试执行

```bash
cd Packages/PluginToolManager
swift test
```

## 维护规则

1. **新增公开 API** → 先在 TestPlan 登记测试用例，再写实现
2. **Bug 修复** → 追加回归用例，标注触发条件
3. **删除用例** → 在 commit message 说明理由
4. **状态同步** → 实现后更新 TestPlan，标记 ✅ 并填写测试方法名
5. **改名同步** → 重命名 `@Test` 函数后必须同步本表，否则 `Scripts/verify-testplan.py` 会报「登记方法在源码不存在」
