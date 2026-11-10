# TestPlan — PluginConversationList

## 包概述

PluginConversationList 的实现包，包含 15 个主要类型；当前测试覆盖 62 条用例。

平台: macOS 14+, iOS 17+
测试文件: 13 个，用例总数: 62

核心组件（源码目录）:
- `Helpers/`
- `Models/`
- `Observers/`
- `Support/`
- `Tools/`
- `ViewModels/`
- `Views/`

## 公开 API

包内主要类型（按声明顺序抽取，供定位被测对象）:

- `ConversationListContext`
- `ConversationListPlugin`
- `ConversationSortStabilizer`
- `ConversationAttentionStore`
- `ConversationAttentionScanner`
- `ConversationPageCursor`
- `ConversationListContextObserver`
- `ConversationRailTabController`
- `GetRecentConversationsTool`
- `ConversationListToolbarViewModel`
- `ConversationListViewModel`
- `HeaderBarView`
- `ItemView`
- `ListEmptyView`
- `ListErrorView`

## 关键行为契约（实现约定，非协议要求）

按测试模块归纳，改动对应模块时须保持既有断言成立:

- **ConversationAttentionStore**（2 条）：由 `attentionStorePublishesOnlyStateChanges`、`attentionIsTrackedIndependentlyForEachConversation` 等用例锁定；改动该模块时优先跑对应测试文件。
- **ConversationListContext**（3 条）：由 `contextPublishesSelectionChangesOnceAndConversationRefreshes`、`contextTracksTheCurrentProjectNameAndPath`、`contextObserverRefreshesForStructureAndStateButIgnoresVerbosity` 等用例锁定；改动该模块时优先跑对应测试文件。
- **ConversationListPlugin**（3 条）：由 `pluginBootRegistersToolbarToolAndDynamicRailTabsThenShutsThemDown`、`pluginDoesNotPartiallyBootWithoutRequiredProviders`、`pluginMarksFinishedTurnsReadOrNeedsAttentionBasedOnSelection` 等用例锁定；改动该模块时优先跑对应测试文件。
- **ConversationListToolbarViewModel**（3 条）：由 `toolbarRefreshesConversationPresenceAndObservesChatVisibility`、`toolbarShowsCurrentProjectScopeOnlyWhenItHasConversationsAndOthersExist`、`toolbarShowsCurrentProjectScopeWhenOnlyProjectlessConversationsDiffer` 等用例锁定；改动该模块时优先跑对应测试文件。
- **ConversationListViewModel**（9 条）：由 `initialLoadAndHeaderReflectConversationAndProjectState`、`currentProjectScopeFiltersReloadAndUpdatesProjectTitle`、`conversationCountReflectsScopeAndUpdatesOnChange`、`reloadFailurePreservesConversationsAndPagination`、`reloadKeepsPagesAppendedWhileItRuns` 等用例锁定；改动该模块时优先跑对应测试文件。
- **ConversationRailTabController**（6 条）：由 `railTabsFollowConversationAndCurrentProjectAvailability`、`railProjectTabAppearsWhenOnlyProjectlessConversationsDiffer`、`stoppingRailControllerCancelsRefreshSubscriptions`、`railVisibilityIsWrittenBackToHostOnEveryReconcile`、`railTabTitlesUsePluginLocalization`、`railTabTitleKeysHaveTranslations` 等用例锁定；改动该模块时优先跑对应测试文件。
- **ConversationRowAccessibility**（4 条）：由 `rowAccessibilityLabelAlwaysStartsWithTitle`、`rowAccessibilityLabelIncludesAutomationLevel`、`rowAccessibilityLabelFallsBackWhenTitleMissing`、`rowAccessibilityLabelSkipsEmptyProviderAndModel` 锁定行朗读文案的组成与回退规则。
- **ConversationRowEmptyTitle**（4 条）：由 `rowLabelFallsBackForEmptyStringTitle`、`rowLabelFallsBackForWhitespaceOnlyTitle`、`emptyStringAndNilTitlesConverge`、`nonEmptyTitleIsPreserved` 锁定空标题回退文案的一致性。
- **ConversationStatsViewModel**（8 条）：由 `loadsDailySeries`、`scopesToCurrentProject`、`cleansUpOlderConversations`、`ignoresConcurrentCleanup` 等用例锁定统计区间、清理边界与并发守卫。
- **ConversationSortStabilizer**（3 条）：由 `sortTimeStaysAnchoredUntilTheHoldWindowExpires`、`markingViewedAnchorsTheConversationAtTheCurrentTime`、`cleanupKeepsRecentAnchorsAndDropsOldOnes` 等用例锁定；改动该模块时优先跑对应测试文件。
- **GetRecentConversationsTool**（5 条）：由 `emptyConversationListReturnsHelpfulStatus`、`recentConversationTableEscapesTitlesAndMarksCurrentProject`、`recentConversationTableEscapesProjectNamesAndKeepsFiveColumns`、`recentConversationLimitDefaultsAndClampsToOneThroughTwenty` 等用例锁定；改动该模块时优先跑对应测试文件。
- **RelativeTime**（3 条）：由 `relativeTimeFormatsPastMinutesHoursAndDays`、`relativeTimeTreatsRecentAndFutureDatesAsJustNow`、`conversationPageCursorKeepsItsTimestampAndIdentifier` 等用例锁定；改动该模块时优先跑对应测试文件。

