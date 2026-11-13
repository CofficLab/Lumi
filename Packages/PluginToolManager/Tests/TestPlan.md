# TestPlan — PluginToolManager

## 包概述

PluginToolManager 的实现包，包含 14 个主要类型；当前测试覆盖 160 条用例。

平台: macOS 14+, iOS 17+
测试文件: 14 个，用例总数: 160

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
- **ToolExecutionScheduling**（11 条）：由 `toolContextResolvesProjectForOwningConversation`、`readOnlyJobsRunInParallelWithPerTurnLimit`、`sideEffectJobsCreateAnOrderingBarrier` 等用例锁定；改动该模块时优先跑对应测试文件。混合批次中前序读并行、副作用屏障等齐前序读、后续读在屏障后重新并行且不超上限 4；取消单个并行读不牵连兄弟，取消排队中的读立即终态且不执行，整回合取消必须让每个 Job 都拿到终态结果（#1312）。
- **ShellCommandRisk**（10 条）：由 `readOnlyCommandsStayLow`、`networkExfiltrationAndDownloadExecuteAreHigh`、`shellToolUsesChainAwareRisk` 等用例锁定；改动风险评估时优先跑 `ShellCommandRiskTests`。
- **ToolJobPersistence**（3 条）：由 `executionLifecycleIsPersisted`、`unfinishedJobsAreSettledAfterRestart`、`deletingConversationCancelsJobsAndClearsRecords` 等用例锁定；改动该模块时优先跑对应测试文件。
- **后台任务**（12 条）：由 `taskFinishesExactlyOnceOnProcessExit`、`explicitStopTerminatesProcessAndEmitsOnce`、`deletingConversationStopsItsBackgroundTasks` 等用例锁定；改动 `BackgroundTaskRegistry` 时优先跑 `BackgroundTaskRegistryTests`。进程内任务（#1313 后台子代理）经 `adoptInProcess`/`appendOutput`/`finishInProcess` 复用同一套恰好一次守卫。三条易错约定：
  - **后台任务不走 ToolJob 事件通道**：ToolJob 是回合作用域的，回合取消后迟到事件必须丢弃（见 #536）。后台任务的生命周期**跨越回合**——取消当前回合时后台进程必须继续跑，因此它由独立的 actor 管理，绝不能回流到 ToolJob 事件路径。
  - **完成事件恰好一次**：状态迁移都在 actor 内完成，`finished` 只在状态首次从 `.running` 变为终态时发出。进程退出与用户显式停止并发时也只发一次。
  - **取消回合不杀、删除会话要杀**：前者是后台化的意义所在；后者是因为后台进程会继续写文件、占用 CPU，且它的完成通知已经没有收件人。
- **非阻塞命令**（11 条）：由 `schemaAdvertisesBackgroundArguments`、`budgetExpiryHandsOffToBackground`、`sleepCommandWaitsInForeground` 等用例锁定；改动 `ShellTool` 时优先跑 `ShellToolBackgroundTests`。四条易错约定：
  - **`timeout` 是前台预算而不是死线**：预算耗尽时命令**继续在后台跑**，不会被杀掉。这与 KitShell 里 `executeStreaming` 的 kill-on-timeout 语义并存且互不影响。
  - **以 sleep 开头的命令豁免自动后台**：`sleep 5` 的语义就是「等一会儿」，转后台会让模型拿到的不是结果而是一个迟到的通知。显式 `run_in_background=true` 仍然尊重。
  - **后台结果文本必须含三要素**：后台 ID、输出路径、`read_file` 提示。缺一模型就无法继续跟进这个后台任务。
  - **失败必须抛出**：没有登记表时后台化抛 `ToolExecutionError`，不能返回一句「已在后台运行」——那会让模型以为进程还活着。
- **完成通知**（9 条）：由 `idleConversationGetsUserMessage`、`turnFinishedDrainsQueuedNotification`、`duplicateCompletionEventsDeliverOnlyOnce` 等用例锁定；改动 `BackgroundTaskNotificationCoordinator` 时优先跑 `BackgroundTaskNotificationTests`。四条易错约定：
  - **通知写成 `role == .user` 的消息**：Lumi 没有「只给模型看」的标志位，只有反向的 timeline-event 机制。user 消息会触发 `MessageObserver` 起回合，从而唤醒模型。
  - **忙时必须入队而不是直接插入**：回合正在跑时插入消息不会起新回合（`MessageObserver` 因 `isRunning` 直接返回），通知就丢了。忙时入队，由 `turnFinished` 钩子排空。
  - **排空必须延后到回合真正空闲**：`turnFinished` 触发时上一个 `runTurn` 还在退栈，直接起会被判定为并发回合而失败。
  - **抑制期间暂存而非丢弃**：`isAutoReplySuppressed`（ACP 托管回合）时插入的消息会被 `MessageObserver` 丢弃，因此改为暂存，抑制解除后再投递。
