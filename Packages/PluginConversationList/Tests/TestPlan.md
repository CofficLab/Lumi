# TestPlan — PluginConversationList

## 包概述

PluginConversationList 的实现包，包含 14 个主要类型；当前测试覆盖 27 条用例。

平台: macOS 14+, iOS 17+
测试文件: 9 个，用例总数: 27

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
- **ConversationListToolbarViewModel**（2 条）：由 `toolbarRefreshesConversationPresenceAndObservesChatVisibility`、`toolbarShowsCurrentProjectScopeOnlyWhenItHasConversationsAndOthersExist` 等用例锁定；改动该模块时优先跑对应测试文件。
- **ConversationListViewModel**（5 条）：由 `initialLoadAndHeaderReflectConversationAndProjectState`、`currentProjectScopeFiltersReloadAndUpdatesProjectTitle`、`nextPageAppendsOnlyTheRemainingConversations` 等用例锁定；改动该模块时优先跑对应测试文件。
- **ConversationRailTabController**（2 条）：由 `railTabsFollowConversationAndCurrentProjectAvailability`、`stoppingRailControllerCancelsRefreshSubscriptions` 等用例锁定；改动该模块时优先跑对应测试文件。
- **ConversationSortStabilizer**（3 条）：由 `sortTimeStaysAnchoredUntilTheHoldWindowExpires`、`markingViewedAnchorsTheConversationAtTheCurrentTime`、`cleanupKeepsRecentAnchorsAndDropsOldOnes` 等用例锁定；改动该模块时优先跑对应测试文件。
- **GetRecentConversationsTool**（4 条）：由 `emptyConversationListReturnsHelpfulStatus`、`recentConversationTableEscapesTitlesAndMarksCurrentProject`、`recentConversationLimitDefaultsAndClampsToOneThroughTwenty` 等用例锁定；改动该模块时优先跑对应测试文件。
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
| 25 | RelativeTime | relativeTimeFormatsPastMinutesHoursAndDays | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `relativeTimeFormatsPastMinutesHoursAndDays` |
| 26 | RelativeTime | relativeTimeTreatsRecentAndFutureDatesAsJustNow | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `relativeTimeTreatsRecentAndFutureDatesAsJustNow` |
| 27 | RelativeTime | conversationPageCursorKeepsItsTimestampAndIdentifier | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `conversationPageCursorKeepsItsTimestampAndIdentifier` |

> 说明：全部 **27 条场景**已在本包 `swift test` 中实跑通过。
> 用例名与描述取自 `Tests/` 下的真实 `@Test` 声明，改动测试时须同步本表。

## 覆盖率统计

- P0: 已覆盖 0 / 0
- P1: 已覆盖 23 / 23
- P2: 已覆盖 4 / 4
- **合计: 27 / 27**（仅表示清单场景，非源码覆盖率）

## 优先级说明

- **P0**: 描述/名称含崩溃、泄漏、截断、丢失、竞态、超时、必须、不得、重试等失效类信号的用例（0 条）
- **P1**: 其余功能性用例（23 条）
- **P2**: 稳定常量、占位、文案、空集合等边界用例（4 条）

## 跨平台说明

- Package 声明: macOS 14+, iOS 17+
- 27 条用例位于 `Tests/`，需在目标平台执行 `swift test`

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