## 测试用例清单

| ID | 类别 | 描述 | 前置条件 | 操作步骤 | 预期结果 | 优先级 | 状态 | 测试方法 |
|----|------|------|----------|----------|----------|------|------|----------|
| 1 | ConversationAttentionStore | attentionStorePublishesOnlyStateChanges | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `attentionStorePublishesOnlyStateChanges` |
| 2 | ConversationAttentionStore | attentionIsTrackedIndependentlyForEachConversation | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `attentionIsTrackedIndependentlyForEachConversation` |
| 3 | ConversationListContext | contextPublishesSelectionChangesOnceAndConversationRefreshes | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `contextPublishesSelectionChangesOnceAndConversationRefreshes` |
| 4 | ConversationListContext | contextTracksTheCurrentProjectNameAndPath | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `contextTracksTheCurrentProjectNameAndPath` |
| 5 | ConversationListContext | contextObserverRefreshesForStructureAndStateButIgnoresVerbosity | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `contextObserverRefreshesForStructureAndStateButIgnoresVerbosity` |
| 6 | ConversationListPlugin | pluginBootRegistersToolbarToolAndDynamicRailTabsThenShutsThemDown | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `pluginBootRegistersToolbarToolAndDynamicRailTabsThenShutsThemDown` |
| 7 | ConversationListPlugin | pluginDoesNotPartiallyBootWithoutRequiredProviders | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `pluginDoesNotPartiallyBootWithoutRequiredProviders` |
| 8 | ConversationListPlugin | pluginMarksFinishedTurnsReadOrNeedsAttentionBasedOnSelection | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `pluginMarksFinishedTurnsReadOrNeedsAttentionBasedOnSelection` |
| 9 | ConversationListToolbarViewModel | toolbarRefreshesConversationPresenceAndObservesChatVisibility | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `toolbarRefreshesConversationPresenceAndObservesChatVisibility` |
| 10 | ConversationListToolbarViewModel | toolbarShowsCurrentProjectScopeOnlyWhenItHasConversationsAndOthersExist | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `toolbarShowsCurrentProjectScopeOnlyWhenItHasConversationsAndOthersExist` |
| 11 | ConversationListViewModel | initialLoadAndHeaderReflectConversationAndProjectState | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `initialLoadAndHeaderReflectConversationAndProjectState` |
| 12 | ConversationListViewModel | currentProjectScopeFiltersReloadAndUpdatesProjectTitle | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `currentProjectScopeFiltersReloadAndUpdatesProjectTitle` |
| 13 | ConversationListViewModel | nextPageAppendsOnlyTheRemainingConversations | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `nextPageAppendsOnlyTheRemainingConversations` |
| 14 | ConversationListViewModel | selectionClearsAttentionAndDeleteUsesConversationProvider | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `selectionClearsAttentionAndDeleteUsesConversationProvider` |
| 15 | ConversationListViewModel | automationLevelChangeUpdatesOnlyTheAffectedConversationRow | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `automationLevelChangeUpdatesOnlyTheAffectedConversationRow` |
| 16 | ConversationRailTabController | railTabsFollowConversationAndCurrentProjectAvailability | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `railTabsFollowConversationAndCurrentProjectAvailability` |
| 17 | ConversationRailTabController | stoppingRailControllerCancelsRefreshSubscriptions | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `stoppingRailControllerCancelsRefreshSubscriptions` |
| 18 | ConversationSortStabilizer | sortTimeStaysAnchoredUntilTheHoldWindowExpires | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `sortTimeStaysAnchoredUntilTheHoldWindowExpires` |
| 19 | ConversationSortStabilizer | markingViewedAnchorsTheConversationAtTheCurrentTime | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `markingViewedAnchorsTheConversationAtTheCurrentTime` |
| 20 | ConversationSortStabilizer | cleanupKeepsRecentAnchorsAndDropsOldOnes | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `cleanupKeepsRecentAnchorsAndDropsOldOnes` |
| 21 | GetRecentConversationsTool | emptyConversationListReturnsHelpfulStatus | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `emptyConversationListReturnsHelpfulStatus` |
| 22 | GetRecentConversationsTool | recentConversationTableEscapesTitlesAndMarksCurrentProject | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `recentConversationTableEscapesTitlesAndMarksCurrentProject` |
| 23 | GetRecentConversationsTool | recentConversationLimitDefaultsAndClampsToOneThroughTwenty | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `recentConversationLimitDefaultsAndClampsToOneThroughTwenty` |
| 24 | GetRecentConversationsTool | recentConversationToolMetadataSupportsBothLanguages | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `recentConversationToolMetadataSupportsBothLanguages` |
| 25 | GetRecentConversationsTool | recentConversationTableEscapesProjectNamesAndKeepsFiveColumns | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `recentConversationTableEscapesProjectNamesAndKeepsFiveColumns` |
| 26 | RelativeTime | relativeTimeFormatsPastMinutesHoursAndDays | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `relativeTimeFormatsPastMinutesHoursAndDays` |
| 27 | RelativeTime | relativeTimeTreatsRecentAndFutureDatesAsJustNow | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `relativeTimeTreatsRecentAndFutureDatesAsJustNow` |
| 28 | RelativeTime | conversationPageCursorKeepsItsTimestampAndIdentifier | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `conversationPageCursorKeepsItsTimestampAndIdentifier` |
| 29 | ConversationList | 切项目后丢弃旧项目的 reload 快照 | 项目 One 的分页延迟 400ms | reload 期间切到项目 Two | 列表不出现 One 的会话，最终为 Two 的会话 | P1 | ✅ 已覆盖 | `reloadDiscardsSnapshotFromPreviousProject` |
| 30 | ConversationList | 切项目后旧翻页结果不追加到新列表 | 项目 One 有 60 条会话，翻页延迟 400ms | 翻页途中切到 Two 并刷新 | 列表只剩 Two 的会话 | P1 | ✅ 已覆盖 | `loadNextPageDoesNotAppendStalePageAfterProjectSwitch` |
| 31 | ConversationListViewModel | 条数按作用域统计并随会话增删刷新 | 项目 One、Two 各一条会话，挂上下文观察器 | 分别用 `.all` 与 `.currentProject` 加载，再新建一条 Two 会话 | 全库条数为 2，当前项目为 1，新建后当前项目变为 2 | P1 | ✅ 已覆盖 | `conversationCountReflectsScopeAndUpdatesOnChange` |
| 32 | ConversationRailTabController | 每次 reconcile 都把 Rail 可见性写回宿主 | 宿主初始可见性被 Chat 写成 true，且当前无会话 | 启动控制器 → 新建会话 → 删除最后一条会话 | 无 tab 时写回 false，有 tab 时写回 true，清空后回落 false | P1 | ✅ 已覆盖 | `railVisibilityIsWrittenBackToHostOnEveryReconcile` |
| 33 | ConversationRowAccessibility | 行朗读文案始终以标题开头 | 会话带标题、提供方与模型 | 调用 `rowLabel(for:)` | 文案以标题开头，稳定标识符为 `lumi.conversation-list*` | P1 | ✅ 已覆盖 | `rowAccessibilityLabelAlwaysStartsWithTitle` |
| 34 | ConversationRowAccessibility | 行朗读文案包含自动化等级 | 遍历全部 `AutomationLevel` | 调用 `rowLabel(for:)` | 每个等级对应的文案都包含其等级描述 | P1 | ✅ 已覆盖 | `rowAccessibilityLabelIncludesAutomationLevel` |
| 35 | ConversationRowAccessibility | 标题缺失时行文案回退到占位文案 | 会话无标题、无自动化等级 | 调用 `rowLabel(for:)` | 返回非空占位文案，不出现空串 | P2 | ✅ 已覆盖 | `rowAccessibilityLabelFallsBackWhenTitleMissing` |
| 36 | ConversationRowAccessibility | 空提供方与空模型不进入行文案 | 提供方与模型均为空串 | 调用 `rowLabel(for:)` | 文案不包含空段或多余分隔符 | P2 | ✅ 已覆盖 | `rowAccessibilityLabelSkipsEmptyProviderAndModel` |
| 37 | ConversationRowEmptyTitle | 空字符串标题回退为占位文案，不得返回空串 | 标题为 `""` | 调用 `rowLabel(for:)` | 返回占位文案 | P2 | ✅ 已覆盖 | `rowLabelFallsBackForEmptyStringTitle` |
| 38 | ConversationRowEmptyTitle | 纯空白标题回退为占位文案 | 标题为 `"   "` | 调用 `rowLabel(for:)` | 返回占位文案 | P2 | ✅ 已覆盖 | `rowLabelFallsBackForWhitespaceOnlyTitle` |
| 39 | ConversationRowEmptyTitle | 空串标题与 nil 标题回退到同一占位文案 | 一条空串标题、一条 nil 标题 | 分别调用 `rowLabel(for:)` | 两次结果完全相同 | P2 | ✅ 已覆盖 | `emptyStringAndNilTitlesConverge` |
| 40 | ConversationRowEmptyTitle | 有标题时保持原样 | 标题为普通文本 | 调用 `rowLabel(for:)` | 文案以原标题开头，不被替换 | P2 | ✅ 已覆盖 | `nonEmptyTitleIsPreserved` |
| 41 | ConversationStatsViewModel | 加载每日计数序列并暴露区间总数与峰值 | 存根返回多个日期点 | 调用加载 | `series` 与总数、峰值按存根数据填充 | P1 | ✅ 已覆盖 | `loadsDailySeries` |
| 42 | ConversationStatsViewModel | 统计作用域跟随当前项目 | 指定 projectPath | 加载统计 | 请求带上的项目路径与 ViewModel 一致 | P1 | ✅ 已覆盖 | `scopesToCurrentProject` |
| 43 | ConversationStatsViewModel | 清理按创建时间分界点执行并刷新序列 | 存根返回待删除 id 列表 | 调用清理 | 删除条数与分界点正确，序列重新加载 | P1 | ✅ 已覆盖 | `cleansUpOlderConversations` |
| 44 | ConversationStatsViewModel | 30 天窗口的分界点早于 7 天窗口 | — | 分别按 7 天与 30 天计算分界点 | 30 天分界点明显更早 | P1 | ✅ 已覆盖 | `thirtyDayWindowCutsOffEarlier` |
| 45 | ConversationStatsViewModel | 可清理数量由存储层查询给出 | 存根返回 12 | 加载统计 | `deletableCount` 为 12 | P1 | ✅ 已覆盖 | `reportsDeletableCount` |
| 46 | ConversationStatsViewModel | 加载时一并取回各窗口的待删除条数 | 存根返回 5 | 加载统计 | 7 天与 30 天窗口的待删除条数都被填充 | P1 | ✅ 已覆盖 | `loadsDeletableCountsForAllWindows` |
| 47 | ConversationStatsViewModel | 清理后刷新待删除条数 | 初始 9，清理后存根变为新值 | 调用清理 | 待删除条数更新为清理后的值 | P1 | ✅ 已覆盖 | `refreshesDeletableCountsAfterCleanup` |
| 48 | ConversationStatsViewModel | 清理期间重复触发只执行一次 | 清理过程被挂起 | 连续触发两次清理 | 存储层只收到一次清理调用 | P1 | ✅ 已覆盖 | `ignoresConcurrentCleanup` |
| 49 | ConversationAttentionScanner | 被挤出缓存的会话完成时仍产生完成边缘（**#993**） | 缓存为空，上一轮跟踪到 A 在运行，A 已结束 | 执行一轮扫描 | `finished` 含 A，`stillRunning` 为空 | P1 | ✅ 已覆盖 | `evictedConversationStillReportsCompletion` |
| 50 | ConversationAttentionScanner | 被挤出缓存但仍在运行的会话必须继续被跟踪（**#993**） | 缓存为空，上一轮跟踪到 A 在运行，A 仍在运行 | 执行一轮扫描 | `stillRunning` 含 A，`finished` 为空 | P0 | ✅ 已覆盖 | `evictedRunningConversationStaysTracked` |
| 51 | ConversationAttentionScanner | 从未观测为运行的会话结束时不得生成未读提示 | 缓存含 A，跟踪表为空，A 已结束 | 执行一轮扫描 | `finished` 与 `stillRunning` 均为空 | P0 | ✅ 已覆盖 | `neverRunningConversationDoesNotFinish` |
| 52 | ConversationAttentionScanner | 缓存内的会话完成后停止跟踪 | 缓存与跟踪表均含 A，A 已结束 | 执行一轮扫描 | `finished` 含 A，`stillRunning` 为空 | P1 | ✅ 已覆盖 | `cachedConversationFinishesOnce` |
| 53 | ConversationListPlugin | 会话删除后必须停止跟踪并清掉残留未读提示 | 已存在未读提示 | 删除会话 | `needsAttention` 变为 false | P0 | ✅ 已覆盖 | `pluginStopsTrackingAndClearsAttentionWhenConversationIsDeleted` |
| 54 | GetRecentConversationsTool | 标题中的反斜杠加管道符仍留在单个单元格（**#994**） | 标题为字面 `A\|B` | 执行工具并解析数据行 | 输出 `A\\\|B`，数据行未转义管道符恰为 6 个 | P1 | ✅ 已覆盖 | `recentConversationTitleWithBackslashAndPipeStaysInSingleCell` |
| 55 | ConversationListToolbarViewModel | 单项目加无项目会话时仍显示当前项目筛选（**#931**） | 未打开项目时创建会话 G，打开唯一项目 P 并创建会话 C | 刷新分段可见性 | 两个范围条数不同，`showsCurrentProjectScope` 为 true 且可选中当前项目 | P1 | ✅ 已覆盖 | `toolbarShowsCurrentProjectScopeWhenOnlyProjectlessConversationsDiffer` |
| 56 | ConversationRailTabController | 单项目加无项目会话时仍注册项目标签（**#931**） | 未打开项目时创建会话 G，打开唯一项目 P 并创建会话 C | 启动控制器 | 「项目」标签出现，且项目列表只包含 C | P1 | ✅ 已覆盖 | `railProjectTabAppearsWhenOnlyProjectlessConversationsDiffer` |
| 57 | ConversationListViewModel | 刷新读取失败保留已知良好列表与分页（**#932**） | 已加载 40 条，下一次分页读取抛错 | 触发 reload 与 loadNextPage，随后恢复存储再翻页 | 列表与游标不变、hasLoadError 为 true、hasMore 仍为 true；恢复后追加到 60 条 | P0 | ✅ 已覆盖 | `reloadFailurePreservesConversationsAndPagination` |
| 58 | ConversationListViewModel | 首次加载失败后视图重现仍可重试（**#932**） | 首次分页读取抛错 | 再次调用 loadInitialIfNeeded | 仍为空列表且 hasLoadError；恢复后成功加载并清除错误 | P1 | ✅ 已覆盖 | `initialLoadFailureRemainsRetryable` |
| 59 | ConversationListViewModel | 刷新与下一页交错时不删除已追加页面（**#933**） | 已加载 40 条，下一页 100ms 返回、刷新首屏 400ms 返回 | 分页完成后改标题并等待刷新发布 | 列表保留 80 条、hasMore 仍为 true，随后可加载到 100 条 | P0 | ✅ 已覆盖 | `reloadKeepsPagesAppendedWhileItRuns` |
| 60 | ConversationRailTabController | Chat 侧栏标签标题走本地化，tooltip 不再硬编码中文（**#923**） | 同时存在 Chats 与项目标签 | 启动控制器并注入标题解析器 | 两个标签标题均来自解析器，而非中文字面量 | P1 | ✅ 已覆盖 | `railTabTitlesUsePluginLocalization` |
| 61 | ConversationRailTabController | 标签标题依赖的 Chats/Projects key 具备多语言翻译（**#923**） | 插件编译后的字符串表 | 读取各语言 Localizable.strings | 英文为 Chats/Projects，简中为 对话/项目，繁中为 專案 | P1 | ✅ 已覆盖 | `railTabTitleKeysHaveTranslations` |
| 62 | ConversationListViewModel | 切到条数更多的新项目后 reload 保持 hasMore 打开（**#896**） | 项目 A 已加载全部 41 条，项目 B 有 81 条 | 切到 B 并 reload，随后 loadNextPage | reload 后显示 80 条且 hasMore 为 true，翻页后补齐 81 条并关闭 hasMore | P1 | ✅ 已覆盖 | `projectSwitchReloadKeepsPagingUntilNewProjectIsExhausted` |

