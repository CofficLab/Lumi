# TestPlan — PluginGoalTask

## 包概述

GoalTaskPlugin 目标导向的任务管理插件，为 Lumi 提供 Goal（目标）+ Task（任务）两层结构的任务追踪能力。

平台: macOS 14+, iOS 17+
测试文件: 18 个，用例总数: 190

核心组件（源码目录）:
- `Capabilities/`
- `Hooks/`
- `Models/`
- `Observers/`
- `Services/`
- `Tools/`
- `ViewModels/`
- `Views/`

## 公开 API

包内主要类型（按声明顺序抽取，供定位被测对象）:

- `GoalTaskPlugin`
- `GoalTaskPluginSupport`
- `GoalTaskTimeline`
- `GoalForkCapability`
- `GoalPromptInjectionHook`
- `GoalTaskTurnFinishedHook`
- `Goal`
- `GoalDisplayItem`
- `GoalListItem`
- `GoalTaskDisplayItem`
- `GoalTask`
- `GoalChangeCenter`
- `GoalTaskConversationBridge`
- `GoalForkCoordinator`

## 关键行为契约（实现约定，非协议要求）

按测试模块归纳，改动对应模块时须保持既有断言成立:

- **GoalDisplayAndVM**（19 条）：由 `testMappingPreservesFields`、`testIsTerminal`、`testStatusSystemImage` 等用例锁定；改动该模块时优先跑对应测试文件。
- **GoalForkAttachmentIsolation**（1 条）：由 `testForkCommitDoesNotConsumePendingAttachments` 锁定；分叉提交必须走显式附件重载，改动该调用点时优先跑对应测试文件。
- **GoalForkCoordinator**（16 条）：由 `testForkAndStartHappyPath`、`testResumePromptContent`、`testResumePromptListsOnlyOutstandingTasks`、`testResumePromptUsesForkedTaskIDs` 等用例锁定；分叉首轮是「继续推进目标」的自动回合，必须继承源对话的自动化等级（源无工具时至少升到 Build），且先捕获源等级再建对话、把等级应用到新对话并早于启动回合，绝不退化成无工具回合（**回归** #772），改动该模块时优先跑对应测试文件。
- **GoalForkAutomationInheritance**（3 条）：由 `testSourceLevelReadsSelectedConversationNotGlobal`、`testApplyLevelTargetsForkedConversation`、`testSourceLevelFallsBackToGlobalWhenNoSelection` 锁定；`sourceAutomationLevel` 必须读选中源对话而非全局 New Chat 默认，`applyAutomationLevel` 必须写到分叉出的目标对话，未选中源对话时才回落全局（**回归** #772），改动 `GoalForkCapabilityAdapter` 的等级读写时优先跑对应测试文件。
- **GoalHooks**（30 条）：由 `testNoManagerReturnsContextUnchanged`、`testNoActiveGoalsInjectsNothing`、`testBlockedGoalInjectsOnlyStopPrompt` 等用例锁定；改动该模块时优先跑对应测试文件。
- **GoalStateManagerAppendFork**（19 条）：由 `testAddTasksContinuesOrder`、`testAddTasksThrowsWhenGoalAlreadyFull`、`testAddTasksWritesPartialBatch` 等用例锁定；改动该模块时优先跑对应测试文件。
- **GoalTaskMigration**（3 条）：由 `v5MigrationLandsDatabaseAtReadPath`、`promotesMisplacedStoreOnlyWhenReadPathIsEmpty` 锁定；升级迁移必须把 v5 数据库放到 `GoalStateManager` 实际读取的位置，改动迁移或数据库路径时优先跑对应测试文件。
- **GoalStateManager**（16 条）：由 `testCreateGoal`、`testUpdateTaskStatusDerivesGoalStatus`、`testUpdateGoalStatusBlocked` 等用例锁定；全部任务终态且含失败时 Goal 必须推导为 failed，不得停留在 inProgress/pending（**回归** #188），改动该模块时优先跑对应测试文件。
- **GoalTaskTimeline**（2 条）：由 `continuationMessage`、`limitReachedMessage` 等用例锁定；改动该模块时优先跑对应测试文件。
- **GoalToolbarButtonVisibility**（5 条）：由 `testHiddenWithoutGoals`、`testHiddenForSingleActiveGoal`、`testShownForMultipleGoals` 等用例锁定；改动该模块时优先跑对应测试文件。
- **GoalTaskTools**（20 条）：由 `addTasksAppendsAndReports`、`addTasksResolvesOmittedGoalId`、`addTasksFiltersEntriesWithoutTitle` 等用例锁定；改动该模块时优先跑对应测试文件。
- **GoalTaskV2**（13 条）：由 `preservesPluginIdentityAndPolicy`、`preservesLegacyToolNamesAndRequiredArguments`、`createGoalUsesExecutionConversation`、`testPreciseGoalIdCannotCrossConversations`、`testUpdateTaskStatusCannotCrossConversations` 等用例锁定；带会话上下文时精确 goal_id 必须属于本会话（**回归** #189），update_task_status 必须校验任务归属会话、禁止跨会话改写（**回归** #190），改动该模块时优先跑对应测试文件。
- **TaskListSurface**（4 条）：由 `bottomEdgeHasVisibleShadow`、`topAndBottomShadowAreSymmetric`、`bottomBandMirrorsTopBand` 等用例锁定；改动该模块时优先跑对应测试文件。
- **GoalViewRender**（8 条）：由 `taskRowHeightIsThirtyPoints`、`taskRowUsesOrangeSurface`、`longTitleIsTruncatedAtRowEdge` 等用例锁定；改动该模块时优先跑对应测试文件。
- **GoalTopShadow**（5 条）：由 `topShadowRendersAbovePanelEdge`、`topShadowFadesMonotonically`、`topShadowHasSolidContactLine`、`topShadowPeakIsAtPanelEdge`、`noShadowWithoutActiveGoal` 锁定；改动该模块时优先跑对应测试文件。
- **GoalTaskConversationCleanup**（2 条）：由 `deletingConversationRemovesOnlyItsGoals`、`deletingMultipleConversationsRemovesEachGoalSet` 锁定；会话删除必须同步清理该会话的 Goals（**回归** #771），改动删除观察者时优先跑对应测试文件。
- **GoalTaskOrphanCleanup**（5 条）：由 `testCreateGoalLinksTasksForCascade`、`testDeleteAllGoalsRemovesCreatedTasks`、`testDeleteAllGoalsRemovesAppendedTasks`、`testDeleteAllGoalsRemovesForkedTasks`、`testDeleteAllGoalsRemovesUnlinkedLegacyOrphan` 锁定；创建/追加/fork 的 Task 必须建立 `task.goal` 对象关系（字符串 `goalId` 不会自动填充关系），`deleteAllGoals` 必须连带删除全部 Task 并显式按 `goalId` 清掉未链接的历史孤儿，不得只依赖 `.cascade` 而残留永久孤儿（**回归** #815）。改动 `GoalStateManager` 的创建/删除路径或 `Goal`/`GoalTask` 关系时优先跑对应测试文件。

