# TestPlan — PluginGoalTask

## 包概述

GoalTaskPlugin 目标导向的任务管理插件，为 Lumi 提供 Goal（目标）+ Task（任务）两层结构的任务追踪能力。

平台: macOS 14+, iOS 17+
测试文件: 10 个，用例总数: 121

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
- **GoalForkCoordinator**（11 条）：由 `testForkAndStartHappyPath`、`testResumePromptContent`、`testResumePromptListsOnlyOutstandingTasks` 等用例锁定；改动该模块时优先跑对应测试文件。
- **GoalHooks**（24 条）：由 `testNoManagerReturnsContextUnchanged`、`testNoActiveGoalsInjectsNothing`、`testBlockedGoalInjectsOnlyStopPrompt` 等用例锁定；改动该模块时优先跑对应测试文件。
- **GoalStateManagerAppendFork**（19 条）：由 `testAddTasksContinuesOrder`、`testAddTasksThrowsWhenGoalAlreadyFull`、`testAddTasksWritesPartialBatch` 等用例锁定；改动该模块时优先跑对应测试文件。
- **GoalStateManager**（13 条）：由 `testCreateGoal`、`testUpdateTaskStatusDerivesGoalStatus`、`testUpdateGoalStatusBlocked` 等用例锁定；改动该模块时优先跑对应测试文件。
- **GoalTaskTimeline**（2 条）：由 `continuationMessage`、`limitReachedMessage` 等用例锁定；改动该模块时优先跑对应测试文件。
- **GoalTaskTools**（20 条）：由 `addTasksAppendsAndReports`、`addTasksResolvesOmittedGoalId`、`addTasksFiltersEntriesWithoutTitle` 等用例锁定；改动该模块时优先跑对应测试文件。
- **GoalTaskV2**（9 条）：由 `preservesPluginIdentityAndPolicy`、`preservesLegacyToolNamesAndRequiredArguments`、`createGoalUsesExecutionConversation` 等用例锁定；改动该模块时优先跑对应测试文件。
- **TaskListSurface**（4 条）：由 `bottomEdgeHasVisibleShadow`、`topAndBottomShadowAreSymmetric`、`bottomBandMirrorsTopBand` 等用例锁定；改动该模块时优先跑对应测试文件。

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

> 说明：全部 **121 条场景**已在本包 `swift test` 中实跑通过。
> 用例名与描述取自 `Tests/` 下的真实 `@Test` 声明，改动测试时须同步本表。

## 覆盖率统计

- P0: 已覆盖 8 / 8
- P1: 已覆盖 99 / 99
- P2: 已覆盖 14 / 14
- **合计: 121 / 121**（仅表示清单场景，非源码覆盖率）

## 优先级说明

- **P0**: 描述/名称含崩溃、泄漏、截断、丢失、竞态、超时、必须、不得、重试等失效类信号的用例（8 条）
- **P1**: 其余功能性用例（99 条）
- **P2**: 稳定常量、占位、文案、空集合等边界用例（14 条）

## 跨平台说明

- Package 声明: macOS 14+, iOS 17+
- 121 条用例位于 `Tests/`，需在目标平台执行 `swift test`

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