> 说明：全部 **62 条场景**已在本包 `swift test` 中实跑通过。
> 用例名与描述取自 `Tests/` 下的真实 `@Test` 声明，改动测试时须同步本表。

## 覆盖率统计

- P0: 已覆盖 5 / 5
- P1: 已覆盖 46 / 46
- P2: 已覆盖 11 / 11
- **合计: 62 / 62**（仅表示清单场景，非源码覆盖率）

## 优先级说明

- **P0**: 描述/名称含崩溃、泄漏、截断、丢失、竞态、超时、必须、不得、重试等失效类信号的用例（3 条）
- **P1**: 其余功能性用例（42 条）
- **P2**: 稳定常量、占位、文案、空集合等边界用例（11 条）

## 跨平台说明

- Package 声明: macOS 14+, iOS 17+
- 50 条用例位于 `Tests/`，需在目标平台执行 `swift test`

## 测试执行

```bash
cd Packages/PluginConversationList
swift test
```

## 维护规则

1. **新增公开 API** → 先在 TestPlan 登记测试用例，再写实现
2. **Bug 修复** → 追加回归用例，标注触发条件
3. **删除用例** → 在 commit message 说明理由
4. **状态同步** → 实现后更新 TestPlan，标记 ✅ 并填写测试方法名
5. **改名同步** → 重命名 `@Test` 函数后必须同步本表，否则 `Scripts/verify-testplan.py` 会报「登记方法在源码不存在」