## 测试用例清单

| ID | 类别 | 描述 | 前置条件 | 操作步骤 | 预期结果 | 优先级 | 状态 | 测试方法 |
|----|------|------|----------|----------|----------|------|------|----------|
| 1 | GoalDisplayAndVM | 映射保留身份与状态字段 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testMappingPreservesFields` |
| 2 | GoalDisplayAndVM | 终态判定只认 completed / failed / skipped | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testIsTerminal` |
| 3 | GoalDisplayAndVM | 每种状态都有唯一图标，不出现空串 | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `testStatusSystemImage` |
| 4 | GoalDisplayAndVM | 状态颜色随状态变化 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testStatusColorVariesByStatus` |
| 5 | GoalDisplayAndVM | 映射保留任务身份、分组与状态 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testMappingPreservesFields` |
| 6 | GoalDisplayAndVM | 每种任务状态都有唯一图标 | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `testStatusSystemImage` |
| 7 | GoalDisplayAndVM | 颜色随状态变化，skipped 与 Goal 的灰色不同以示区分 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testStatusColor` |
| 8 | GoalDisplayAndVM | 无当前会话时 refresh 清空列表 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testRefreshWithoutConversationClearsGoals` |
| 9 | GoalDisplayAndVM | 当前会话切换到相同 ID 时跳过更新 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testUpdateCurrentConversationIDSkipsIdenticalValue` |
| 10 | GoalDisplayAndVM | manager 不可用时 refresh 静默跳过，不清空已有数据 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testRefreshSkipsWhenManagerUnavailable` |
| 11 | GoalDisplayAndVM | refresh 拉取目标会话的 Goal 与任务 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testRefreshLoadsGoalsAndTasks` |
| 12 | GoalDisplayAndVM | 空会话的派生态不报错，进度为空串 | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `testDerivedStateForEmptyConversation` |
| 13 | GoalDisplayAndVM | 进度文本把已完成与已跳过都计入分子 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testProgressTextCountsCompletedAndSkipped` |
| 14 | GoalDisplayAndVM | Goal 终态但仍有进行中任务时侧栏仍可见 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testHasActiveWorkForTerminalGoalWithRunningTask` |
| 15 | GoalDisplayAndVM | Goal 终态且所有任务已结束时不显示侧栏 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `testHasActiveWorkHiddenWhenEverythingDone` |
| 16 | GoalDisplayAndVM | refreshIfCurrentConversation 只在会话匹配时刷新 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testRefreshIfCurrentConversationGuardsOnID` |
| 17 | GoalDisplayAndVM | 订阅者收到 notify 推送的会话 ID | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testObserverReceivesNotification` |
| 18 | GoalDisplayAndVM | cancel 后不再收到通知 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testCancelStopsNotifications` |
| 19 | GoalDisplayAndVM | 多个订阅者互不影响 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testMultipleObservers` |
| 20 | GoalForkCoordinator | fork 后建会话、复制 Goal、发消息并启动回合 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testForkAndStartHappyPath` |
| 21 | GoalForkCoordinator | 开场指令陈述目标与描述、成功标准，不下继续执行指令 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testResumePromptContent` |
| 22 | GoalForkCoordinator | 只列出未完成任务，已完成的不出现在开场指令中 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testResumePromptListsOnlyOutstandingTasks` |
| 23 | GoalForkCoordinator | 全部任务已结束时开场指令不含未完成区块 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testResumePromptWithoutOutstandingTasks` |
| 24 | GoalForkCoordinator | fork 副本的描述与成功标准为空时对应区块被省略 | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `testResumePromptOmitsEmptyDescriptionAndCriteria` |
| 25 | GoalForkCoordinator | fork 副本的描述为空串时同样省略该区块 | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `testResumePromptOmitsEmptyStringDescription` |
| 26 | GoalForkCoordinator | 建对话失败时向上抛出且不执行后续步骤 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testCreateConversationFailurePropagates` |
| 27 | GoalForkCoordinator | 复制 Goal 失败时回收刚建的空会话，不留孤儿对话 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testForkFailureDiscardsConversation` |
| 28 | GoalForkCoordinator | 提交消息返回 nil 时抛 emptyPrompt 并回收会话 | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `testEmptyCommitThrowsAndDiscards` |
| 29 | GoalForkCoordinator | 提交消息抛错时同样回收会话 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testCommitFailureDiscards` |
| 30 | GoalForkCoordinator | 每个 case 都有面向用户的文案 | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `testErrorDescriptions` |
| 31 | GoalHooks | manager 未就绪时原样返回，不注入任何消息 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testNoManagerReturnsContextUnchanged` |
| 32 | GoalHooks | 无活跃 Goal 时不注入，不产生 token 开销 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testNoActiveGoalsInjectsNothing` |
| 33 | GoalHooks | 只有 blocked Goal 时只注入等待指令，不叠加自主执行契约 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testBlockedGoalInjectsOnlyStopPrompt` |
| 34 | GoalHooks | blocked Goal 没有阻塞原因时不输出 Reason 行 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testBlockedGoalWithoutReason` |
| 35 | GoalHooks | 活跃 Goal 注入契约与进度，静态契约排在动态进度之前 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testActiveGoalInjectsContractBeforeProgress` |
| 36 | GoalHooks | 无 in_progress 任务且待办同组时提示可并行执行 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testPromptSuggestsParallelGroupWhenNoFocusTask` |
| 37 | GoalHooks | 失败任务计入进度行的失败数 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testFailedTasksCountedInProgress` |
| 38 | GoalHooks | 首个任务完成后提示下一个待办为 next task | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testPromptSuggestsNextTaskWhenNoneInProgress` |
| 39 | GoalHooks | 所有任务结束时提示验收并关闭 Goal | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testPromptWhenAllTasksFinished` |
| 40 | GoalHooks | 多个活跃 Goal 各自注入一段进度 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testMultipleActiveGoalsInjectSeparateProgress` |
| 41 | GoalHooks | 待办超过 10 个时截断并提示用 get_goal_progress 取全量 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `testPendingTasksTruncatedBeyondTen` |
| 42 | GoalHooks | 消费到续跑标记时追加开场指令，且只生效一次 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testContinuationPromptConsumedOnce` |
| 43 | GoalHooks | 没有续跑标记时不追加开场指令 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testNoContinuationPromptWithoutMarker` |
| 44 | GoalHooks | 非 completed / suspended 的结束原因不触发任何动作 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testIgnoredEndReasons` |
| 45 | GoalHooks | 有活跃 Goal 且存在未完成任务时发起续跑并置位标记 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testContinuesWhenActiveGoalHasPendingTasks` |
| 46 | GoalHooks | 续跑次数耗尽后停止并把未完成 Goal 标记为失败 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testLimitReachedFailsGoals` |
| 47 | GoalHooks | 活跃 Goal 的任务已全部结束时不续跑 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testNoContinuationWhenNoOpenTasks` |
| 48 | GoalHooks | 全部 Goal 到达终态后清理并通知，不再续跑 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testCleansUpWhenAllGoalsTerminal` |
| 49 | GoalHooks | blocked Goal 不触发续跑（与注入钩子的活跃判定保持一致） | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testBlockedGoalDoesNotContinue` |
| 50 | GoalHooks | suspended 回合在活跃 Goal 时代答 ask_user 并恢复 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testSuspendedAutoAnswersAskUser` |
| 51 | GoalHooks | 非 ask_user 的挂起点不被代答 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testNonAskUserSuspensionIgnored` |
| 52 | GoalHooks | question 为空的 ask_user 不代答（参数校验失败不构成真正提问） | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `testEmptyQuestionNotAnswered` |
| 53 | GoalHooks | ask_user 代答预算耗尽后交回用户 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testAskUserBudgetExhausted` |
| 54 | GoalHooks | 无活跃 Goal 时挂起回合不被代答 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testNoActiveGoalNoAutoAnswer` |
| 55 | GoalStateManagerAppendFork | 追加任务时 order 从现有最大值续接，且不改动已有任务状态 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testAddTasksContinuesOrder` |
| 56 | GoalStateManagerAppendFork | 追加任务时 Goal 已满则抛 tooManyTasks，不静默丢弃 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testAddTasksThrowsWhenGoalAlreadyFull` |
| 57 | GoalStateManagerAppendFork | 追加任务在只剩部分容量时只写入能放下的部分 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testAddTasksWritesPartialBatch` |
| 58 | GoalStateManagerAppendFork | 向不存在的 Goal 追加任务抛 goalNotFound | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testAddTasksToMissingGoalThrows` |
| 59 | GoalStateManagerAppendFork | 单会话 Goal 数量达到上限后拒绝继续创建 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `testCreateGoalRejectsWhenConversationFull` |
| 60 | GoalStateManagerAppendFork | fork 复制 Goal 与任务，并把源 Goal 标记为 skipped | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testForkCopiesGoalAndTasks` |
| 61 | GoalStateManagerAppendFork | fork 终态 Goal 时副本重置为 pending，不继承完成时间 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testForkResetsTerminalStatusToPending` |
| 62 | GoalStateManagerAppendFork | 目标会话已有活跃 Goal 时拒绝 fork | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `testForkRejectsWhenTargetHasActiveGoal` |
| 63 | GoalStateManagerAppendFork | 目标会话只有终态 Goal 时允许 fork | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testForkAllowedWhenTargetOnlyHasTerminalGoals` |
| 64 | GoalStateManagerAppendFork | fork 不存在的 Goal 抛 goalNotFound | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testForkMissingGoalThrows` |
| 65 | GoalStateManagerAppendFork | GoalStateError 每个 case 都有面向用户的文案 | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `testGoalStateErrorDescriptions` |
| 66 | GoalStateManagerAppendFork | 更新不存在的任务抛 taskNotFound | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testUpdateMissingTaskThrows` |
| 67 | GoalStateManagerAppendFork | 任务标记 failed 时记录 errorMessage，Goal 不被自动覆盖 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testUpdateTaskFailureRecordsErrorAndKeepsGoalStatus` |
| 68 | GoalStateManagerAppendFork | 全部任务失败时 Goal 推导为 failed | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testGoalDerivesFailedWhenAllTasksFail` |
| 69 | GoalStateManagerAppendFork | LLM 手动标记 blocked 后任务推进不再自动改写 Goal 状态 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testManualBlockedStatusIsNotOverwritten` |
| 70 | GoalStateManagerAppendFork | 手动标记 failed 的 Goal 同样不被任务推进覆盖 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testManualFailedStatusIsNotOverwritten` |
| 71 | GoalStateManagerAppendFork | 完成百分比按已完成 + 已跳过计算 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testCompletionPercent` |
| 72 | GoalStateManagerAppendFork | 总任务为 0 时完成百分比为 0 且不算全部完成 | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `testEmptySummary` |
| 73 | GoalStateManagerAppendFork | 没有 pending / in_progress 任务即视为全部结束 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testIsAllDone` |
| 74 | GoalStateManager | Create goal with tasks | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testCreateGoal` |
| 75 | GoalStateManager | Update task status auto-derives goal status | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testUpdateTaskStatusDerivesGoalStatus` |
| 76 | GoalStateManager | Update goal status to blocked | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testUpdateGoalStatusBlocked` |
| 77 | GoalStateManager | Marking an incomplete goal as failed preserves the goal and tasks | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testFailedGoalPreservesTasks` |
| 78 | GoalStateManager | Task progress resets the automatic continuation budget | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testContinuationBudgetReset` |
| 79 | GoalStateManager | Continuation marker is consumed exactly once | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testContinuationMarkerConsumedOnce` |
| 80 | GoalStateManager | Ask user answer budget is independent and exhausts | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testAskUserAnswerBudget` |
| 81 | GoalStateManager | Task progress resets both continuation and ask user budgets | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testResetClearsBothBudgets` |
| 82 | GoalStateManager | Deleting goals clears the conversation runtime budget | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testDeleteGoalsClearsBudget` |
| 83 | GoalStateManager | Fetch goals by conversation | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testFetchGoals` |
| 84 | GoalStateManager | Create then immediately fetch returns the goal | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testCreateThenFetchImmediately` |
| 85 | GoalStateManager | Sidebar hides when all goals reach terminal state | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testSidebarHidesWhenAllDone` |
| 86 | GoalStateManager | Sidebar visible when work is in progress | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testSidebarVisibleWhenInProgress` |
| 87 | GoalTaskTimeline | continuation message is a timeline event with progress metadata | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `continuationMessage` |
| 88 | GoalTaskTimeline | limit message explains why automatic continuation stopped | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `limitReachedMessage` |
| 89 | GoalTaskTools | add_tasks_to_goal 追加任务并回显 Goal ID 与任务列表 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `addTasksAppendsAndReports` |
| 90 | GoalTaskTools | add_tasks_to_goal 可省略 goal_id 自动解析唯一活跃 Goal | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `addTasksResolvesOmittedGoalId` |
| 91 | GoalTaskTools | add_tasks_to_goal 过滤缺少标题的任务 | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `addTasksFiltersEntriesWithoutTitle` |
| 92 | GoalTaskTools | add_tasks_to_goal 目标不存在时返回可恢复错误 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `addTasksReportsUnknownGoal` |
| 93 | GoalTaskTools | add_tasks_to_goal 在 Goal 已满时报告失败而不是假装成功 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `addTasksReportsFullGoal` |
| 94 | GoalTaskTools | add_tasks_to_goal 在 manager 未就绪时给出明确提示 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `addTasksWithoutManager` |
| 95 | GoalTaskTools | update_task_status 更新任务并回显 Goal 新状态 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `updateTaskStatusReportsGoalState` |
| 96 | GoalTaskTools | update_task_status 拒绝非法状态值 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `updateTaskStatusRejectsInvalidStatus` |
| 97 | GoalTaskTools | update_task_status 任务推进后重置续跑预算 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `updateTaskStatusResetsContinuationBudget` |
| 98 | GoalTaskTools | update_task_status 任务不存在时返回失败文案 | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `updateTaskStatusReportsMissingTask` |
| 99 | GoalTaskTools | get_goal_progress 汇总各状态计数与百分比 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `getProgressSummarizesStatuses` |
| 100 | GoalTaskTools | get_goal_progress 在 manager 未就绪时给出明确提示 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `getProgressWithoutManager` |
| 101 | GoalTaskTools | update_goal_status 支持 blocked 并记录原因 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `updateGoalStatusBlocked` |
| 102 | GoalTaskTools | update_goal_status 拒绝非法状态值 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `updateGoalStatusRejectsInvalidStatus` |
| 103 | GoalTaskTools | string 去掉首尾空白；纯空白串归一为空串而非 nil | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testStringTrimming` |
| 104 | GoalTaskTools | taskInputs 丢弃缺少标题或标题为空的项 | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `testTaskInputsFiltering` |
| 105 | GoalTaskTools | taskInputs 对 nil 与非字典数组返回空 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testTaskInputsNonArray` |
| 106 | GoalTaskTools | taskSchema 默认不带 maxItems，显式传入时附加上限 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testTaskSchema` |
| 107 | GoalTaskTools | normalize 忽略大小写与首尾空白 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testNormalize` |
| 108 | GoalTaskTools | goalListText 输出每行的 id、标题与状态 | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `testGoalListText` |
| 109 | GoalTaskV2 | preservesPluginIdentityAndPolicy | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `preservesPluginIdentityAndPolicy` |
| 110 | GoalTaskV2 | preservesLegacyToolNamesAndRequiredArguments | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `preservesLegacyToolNamesAndRequiredArguments` |
| 111 | GoalTaskV2 | create_goal 使用 Agent 回合会话而非 UI 当前选中会话 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `createGoalUsesExecutionConversation` |
| 112 | GoalTaskV2 | Goal 会话 Bridge 收到切换后的新会话 ID | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `goalConversationBridgeUsesUpdatedSelection` |
| 113 | GoalTaskV2 | create_goal 没有执行上下文时拒绝写入 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `createGoalRejectsContextlessExecution` |
| 114 | GoalTaskV2 | create_goal 返回 Goal ID，后续工具可用它 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `createGoalExposesGoalId` |
| 115 | GoalTaskV2 | update_goal_status 可以用标题解析 goal_id（id 丢失时的恢复路径） | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `goalIdResolvesByTitle` |
| 116 | GoalTaskV2 | 省略 goal_id 时自动解析会话内唯一活跃 goal | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `omittedGoalIdResolvesActiveGoal` |
| 117 | GoalTaskV2 | goal not found 错误附本会话候选列表（可恢复） | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `unknownGoalIdListsCandidates` |
| 118 | TaskListSurface | 容器底边存在可见阴影带 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `bottomEdgeHasVisibleShadow` |
| 119 | TaskListSurface | 顶边与底边阴影强度对称 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `topAndBottomShadowAreSymmetric` |
| 120 | TaskListSurface | 底边阴影带与顶边逐行镜像 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `bottomBandMirrorsTopBand` |
| 121 | TaskListSurface | 顶边阴影强度保持不变 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `topEdgeShadowStaysStrong` |
| 122 | GoalViewRender | 任务行高度为 30pt | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `taskRowHeightIsThirtyPoints` |
| 123 | GoalViewRender | 任务行底色与描边为橙色系 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `taskRowUsesOrangeSurface` |
| 124 | GoalViewRender | 任务行状态图标从 8pt 内边距处开始 | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `taskRowIconStartsAtEightPointInset` |
| 125 | GoalViewRender | 长标题被截断到行右边缘 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `longTitleIsTruncatedAtRowEdge` |
| 126 | GoalViewRender | 阻塞原因卡片高度为 40pt | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `blockedReasonCardHeightIsFortyPoints` |
| 127 | GoalViewRender | 容器高度按行数计算 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `containerHeightFollowsRowCount` |
| 128 | GoalViewRender | 容器高度在 160pt 封顶 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `containerHeightIsCapped` |
| 129 | GoalViewRender | 未超上限时按内容高度 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `containerHeightFollowsContentBelowCap` |
| 130 | GoalTopShadow | 顶部阴影落在面板顶边之上并向顶边渐强 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `topShadowRendersAbovePanelEdge` |
| 131 | GoalTopShadow | 没有活跃 goal 时不画顶部阴影 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `noShadowWithoutActiveGoal` |
| 132 | GoalTopShadow | 顶部阴影沿高度单调衰减，顶端无亮度突变 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `topShadowFadesMonotonically` |
| 133 | GoalForkCoordinator | 开场指令使用分叉副本的任务 ID，而非源任务 ID | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testResumePromptUsesForkedTaskIDs` |
| 134 | GoalToolbarButtonVisibility | 没有 Goal 时不显示按钮 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testHiddenWithoutGoals` |
| 135 | GoalToolbarButtonVisibility | 只有一个活跃 Goal 时隐藏按钮 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testHiddenForSingleActiveGoal` |
| 136 | GoalToolbarButtonVisibility | 只有一个终态 Goal 且任务全部结束时同样隐藏按钮 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testHiddenForSingleFinishedGoal` |
| 137 | GoalToolbarButtonVisibility | 多个 Goal 时保留按钮 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testShownForMultipleGoals` |
| 138 | GoalToolbarButtonVisibility | 多个 Goal 时即使侧栏只展示一个也保留按钮 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testShownForMultipleGoalsWhenSidebarCollapsed` |
| 139 | GoalStateManager | 分叉 blocked Goal 时保留阻塞原因 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testForkPreservesBlockedReason` |
| 140 | GoalForkAttachmentIsolation | 分叉提交走显式附件重载，不消费也不清空发送器挂起的图片/文件附件 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `testForkCommitDoesNotConsumePendingAttachments` |
| 141 | GoalTaskMigration | v5 迁移把数据库放到 GoalStateManager 读取路径 | 旧布局 `<legacy>/GoalTaskPlugin/GoalTaskPlugin/goals.sqlite` | 调用 `migrateData` | 数据库落在 `<current>/<plugin-id>/GoalTaskPlugin/goals.sqlite`，不再多套一层，可重复执行（**回归** #767） | P0 | ✅ 已覆盖 | `v5MigrationLandsDatabaseAtReadPath` |
| 142 | GoalTaskMigration | 读取位置为空时提升被多套一层的旧库 | 读取位置已有空库、内层存在旧库 | 构造 `GoalStateManager` | 旧数据可见；读取位置已有数据时不覆盖（**回归** #767） | P0 | ✅ 已覆盖 | `promotesMisplacedStoreOnlyWhenReadPathIsEmpty` |
| 143 | GoalTaskMigration | v4 的 `GoalTask` 数据目录必须被迁移 | 旧布局 `<legacy>/GoalTask/GoalTaskPlugin/goals.sqlite` | 调用 `migrateData` | 数据库落在当前读取路径；`legacyDataDirectoryNames` 含 `GoalTask`（**回归** #768） | P0 | ✅ 已覆盖 | `v4MigrationReadsGoalTaskDirectory` |
| 144 | GoalTaskTools | GoalTask 工具的失败必须抛出结构化错误 | `get_goal_progress` 传入不存在的 goal_id | 调用 `executeResult` | 抛出错误且消息含候选列表；不再以 `isError == false` 返回（**回归** #769） | P0 | ✅ 已覆盖 | `getProgressThrowsForUnknownGoal` |
| 145 | GoalVM | 侧栏定位最新的非终态 Goal | 先完成旧 Goal，再创建新 Goal | 构造 `GoalVM` 并 `refresh` | `activeGoal` 为新 Goal、`hasActiveWork == true`（**回归** #770） | P0 | ✅ 已覆盖 | `testActiveGoalPrefersLatestNonTerminalGoal` |
| 146 | GoalTaskConversationCleanup | 删除会话时只清理该会话的 Goals | 两个会话各有 Goal | 删除其中一个会话 | 该会话 Goals 为空，另一会话 Goals 保留（**回归** #771） | P1 | ✅ 已覆盖 | `deletingConversationRemovesOnlyItsGoals` |
| 147 | GoalTaskConversationCleanup | 删除多个会话时逐个清理 | 两个会话各有 Goal | 连续删除两个会话 | 两个会话的 Goals 都为空（**回归** #771） | P1 | ✅ 已覆盖 | `deletingMultipleConversationsRemovesEachGoalSet` |
| 148 | GoalHooks | 续跑预算耗尽时只把本次活跃 Goal 标记失败 | 历史 failed Goal + 一个活跃 Goal，续跑次数已耗尽 | 触发 completed 钩子 | 历史失败原因保持不变，活跃 Goal 被标记为超限失败（**回归** #904） | P1 | ✅ 已覆盖 | `testLimitReachedKeepsHistoricalFailureReason` |
| 149 | GoalHooks | 新 Goal 获得独立续跑预算 | 上一 Goal 的续跑计数已耗尽并被标记 failed | 创建新 Goal 后触发 completed 钩子 | 新 Goal 正常续跑（1/5），不被立即判超限（**回归** #903） | P1 | ✅ 已覆盖 | `testNewGoalGetsFreshContinuationBudget` |
| 150 | GoalStateManager | 创建新 Goal 重置会话续跑与代答预算 | 两个预算都已耗尽 | 调用 `createGoal` | 两个计数都从 1 重新开始（**回归** #903） | P1 | ✅ 已覆盖 | `testCreateGoalClearsConversationBudgets` |
| 151 | GoalHooks | 活跃 Goal 静态契约留最前、动态进度锚定最新 user 之前，稳定历史前缀逐字节不变（保前缀缓存） | 多轮历史 + 一个活跃 Goal | 调用 `GoalPromptInjectionHook.apply` | 契约在 [0]、历史前缀不变、进度落在最新 user 之前，消息数 +2 | P1 | ✅ 已覆盖 | `testDynamicProgressAnchorsBeforeLatestUserPreservingPrefix` |
| 152 | GoalHooks | 最新 user 之后仍有尾随 system 消息时，动态进度仍锚定该 user 之前 | 历史末尾为 user + system | 调用 `GoalPromptInjectionHook.apply` | 进度插在最新 user 之前，尾随 system 保持在末尾，消息数 +2 | P1 | ✅ 已覆盖 | `testDynamicProgressAnchorsOnLatestUserWithTrailingSystem` |
| 153 | GoalHooks | blocked 等待指令锚定最新 user 之前，不前置静态契约 | 一个 blocked Goal + 多轮历史 | 调用 `GoalPromptInjectionHook.apply` | 只注入 blocked 一条、历史前缀不变、落在最新 user 之前，消息数 +1 | P1 | ✅ 已覆盖 | `testBlockedPromptAnchorsBeforeLatestUser` |
| 154 | GoalHooks | 续跑开场指令与进度一起锚定最新 user 之前且保持顺序 | 活跃 Goal + 已置位续跑标记 | 调用 `GoalPromptInjectionHook.apply` | 契约在 [0]、进度在续跑指令之前、两者都落在最新 user 之前，消息数 +3 | P1 | ✅ 已覆盖 | `testContinuationPromptAnchorsBeforeLatestUserInOrder` |
| 155 | GoalStateManager | 部分任务成功部分失败时 Goal 推导为终态 failed | 两任务 Goal，A completed、B failed | 调用 `updateGoalTaskStatus` | Goal 状态为 failed 且 isTerminal，不再永久占用活跃槽（**回归** #188） | P0 | ✅ 已覆盖 | `testPartialFailureDerivesFailedGoal` |
| 156 | GoalStateManager | failed 与 skipped 混合且无待办时 Goal 推导为终态 failed | 两任务 Goal，A failed、B skipped | 调用 `updateGoalTaskStatus` | Goal 状态为 failed 且 isTerminal（**回归** #188） | P0 | ✅ 已覆盖 | `testFailedAndSkippedDerivesFailedGoal` |
| 157 | GoalTopShadow | 面板顶边处有一条实心接触线，其上才是衰减区 | 渲染带活跃 goal 的面板 | 取样接触线各行亮度 | 接触线内部浓度接近（实心），其上第一行明显变淡 | P1 | ✅ 已覆盖 | `topShadowHasSolidContactLine` |
| 158 | GoalTopShadow | 阴影浓度峰值位于面板顶边而非带的中段 | 渲染带活跃 goal 的面板 | 比较顶边行与带中段行亮度 | 顶边行比中段更暗，峰值在接触处 | P1 | ✅ 已覆盖 | `topShadowPeakIsAtPanelEdge` |
| 159 | GoalTaskV2 | 精确 goal_id 不得跨会话解析（读取/改状态/追加任务均拒绝） | 会话 A 有 Goal，从会话 B 上下文传 A 的 goal_id | 调用 `get_goal_progress` / `update_goal_status` / `add_tasks_to_goal` | 三者均抛 goal not found；A 的 Goal 状态与任务数不变（**回归** #189） | P0 | ✅ 已覆盖 | `testPreciseGoalIdCannotCrossConversations` |
| 160 | GoalTaskV2 | 精确 goal_id 在本会话内仍可解析（含终态 Goal） | 本会话创建 Goal 并取得 goal_id | 调用 `get_goal_progress`，标记 completed 后再查 | 两次均 isError==false，完成后可读到 completed（**回归** #189） | P1 | ✅ 已覆盖 | `testPreciseGoalIdResolvesWithinSameConversation` |
| 161 | GoalTaskV2 | update_task_status 不得跨会话改写任务 | 会话 A 有 Goal+任务，从会话 B 上下文传 A 的 task_id | 调用 `update_task_status`（status=completed） | 抛 task not found；A 的任务/Goal 状态不变，续跑计数不被清零（**回归** #190） | P0 | ✅ 已覆盖 | `testUpdateTaskStatusCannotCrossConversations` |
| 162 | GoalTaskV2 | update_task_status 在本会话内仍可更新任务 | 本会话创建 Goal+任务并取得 task_id | 调用 `update_task_status`（status=completed） | isError==false，任务状态变为 completed（**回归** #190） | P1 | ✅ 已覆盖 | `testUpdateTaskStatusResolvesWithinSameConversation` |
| 163 | GoalHooks | 用户编辑后下一轮注入新文本与一次性提示，提示只出现一次 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testUserEditInjectsNewContentAndOneShotNotice` |
| 164 | GoalHooks | 没有用户编辑时不注入编辑提示 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testNoEditNoticeWithoutUserEdit` |
| 165 | GoalHooks | blocked 期间编辑不消费提示标记，重新活跃后才注入 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testEditNoticeDeferredWhileBlocked` |
| 166 | GoalDisplayAndVM | 保存编辑写库并经 GoalChangeCenter 通知当前会话 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testUpdateGoalContentNotifiesAndPersists` |
| 167 | GoalDisplayAndVM | 旧会话的迟到保存不通知新会话 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `testStaleSaveDoesNotNotifyAfterConversationSwitch` |
| 168 | GoalDisplayAndVM | 写入失败时原样抛出且不通知 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `testUpdateGoalContentRethrowsWithoutNotify` |
| 169 | GoalDisplayAndVM | manager 不可用时保存抛出 managerUnavailable | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `testUpdateGoalContentWithoutManagerThrows` |
| 170 | GoalStateManager | 用户编辑更新内容字段并刷新 updatedAt，不改状态 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testUpdateGoalContent` |
| 171 | GoalStateManager | 用户编辑拒绝未知与终态 Goal | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `testUpdateGoalContentRejectsUnknownAndTerminal` |
| 172 | GoalStateManager | 用户编辑拒绝空标题并把空内容归一为 nil | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `testUpdateGoalContentValidation` |
| 173 | GoalStateManager | 用户编辑设置一次性提示，恰好消费一次 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testUserEditNoticeConsumedOnce` |
| 174 | GoalStateManager | 用户编辑重置续跑预算；删除 Goal 清理待注入提示 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testUserEditBudgetResetAndNoticeCleanup` |
| 175 | GoalTaskTools | update_goal_status blocked 时回显 suggested_actions（#857） | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `updateGoalStatusBlockedSurfacesSuggestedActions` |
| 176 | GoalTaskTools | update_goal_status blocked 但无建议时不输出建议列表（#857） | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `updateGoalStatusBlockedWithoutSuggestionsHasNoList` |
| 177 | GoalTaskTools | update_goal_status 非 blocked 状态不输出建议列表（#857） | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `updateGoalStatusNonBlockedDoesNotSurfaceSuggestions` |
| 178 | GoalTaskTools | stringList 逐项 trim、丢弃空串与非字符串项，兼容 [Any]（#857） | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `testStringListParsing` |
| 179 | GoalTaskOrphanCleanup | createGoal 建立 Task→Goal 关系，使 .cascade 可命中 | 创建含 2 个 Task 的 Goal | 独立保活上下文 fetch Goal | `goal.tasks.count == 2`、ID 集合一致、每个 `task.goal` 指回该 Goal（**回归** #815） | P0 | ✅ 已覆盖 | `testCreateGoalLinksTasksForCascade` |
| 180 | GoalTaskOrphanCleanup | deleteAllGoals 清除 createGoal 产生的全部 Task | 创建含 3 个 Task 的 Goal | `deleteAllGoals` | 该会话 Goals 为空，`fetchTasks(goalId:)` 为空，不得残留孤儿（**回归** #815） | P0 | ✅ 已覆盖 | `testDeleteAllGoalsRemovesCreatedTasks` |
| 181 | GoalTaskOrphanCleanup | deleteAllGoals 清除追加（addTasksToGoal）的 Task | Goal 含 1 Task，再追加 2 个 | `deleteAllGoals` | `fetchTasks(goalId:)` 为空，追加的 Task 不得绕过清理（**回归** #815） | P0 | ✅ 已覆盖 | `testDeleteAllGoalsRemovesAppendedTasks` |
| 182 | GoalTaskOrphanCleanup | deleteAllGoals 清除 fork 副本的 Task，且不影响源会话 | 源会话 Goal 含 2 Task，fork 到目标会话 | 对目标会话 `deleteAllGoals` | 副本 Task 与 Goals 清空，源会话 Task 仍为 2（**回归** #815） | P0 | ✅ 已覆盖 | `testDeleteAllGoalsRemovesForkedTasks` |
| 183 | GoalTaskOrphanCleanup | deleteAllGoals 显式按 goalId 清除未链接的历史孤儿 Task | Goal 含 1 链接 Task，另用独立容器写入只带 goalId 的未链接孤儿 | `deleteAllGoals` | `fetchTasks(goalId:)` 为空，未链接孤儿也必须按 goalId 一并清除（**回归** #815） | P0 | ✅ 已覆盖 | `testDeleteAllGoalsRemovesUnlinkedLegacyOrphan` |
| 184 | GoalForkCoordinator | 分叉继承源对话的自主模式，首轮可用工具 | 源对话为 autonomous | 调用 `forkAndStart` | 新对话被应用 autonomous 且 allowsTools（**回归** #772） | P0 | ✅ 已覆盖 | `testForkInheritsAutonomousLevel` |
| 185 | GoalForkCoordinator | 分叉继承源对话的构建模式 | 源对话为 build | 调用 `forkAndStart` | 新对话被应用 build（**回归** #772） | P1 | ✅ 已覆盖 | `testForkInheritsBuildLevel` |
| 186 | GoalForkCoordinator | 源对话无工具时分叉至少升到 Build，绝不退化成无工具回合 | 源对话为 chat（无工具） | 调用 `forkAndStart` | 新对话被应用 build 且 allowsTools，不退化成 chat（**回归** #772） | P0 | ✅ 已覆盖 | `testForkUpgradesToollessSourceToBuild` |
| 187 | GoalForkCoordinator | 先捕获源等级再建对话，应用等级落在新对话且早于启动回合 | 记录 capability 调用序列 | 调用 `forkAndStart` | sourceAutomationLevel 早于 createConversation，applyAutomationLevel 早于 startTurn 且落在分叉会话（**回归** #772） | P0 | ✅ 已覆盖 | `testAutomationCaptureAndApplyOrdering` |
| 188 | GoalForkAutomationInheritance | sourceAutomationLevel 读选中源对话的等级，而非全局 New Chat 默认 | 选中源对话为 autonomous、全局为 chat | 调用 `sourceAutomationLevel` | 返回 autonomous（源对话等级），不是全局 chat（**回归** #772） | P0 | ✅ 已覆盖 | `testSourceLevelReadsSelectedConversationNotGlobal` |
| 189 | GoalForkAutomationInheritance | applyAutomationLevel 把等级写到分叉出的目标对话 | 新建目标对话 | 调用 `applyAutomationLevel(.build, to:)` | setAutomationLevel 落在目标对话，其等级变为 build（**回归** #772） | P0 | ✅ 已覆盖 | `testApplyLevelTargetsForkedConversation` |
| 190 | GoalForkAutomationInheritance | 未选中源对话时回落到全局默认（边界） | 无选中对话、全局为 build | 调用 `sourceAutomationLevel` | 返回全局 build（边界回落） | P2 | ✅ 已覆盖 | `testSourceLevelFallsBackToGlobalWhenNoSelection` |