- **卡片与停止**（11 条）：由 `stopsRunningTask`、`missingPayloadDecodesToNil`、`unknownStatusDecodesToNil` 等用例锁定；改动 `StopBackgroundTaskTool` / `BackgroundTaskCardRenderer` 时优先跑 `BackgroundTaskCardAndStopToolTests`。三条易错约定：
  - **停止语义复用进程树终止**：后台命令常带子进程（编译器、测试 runner），只杀直接子进程会留下孤儿。因此 `stop` 走 KitShell 的 SIGTERM → 宽限 → SIGKILL。
  - **停止已结束的任务不算失败**：任务已经自然结束时再调 stop 会返回真实状态（「already completed」），而不是抛一个误导性的错误。
  - **载荷缺失必须回退而不是崩溃**：通知消息是持久化的，metadata 可能因旧版本数据而缺失，因此解析失败时返回 nil，渲染器回退到纯文本。
- **端到端**（5 条）：由 `longCommandHandsOffThenNotifies`、`backgroundTaskUsesSelectedConversationWhenContextIsAbsent`、`outputFileIsReadableByReadFileWithAbsolutePath` 等用例锁定；改动整条链路时优先跑 `BackgroundTaskEndToEndTests`。三条易错约定：
  - **后台任务必须挂在发起它的会话上**：生产路径从 `ToolExecutionContext.conversationID` 取会话；无上下文的 `execute(arguments:)` 路径退回**当前选中的会话**。用随机 UUID 会让完成通知投递到一个不存在的会话——通知不丢，但模型永远收不到。
  - **输出路径必须是 read_file 能直接解析的绝对路径**：`WorkspacePathResolver` 对绝对路径直接返回，因此模型只需把通知里的路径原样传给 `read_file`。
  - **取消回合不杀后台任务，删除会话才杀**：前者是后台化的意义所在；后者见「后台任务」小节。
