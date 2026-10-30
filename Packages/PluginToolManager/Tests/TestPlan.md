# TestPlan — PluginToolManager

## 包概述

PluginToolManager 的实现包，包含 14 个主要类型；当前测试覆盖 52 条用例。

平台: macOS 14+, iOS 17+
测试文件: 4 个，用例总数: 52

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

> 说明：全部 **52 条场景**已在本包 `swift test` 中实跑通过。
> 用例名与描述取自 `Tests/` 下的真实 `@Test` 声明，改动测试时须同步本表。

## 覆盖率统计

- P0: 已覆盖 5 / 5
- P1: 已覆盖 43 / 43
- P2: 已覆盖 4 / 4
- **合计: 52 / 52**（仅表示清单场景，非源码覆盖率）

## 优先级说明

- **P0**: 描述/名称含崩溃、泄漏、截断、丢失、竞态、超时、必须、不得、重试等失效类信号的用例（5 条）
- **P1**: 其余功能性用例（43 条）
- **P2**: 稳定常量、占位、文案、空集合等边界用例（4 条）

## 跨平台说明

- Package 声明: macOS 14+, iOS 17+
- 52 条用例位于 `Tests/`，需在目标平台执行 `swift test`

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