> 说明：全部 **190 条场景**已在本包 `swift test` 中实跑通过。
> 用例名与描述取自 `Tests/` 下的真实 `@Test` 声明，改动测试时须同步本表。

> 变异验证（**#772**，`GoalForkCoordinator` / `GoalForkCapabilityAdapter`）：
> - 机制 A（协调器应用等级）：把 `forkAndStart` 里的 `capability.applyAutomationLevel(effectiveLevel, to: conversationID)` 换成 `_ = effectiveLevel`（不再写新对话等级），用例 184/186/187 及继承断言转红（新对话拿不到源等级、无工具回合未被升级），恢复后转绿。
> - 机制 B（适配器读源对话）：把 `sourceAutomationLevel` 的 `conversations.automationLevel(for: conversations.selectedConversationID)` 换成 `conversations.globalAutomationLevel`（读全局默认），用例 188 转红（拿到全局 chat 而非源 autonomous），恢复后转绿。

> 变异验证（**#815**，`GoalStateManager`）：
> - 机制 A（建立关系）：删除 createGoal / addTasksToGoal / forkGoal 里的 `task.goal = goal` / `copy.goal = forked`，用例 179 转红（`goal.tasks` 为空，2 条断言失败），而 180–183 仍绿（机制 B 按 goalId 显式删除兜底）；恢复后转绿。
> - 机制 B（显式按 goalId 删除）：把 `deleteAllGoals` 改回只 `context.delete(goal)` 依赖 `.cascade`，用例 183 转红（未链接孤儿存活，1 条断言失败），而 179–182 仍绿（已链接 Task 被 cascade 命中）；恢复后转绿。

## 覆盖率统计

- P0: 已覆盖 34 / 34
- P1: 已覆盖 139 / 139
- P2: 已覆盖 17 / 17
- **合计: 190 / 190**（仅表示清单场景，非源码覆盖率）

## 优先级说明

- **P0**: 描述/名称含崩溃、泄漏、截断、丢失、竞态、超时、必须、不得、重试等失效类信号的用例（34 条）
- **P1**: 其余功能性用例（139 条）
- **P2**: 稳定常量、占位、文案、空集合等边界用例（17 条）

## 跨平台说明

- Package 声明: macOS 14+, iOS 17+
- 190 条用例位于 `Tests/`，需在目标平台执行 `swift test`

## 测试执行

```bash
cd Packages/PluginGoalTask
swift test
```

## 维护规则

1. **新增公开 API** → 先在 TestPlan 登记测试用例，再写实现
2. **Bug 修复** → 追加回归用例，标注触发条件
3. **删除用例** → 在 commit message 说明理由
4. **状态同步** → 实现后更新 TestPlan，标记 ✅ 并填写测试方法名
5. **改名同步** → 重命名 `@Test` 函数后必须同步本表，否则 `Scripts/verify-testplan.py` 会报「登记方法在源码不存在」