- **WorkspacePathResolver**（11 条）：由 `relativePathResolvesInsideWorkspaceWithoutTrailingSlash`、`writeFileToolWritesRelativePathInsideWorkspace`、`readFileToolDoesNotReadParentFileForRelativePath` 等用例锁定；改动路径解析或 read/write/edit 工具时优先跑 `WorkspacePathResolverTests`。工作区根必须按目录 URL 解析（`isDirectory: true`），相对路径不得落到项目父目录（**#140**）；绝对路径原样返回，nil/空白根回退到当前目录。注意 `URL(fileURLWithPath:)` 会 stat 已存在的目录从而掩盖该 bug，回归用例须用「磁盘上不存在的根」或父目录同名诱饵。

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
| 98 | 后台任务 | 进程退出后任务被标记为完成并发出恰好一次完成事件 | 交接一个短生命周期进程 | 等待进程退出 | 状态为 completed、退出码 0，完成事件恰好一次 | P0 | ✅ 已覆盖 | `taskFinishesExactlyOnceOnProcessExit` |
| 99 | 后台任务 | 非零退出码被记录为失败 | 交接一个非零退出的进程 | 等待进程退出 | 状态为 failed 且记录退出码 | P1 | ✅ 已覆盖 | `nonZeroExitCodeMarksTaskFailed` |
| 100 | 后台任务 | 输出被写入任务文件并可读取尾部 | 交接前先产生输出 | 交接后读输出文件 | 文件存在且包含交接前的输出 | P0 | ✅ 已覆盖 | `outputIsWrittenToTaskFile` |
| 101 | 后台任务 | 输出超过磁盘上限时保留尾部并标记截断 | 写入量超过上限 | 追加超出上限的内容 | 保留尾部、写入截断提示、文件大小受控 | P1 | ✅ 已覆盖 | `oversizedOutputKeepsTailAndMarksTruncation` |
| 102 | 后台任务 | 显式停止会终止进程并只发出一次完成事件 | 交接一个长命令 | 调用 stop | 进程被杀，状态 stopped，完成事件恰好一次 | P0 | ✅ 已覆盖 | `explicitStopTerminatesProcessAndEmitsOnce` |
| 103 | 后台任务 | 重复停止同一个任务不会重复发出完成事件 | 已停止的任务 | 再次调用 stop | 第二次返回 false，完成事件仍只有一次 | P1 | ✅ 已覆盖 | `repeatedStopIsIdempotent` |
| 104 | 后台任务 | 删除会话会停止该会话的全部后台任务 | 两个会话各有一个任务 | 停止某会话的任务 | 该会话进程被杀，另一会话不受影响 | P0 | ✅ 已覆盖 | `deletingConversationStopsItsBackgroundTasks` |
| 105 | 后台任务 | 重启后运行中的记录被标记为已中断 | 重新打开同一数据目录 | 读取任务记录 | 状态为 interrupted，不重挂孤儿进程 | P0 | ✅ 已覆盖 | `runningRecordsBecomeInterruptedAfterRestart` |
| 106 | 后台任务 | 输出路径位于 background-tasks 目录且以任务 ID 命名 | — | 读取输出路径 | 路径为 `<root>/background-tasks/<taskID>.log` | P1 | ✅ 已覆盖 | `outputPathLivesInCanonicalDirectory` |
| 107 | 非阻塞命令 | schema 声明了 run_in_background 与新的 timeout 语义 | — | 读取 inputSchema | 含 `run_in_background`，timeout 描述含「foreground budget」与 600 上限 | P0 | ✅ 已覆盖 | `schemaAdvertisesBackgroundArguments` |
| 108 | 非阻塞命令 | description 说明长命令不会阻塞回合 | — | 读取工具描述 | 提到 background 与 read_file | P1 | ✅ 已覆盖 | `descriptionMentionsNonBlockingBehaviour` |
| 109 | 非阻塞命令 | 以 sleep 开头的命令被识别为故意等待 | — | 调用 `isDeliberateWait` | `sleep 5`、`/bin/sleep 5`、`SLEEP 5` 均命中 | P0 | ✅ 已覆盖 | `sleepFirstCommandsAreDeliberateWaits` |
| 110 | 非阻塞命令 | 非 sleep 开头的命令不算故意等待 | — | 调用 `isDeliberateWait` | `swift build`、`echo sleep`、空串均不命中 | P1 | ✅ 已覆盖 | `otherCommandsAreNotDeliberateWaits` |
| 111 | 非阻塞命令 | sleep 命令不自动转后台：仍然等它跑完 | — | 执行 `sleep 1` | 返回执行结果而非后台提示 | P0 | ✅ 已覆盖 | `sleepCommandWaitsInForeground` |
| 112 | 非阻塞命令 | 后台结果文本含任务 ID、输出路径与 read_file 提示 | 已注入登记表 | 执行 `run_in_background=true` | 文本含三要素，且输出文件真实存在 | P0 | ✅ 已覆盖 | `backgroundResultTextContainsTaskIDPathAndHint` |
| 113 | 非阻塞命令 | 显式后台模式立即返回，不等命令跑完 | 已注入登记表 | 执行 `run_in_background=true` | 远早于命令结束就返回后台提示 | P0 | ✅ 已覆盖 | `explicitBackgroundReturnsImmediately` |
| 114 | 非阻塞命令 | 预算耗尽时命令转入后台且进程继续运行 | 已注入登记表、预算 1s | 执行长命令 | 预算内返回后台提示，任务状态为 running | P0 | ✅ 已覆盖 | `budgetExpiryHandsOffToBackground` |
| 115 | 非阻塞命令 | 没有登记表时后台化显式失败而不是谎称成功 | 未注入登记表 | 执行 `run_in_background=true` | 抛 `ToolExecutionError` | P0 | ✅ 已覆盖 | `backgroundWithoutRegistryThrows` |
| 116 | 非阻塞命令 | 超时上限被钳制到 600 秒 | — | 读取常量 | 上限为 600 秒 | P1 | ✅ 已覆盖 | `timeoutIsClampedToCeiling` |
| 117 | 非阻塞命令 | 短命令行为不变：返回执行结果而不是后台提示 | — | 执行 `echo hello` | 返回输出，不含后台提示 | P0 | ✅ 已覆盖 | `shortCommandStillReturnsResult` |
| 118 | 完成通知 | 空闲时插入 user 消息唤醒模型 | 会话空闲 | 投递完成事件 | 插入一条 `role == .user` 消息，含任务 ID 与输出路径 | P0 | ✅ 已覆盖 | `idleConversationGetsUserMessage` |
| 119 | 完成通知 | 通知消息带 metadata 供渲染器识别 | 会话空闲 | 投递完成事件 | metadata 含任务 ID、状态、退出码、输出路径 | P1 | ✅ 已覆盖 | `notificationCarriesRendererMetadata` |
| 120 | 完成通知 | 同一任务的完成事件只投递一次 | 会话空闲 | 重复投递同一任务三次 | 只插入一条消息 | P0 | ✅ 已覆盖 | `duplicateCompletionEventsDeliverOnlyOnce` |
| 121 | 完成通知 | 会话正忙时通知入队而不是直接插入 | 会话运行中 | 投递完成事件 | 不插入消息，队列长度为 1 | P0 | ✅ 已覆盖 | `busyConversationQueuesNotification` |
| 122 | 完成通知 | 回合结束后排队的通知被排空 | 会话运行中后转空闲 | 触发 turnFinished | 排空后插入一条消息，队列归零 | P0 | ✅ 已覆盖 | `turnFinishedDrainsQueuedNotification` |
| 123 | 完成通知 | 忙时两个任务完成都会被送达 | 会话运行中 | 投递两个完成事件后转空闲 | 两条消息都被送达 | P1 | ✅ 已覆盖 | `twoCompletionsWhileBusyBothDelivered` |
| 124 | 完成通知 | 自动回复被抑制时通知被暂存而不是丢弃 | 抑制开启 | 投递完成事件 | 不插入消息，暂存长度为 1 | P0 | ✅ 已覆盖 | `suppressedConversationHoldsNotification` |
| 125 | 完成通知 | 抑制解除后暂存的通知被投递 | 抑制开启后关闭 | 触发 turnFinished | 插入一条消息 | P0 | ✅ 已覆盖 | `suppressedNotificationDeliveredAfterSuppressionEnds` |
| 126 | 完成通知 | 失败任务的通知写明退出码 | — | 构造通知消息 | 含任务 ID、failed、退出码与摘录 | P1 | ✅ 已覆盖 | `failedNotificationIncludesExitCode` |
| 127 | 卡片与停止 | 工具名与 schema 声明 task_id | — | 读取工具定义 | 名称为 `stop_background_task`，必填 `task_id` | P1 | ✅ 已覆盖 | `toolDeclaresTaskIDArgument` |
| 128 | 卡片与停止 | 缺少 task_id 时抛错而不是返回字符串 | — | 不带参数执行 | 抛 `ToolExecutionError` | P0 | ✅ 已覆盖 | `missingTaskIDThrows` |
| 129 | 卡片与停止 | 没有登记表时抛错 | 未注入登记表 | 执行停止 | 抛 `ToolExecutionError` | P0 | ✅ 已覆盖 | `missingRegistryThrows` |
| 130 | 卡片与停止 | 未知任务 ID 时抛错 | 已注入登记表 | 停止不存在的任务 | 抛 `ToolExecutionError` | P0 | ✅ 已覆盖 | `unknownTaskIDThrows` |
| 131 | 卡片与停止 | 停止运行中的任务会终止进程 | 已交接长命令 | 调用停止工具 | 进程被杀，任务状态为 stopped | P0 | ✅ 已覆盖 | `stopsRunningTask` |
| 132 | 卡片与停止 | 停止已结束的任务返回真实状态而不是报错 | 任务已自然结束 | 调用停止工具 | 返回「already」而非抛错 | P1 | ✅ 已覆盖 | `stoppingFinishedTaskReportsStatus` |
| 133 | 卡片与停止 | 通知消息被卡片渲染器接管 | — | 判定消息 | 通知消息被接管 | P0 | ✅ 已覆盖 | `notificationMessageIsRenderedByCard` |
| 134 | 卡片与停止 | 普通消息不被卡片渲染器接管 | — | 判定消息 | 普通 user 消息不被接管 | P1 | ✅ 已覆盖 | `ordinaryMessageIsNotRenderedByCard` |
| 135 | 卡片与停止 | 载荷解析出任务 ID、状态、退出码与输出路径 | — | 解析 metadata | 四项载荷均正确 | P1 | ✅ 已覆盖 | `payloadDecodesFromMetadata` |
| 136 | 卡片与停止 | 载荷缺失时返回 nil 以便回退到纯文本 | — | 解析空 metadata | 返回 nil | P0 | ✅ 已覆盖 | `missingPayloadDecodesToNil` |
| 137 | 卡片与停止 | 未知状态值不会导致崩溃 | — | 解析非法状态 | 返回 nil | P0 | ✅ 已覆盖 | `unknownStatusDecodesToNil` |
| 138 | 端到端 | 长命令在预算内返回、进程继续运行、完成后通知唤醒模型 | 已注入登记表 | 执行长命令并停止 | 预算内返回后台提示，输出可读，通知回到来源会话 | P0 | ✅ 已覆盖 | `longCommandHandsOffThenNotifies` |
| 139 | 端到端 | 取消回合不会杀掉后台任务 | 已交接长命令 | 取消回合 | 任务状态仍是 running | P0 | ✅ 已覆盖 | `cancellingTurnKeepsBackgroundTaskAlive` |
| 140 | 端到端 | 短命令不进入后台，行为与之前一致 | 已注入登记表 | 执行 `echo quick` | 返回输出，不进后台，登记表为空 | P0 | ✅ 已覆盖 | `shortCommandNeverEntersBackground` |
| 141 | 端到端 | 无上下文时后台任务归属当前选中的会话 | 已注入登记表与当前会话 | 执行长命令 | 任务挂在当前选中的会话上 | P0 | ✅ 已覆盖 | `backgroundTaskUsesSelectedConversationWhenContextIsAbsent` |
| 142 | 端到端 | 输出文件能被 read_file 用绝对路径读到 | 已注入登记表 | 执行长命令后用 read_file 读输出 | 读到命令的输出内容 | P0 | ✅ 已覆盖 | `outputFileIsReadableByReadFileWithAbsolutePath` |
| 143 | ToolExecutionScheduling | 混合批次：前序读并行，副作用屏障等齐前序读，后续读在屏障后并行且不超上限（#1312） | 同一回合提交 2 读 + 1 写 + 5 读的混合批次 | 提交批次并等待全部 Job 结束 | 前序读重叠执行，屏障等齐两个前序读结束才启动，后 5 个读真实并行且峰值并发为 4 | P0 | ✅ 已覆盖 | `mixedBatchKeepsReadsOverlappingAndBarrierOrdered` |
| 144 | ToolExecutionScheduling | 取消一个并行读不影响同批其他读（#1312） | 三个并行读同时在跑 | 取消其中一个 | 被取消 Job 为 cancelled 终态，另两个正常完成，峰值并发保持 3 | P0 | ✅ 已覆盖 | `cancellingOneParallelReadDoesNotCancelSiblings` |
| 145 | ToolExecutionScheduling | 取消屏障后排队的读：立即终态，屏障照常完成（#1312） | 读被更早的副作用屏障挡住仍在排队 | 取消该排队读 | 读立即进入 cancelled 且从未执行，屏障正常完成 | P0 | ✅ 已覆盖 | `cancellingQueuedReadBehindBarrierFinishesImmediately` |
| 146 | ToolExecutionScheduling | 整回合取消：每个调用都拿到终态结果，不留无结果孤儿（#1312） | 读写混合批次正在运行 | 取消该回合的全部 Job | 每个 Job 都能等到非 nil 结果且状态为 cancelled | P0 | ✅ 已覆盖 | `turnCancellationSettlesEveryJobWithAResult` |
| 147 | 后台任务 | 进程内任务完成后发出恰好一次完成事件，输出落盘可读尾部（#1313） | 登记一个进程内任务并写入结论 | finishInProcess(exitCode: 0) | 状态 completed、完成事件恰好一次、输出文件与尾部可读 | P0 | ✅ 已覆盖 | `inProcessTaskFinishesExactlyOnce` |
| 148 | 后台任务 | 进程内任务被停止后，迟到的完成写入不再发第二次事件（#1313） | 进程内任务运行中 | stop 之后再 finishInProcess | 完成事件仍只有一次且状态保持 stopped | P0 | ✅ 已覆盖 | `inProcessStopThenLateFinishEmitsOnce` |
| 149 | 后台任务 | 进程内任务失败以非零退出码记录（#1313） | 进程内任务写入失败文案 | finishInProcess(exitCode: 1) | 状态 failed、退出码 1、完成事件恰好一次 | P1 | ✅ 已覆盖 | `inProcessFailureRecordsNonZeroExitCode` |
| 150 | WorkspacePathResolver | 无尾斜杠且磁盘不存在的工作区根下，相对路径必须落在项目内（**#140**） | — | resolve("note.txt", "/tmp/project") | /tmp/project/note.txt | P0 | ✅ 已覆盖 | `relativePathResolvesInsideWorkspaceWithoutTrailingSlash` |
| 151 | WorkspacePathResolver | 带尾斜杠的工作区根同样落在项目内 | — | resolve("note.txt", "/tmp/project/") | /tmp/project/note.txt | P1 | ✅ 已覆盖 | `relativePathResolvesInsideWorkspaceWithTrailingSlash` |
| 152 | WorkspacePathResolver | 嵌套相对路径落在项目内 | — | resolve("a/b.txt", "/tmp/project") | /tmp/project/a/b.txt | P1 | ✅ 已覆盖 | `nestedRelativePathResolvesInsideWorkspace` |
| 153 | WorkspacePathResolver | 绝对路径原样返回，不受工作区根影响 | — | resolve("/etc/hosts", "/tmp/project") | /etc/hosts | P1 | ✅ 已覆盖 | `absolutePathIsReturnedUnchanged` |
| 154 | WorkspacePathResolver | 工作区根为 nil 时回退到当前目录相对解析 | — | resolve("note.txt", nil) | 等于 cwd 相对标准化路径 | P2 | ✅ 已覆盖 | `nilWorkspaceRootResolvesRelativeToCurrentDirectory` |
| 155 | WorkspacePathResolver | 工作区根为空白时回退到当前目录相对解析 | — | resolve("note.txt", "   ") | 等于 cwd 相对标准化路径 | P2 | ✅ 已覆盖 | `blankWorkspaceRootResolvesRelativeToCurrentDirectory` |
| 156 | WorkspacePathResolver | ~ 路径展开到用户主目录 | — | resolve("~/note.txt", "/tmp/project") | NSHomeDirectory()/note.txt | P2 | ✅ 已覆盖 | `tildePathIsExpandedToHomeDirectory` |
| 157 | WorkspacePathResolver | 父级 traversal 相对工作区标准化 | — | resolve("../sibling.txt", "/tmp/project") | /tmp/sibling.txt | P2 | ✅ 已覆盖 | `parentTraversalIsStandardizedAgainstWorkspace` |
| 158 | WorkspacePathResolver | write_file 相对路径写入项目内而非父目录（**#140**） | 临时容器，项目根不预创建 | 注入根 provider 后 write_file("note.txt") | project/note.txt 存在且内容正确，父目录无该文件 | P0 | ✅ 已覆盖 | `writeFileToolWritesRelativePathInsideWorkspace` |
| 159 | WorkspacePathResolver | read_file 相对路径不得读取父目录同名诱饵（**#140**） | 项目根不存在，父目录 note.txt=outside | 注入根 provider 后 read_file("note.txt") | 不返回 outside（指向项目内不存在文件而抛错） | P0 | ✅ 已覆盖 | `readFileToolDoesNotReadParentFileForRelativePath` |
| 160 | WorkspacePathResolver | edit_file 相对路径不得修改父目录同名诱饵（**#140**） | 项目根不存在，父目录 note.txt=outside | 注入根 provider 后 edit_file old→new | 父目录诱饵原样未动 | P0 | ✅ 已覆盖 | `editFileToolDoesNotModifyParentFileForRelativePath` |

> 说明：全部 **160 条场景**已在本包 `swift test` 中实跑通过。
> 用例名与描述取自 `Tests/` 下的真实 `@Test` 声明，改动测试时须同步本表。

## 覆盖率统计

- P0: 已覆盖 47 / 47
- P1: 已覆盖 103 / 103
- P2: 已覆盖 10 / 10
- **合计: 160 / 160**（仅表示清单场景，非源码覆盖率）

## 优先级说明

- **P0**: 描述/名称含崩溃、泄漏、截断、丢失、竞态、超时、必须、不得、重试等失效类信号的用例（47 条）
- **P1**: 其余功能性用例（103 条）
- **P2**: 稳定常量、占位、文案、空集合等边界用例（10 条）

## 跨平台说明

- Package 声明: macOS 14+, iOS 17+
- 160 条用例位于 `Tests/`，需在目标平台执行 `swift test`

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
