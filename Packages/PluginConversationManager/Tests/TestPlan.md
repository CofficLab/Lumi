# TestPlan — PluginConversationManager

## 包概述

PluginConversationManager 的实现包，包含 14 个主要类型；当前测试覆盖 85 条用例。

平台: macOS 14+, iOS 17+
测试文件: 11 个，用例总数: 85

核心组件（源码目录）:
- `Capabilities/`
- `Errors/`
- `Managers/`
- `Models/`
- `Observers/`
- `Service/`
- `Support/`
- `ViewModels/`
- `Views/`

## 公开 API

包内主要类型（按声明顺序抽取，供定位被测对象）:

- `ConversationManagerPlugin`
- `ConversationStoreCapability`
- `ConversationStoreError`
- `ConversationObserverHandleImpl`
- `ConversationManager`
- `ConversationModel`
- `Conversation`
- `ConversationStoreObserver`
- `ConversationLegacyMigration`
- `ConversationStore`
- `V4ConversationReader`
- `ConversationsDidChangeEvent`
- `ConversationMigrationProgressStore`
- `ConversationStoreSettingsViewModel`

## 关键行为契约（实现约定，非协议要求）

按测试模块归纳，改动对应模块时须保持既有断言成立:

- **ConversationLegacyMigration**（6 条）：由 `readerCopiesLegacyDatabaseMapsFieldsReusesAndReleasesItsSnapshot`、`readerReportsMissingAndInvalidLegacyDatabases`、`locatorPrefersProductionAndUsesDebugFallback` 等用例锁定；改动该模块时优先跑对应测试文件。
- **ConversationManagerCRUD**（3 条）：由 `creationInheritsGlobalPreferencesAndKeepsChildOutOfRootCache`、`createAndWaitPersistsBeforeReturningAndCachesRoot`、`selectionTitleActivityAndDeletionUpdateCachedStateAndEvents` 等用例锁定；改动该模块时优先跑对应测试文件。
- **ConversationManagerObserverTransfer**（1 条）：由 `transferredObserversStayAliveAndCancelWithTheirOriginalHandles` 等用例锁定；改动该模块时优先跑对应测试文件。
- **ConversationManagerPreference**（13 条）：由 `automationPreferenceDoesNotPublishStructuralListChange`、`globalAndConversationPreferencesUpdateCacheAndNotifyObservers`、`globalLanguagePersistsAcrossRestartWithoutSelectedConversation`、`evictedConversationKeepsItsOwnLanguage`、`globalVerbosityPersistsAcrossRestartWithoutSelectedConversation`、`evictedConversationKeepsItsBoundModel`、`evictedConversationKeepsItsAutomationLevel`、`evictedConversationKeepsItsReasoningEffort`、`evictedConversationUsesReasoningSetWhileMissing`、`clearedReasoningOnEvictedConversationStaysOff`、`unknownConversationHasNoReasoningEffort`、`unknownConversationStillDefaultsToBuild` 等用例锁定；改动该模块时优先跑对应测试文件。
- **ConversationStoreObserver**（2 条）：由 `forwardsEventsAndMigrationStateUntilCancelled`、`capabilityAdapterUsesManagerAndEmptyMessageFallbacks` 等用例锁定；改动该模块时优先跑对应测试文件。
- **ConversationStoreSettingsViewModel**（5 条）：由 `loadsPagesCountsMessagesAndSelectedConversation`、`selectionFallsBackWhenMissingAndReloadsForStructuralEvents`、`emptyLoadsFinishAndMessagesClearWithoutSelection`、`preferenceEventsRefreshCachedSummaries`、`reopeningRefreshesStaleSummaries` 等用例锁定；模型与偏好事件必须按 ID 就地刷新摘要，重进页面不得沿用陈旧快照。
- **ConversationListRefresh**（1 条）：由 `activeUpdatesAreDebounced` 等用例锁定；改动该模块时优先跑对应测试文件。
- **分页会话的可操作性**（9 条）：由 `deletesUncachedConversation`、`renamesUncachedConversation`、`selectingPagedConversationBackfillsTitle` 等用例锁定；分页返回的真实会话必须能执行与首屏会话相同的删除、改名、偏好与选择操作。
- **ConversationStore**（13 条）：由 `createAndFetch`、`createStoresOnlyModelID`、`updateVerbosity` 等用例锁定；改动该模块时优先跑对应测试文件。

- **ConversationStore 项目会话 ID**（3 条）：由 `returnsOnlyProjectConversations`、`limitsToTheActivityWindow`、`emptyProjectReturnsEmptyArray` 锁定——项目维度统计靠会话存储提供「项目 → 会话 ID」的映射；`updatedSince` 把集合限制在活动窗口内，项目下没有会话时返回空数组。改动这条映射时必须优先跑该文件。

## 测试用例清单

| ID | 类别 | 描述 | 前置条件 | 操作步骤 | 预期结果 | 优先级 | 状态 | 测试方法 |
|----|------|------|----------|----------|----------|------|------|----------|
| 1 | ConversationLegacyMigration | readerCopiesLegacyDatabaseMapsFieldsReusesAndReleasesItsSnapshot | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `readerCopiesLegacyDatabaseMapsFieldsReusesAndReleasesItsSnapshot` |
| 2 | ConversationLegacyMigration | readerReportsMissingAndInvalidLegacyDatabases | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `readerReportsMissingAndInvalidLegacyDatabases` |
| 3 | ConversationLegacyMigration | locatorPrefersProductionAndUsesDebugFallback | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `locatorPrefersProductionAndUsesDebugFallback` |
| 4 | ConversationLegacyMigration | migrationImportsLegacyDataOnceAndPersistsMarker | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `migrationImportsLegacyDataOnceAndPersistsMarker` |
| 5 | ConversationLegacyMigration | failedDatabaseReadDoesNotWriteMarkerAndCanRetry | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `failedDatabaseReadDoesNotWriteMarkerAndCanRetry` |
| 6 | ConversationLegacyMigration | emptyLegacyDatabaseCompletesMigrationWithZeroImports | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `emptyLegacyDatabaseCompletesMigrationWithZeroImports` |
| 7 | ConversationManagerCRUD | creationInheritsGlobalPreferencesAndKeepsChildOutOfRootCache | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `creationInheritsGlobalPreferencesAndKeepsChildOutOfRootCache` |
| 8 | ConversationManagerCRUD | selectionTitleActivityAndDeletionUpdateCachedStateAndEvents | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `selectionTitleActivityAndDeletionUpdateCachedStateAndEvents` |
| 9 | ConversationManagerObserverTransfer | transferredObserversStayAliveAndCancelWithTheirOriginalHandles | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `transferredObserversStayAliveAndCancelWithTheirOriginalHandles` |
| 10 | ConversationManagerPreference | automationPreferenceDoesNotPublishStructuralListChange | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `automationPreferenceDoesNotPublishStructuralListChange` |
| 11 | ConversationManagerPreference | globalAndConversationPreferencesUpdateCacheAndNotifyObservers | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `globalAndConversationPreferencesUpdateCacheAndNotifyObservers` |
| 12 | ConversationStoreObserver | forwardsEventsAndMigrationStateUntilCancelled | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `forwardsEventsAndMigrationStateUntilCancelled` |
| 13 | ConversationStoreObserver | capabilityAdapterUsesManagerAndEmptyMessageFallbacks | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `capabilityAdapterUsesManagerAndEmptyMessageFallbacks` |
| 14 | ConversationStoreSettingsViewModel | loadsPagesCountsMessagesAndSelectedConversation | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `loadsPagesCountsMessagesAndSelectedConversation` |
| 15 | ConversationStoreSettingsViewModel | selectionFallsBackWhenMissingAndReloadsForStructuralEvents | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `selectionFallsBackWhenMissingAndReloadsForStructuralEvents` |
| 16 | ConversationStoreSettingsViewModel | emptyLoadsFinishAndMessagesClearWithoutSelection | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `emptyLoadsFinishAndMessagesClearWithoutSelection` |
| 17 | ConversationListRefresh | 消息活跃更新会合并侧栏刷新通知 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `activeUpdatesAreDebounced` |
| 18 | ConversationStore | 创建会话后可分页查询 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `createAndFetch` |
| 19 | ConversationStore | 新对话只持久化全局唯一模型 ID | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `createStoresOnlyModelID` |
| 20 | ConversationStore | 更新会话详细程度后可持久化 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `updateVerbosity` |
| 21 | ConversationStore | ConversationManager 等待详细程度写入完成 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `managerSetVerbosityAndWaitPersists` |
| 22 | ConversationStore | 迁移导入按 id 去重（幂等） | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `importSummariesIsIdempotent` |
| 23 | ConversationStore | 更新标题与删除 | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `updateAndDelete` |
| 24 | ConversationStore | 子代理对话纳入级联删除范围 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `cascadeDeleteIncludesChildren` |
| 25 | ConversationStore | 分页、项目过滤、会话统计和每日统计 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `projectPagesCountsAndDailySeries` |
| 26 | ConversationStore | 会话字段更新和批量迁移路径 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `updatesConversationFieldsAndProjectPaths` |
| 27 | ConversationStore | ConversationManager delegates paged reads and caches only root summaries | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `managerFetchesPagesCountsAndRootCache` |
| 28 | ConversationStore 项目会话 ID | 只返回该项目的会话 ID | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `returnsOnlyProjectConversations` |
| 29 | ConversationStore 项目会话 ID | 活动窗口把会话集合限制在窗口内 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `limitsToTheActivityWindow` |
| 30 | ConversationStore 项目会话 ID | 项目下没有会话时返回空数组 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `emptyProjectReturnsEmptyArray` |
| 31 | ConversationModelSelection | 钉选模型后会话的 modelID 必须被写入 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `selectModelWritesConversationModelID` |
| 32 | ConversationModelSelection | 会话列表重载后模型钉选不得丢失 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `modelSelectionSurvivesConversationReload` |
| 33 | ConversationStoreUntitledQuery | 无标题会话查询只命中真正无标题的会话 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `findsOnlyUntitledConversations` |
| 34 | ConversationStoreUntitledQuery | 无标题会话查询排除子代理会话 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `excludesChildConversations` |
| 35 | ConversationStoreUntitledQuery | 无标题查询遵守 limit | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `respectsLimit` |
| 36 | ConversationEmptyTitleConsistency | 空标题在内存与数据库两层都表示「没有标题」 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `emptyTitleMeansNoTitleInBothLayers` |
| 37 | ConversationEmptyTitleConsistency | 真实标题经过存取往返后保持不变 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `realTitleSurvivesRoundTrip` |
| 38 | ConversationEmptyTitleConsistency | 清空标题后内存与数据库仍然一致 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `clearingTitleKeepsMemoryAndDatabaseConsistent` |
| 39 | ConversationEmptyTitleConsistency | 只有空白的标题等同于没有标题（两层一致） | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `treatsWhitespaceOnlyTitleAsUntitled` |
| 40 | ConversationStoreUntitledQuery | 只有空白的标题等同于没有标题 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `whitespaceOnlyTitleIsEquivalentToNoTitle` |
| 41 | 项目绑定 | 显式 `.none` 不会回退到当前项目（**回归**） | 当前项目 `/tmp/current-project` | `createConversation(binding: .none)` | 新对话 `projectPath` 为 nil，不被挂到当前项目 | P0 | ✅ 已覆盖 | `noneDoesNotFallBackToCurrentProject` |
| 42 | 项目绑定 | `.inheritCurrent` 沿用当前项目 | 当前项目 `/tmp/current-project` | `createConversation(binding: .inheritCurrent)` | 新对话 `projectPath` 为 `/tmp/current-project` | P1 | ✅ 已覆盖 | `inheritCurrentUsesCurrentProject` |
| 43 | 项目绑定 | `.project` 覆盖当前项目 | 当前项目 `/tmp/current-project`，显式 `/tmp/source-project` | `createConversation(binding: .project(...))` | 新对话 `projectPath` 为 `/tmp/source-project` | P1 | ✅ 已覆盖 | `explicitProjectOverridesCurrent` |
| 44 | 项目绑定 | 旧接口 `projectPath: nil` 仍沿用当前项目 | 当前项目 `/tmp/current-project` | `createConversation(projectPath: nil)` | 行为不变，`projectPath` 为当前项目 | P1 | ✅ 已覆盖 | `legacyNilStillInheritsCurrentProject` |
| 45 | 项目绑定 | 空字符串项目标识不会写入数据层 | 显式 `.project("")` 与旧接口 `projectPath: ""` | 分别创建对话 | 两条对话 `projectPath` 均为 nil，存储层无空字符串 | P0 | ✅ 已覆盖 | `emptyProjectPathIsNeverStored` |
| 46 | ConversationManagerCRUD | 等待落库的创建接口返回时会话已可从库里读到（**回归 #541**） | 有持久化层的 manager | `createConversationAndWait` | 返回后立即 `fetchConversation` 命中，内存缓存与选中态同步 | P1 | ✅ 已覆盖 | `createAndWaitPersistsBeforeReturningAndCachesRoot` |
| 47 | ConversationStoreStats | 每日计数按自然日分桶 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `countsPerCalendarDay` |
| 48 | ConversationStoreStats | 项目作用域只统计该项目 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `scopesToProject` |
| 49 | ConversationStoreStats | 「创建于 cutoff 之前」按 createdAt 判定 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `selectsByCreatedAt` |
| 50 | ConversationStoreStats | 清理父会话时连带清掉子 Agent 会话 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `deletesDescendantsAlongsideParent` |
| 51 | ConversationCountLedger | 删除会话后每日计数保持不变 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `countsSurviveDeletion` |
| 52 | ConversationCountLedger | 批量清理旧对话后统计保持不变 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `countsSurviveBulkCleanup` |
| 53 | ConversationCountLedger | 重启后账本从磁盘恢复，不重复回填 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `ledgerSurvivesRestart` |
| 54 | ConversationManagerCRUD | 删除父会话时子会话也收到 `.deleted` 通知 | 根会话与一个子会话 | 删除根会话 | 观察者依次收到根与子会话的 `.deleted`（**回归 #771**） | P1 | ✅ 已覆盖 | `deletingRootNotifiesDescendantConversations` |
| 55 | ConversationStoreSettings | 刷新落地后旧分页结果不追加 | 首屏 40 条，翻页延迟 400ms | 翻页途中刷新列表 | 最终列表等于刷新结果，无旧分页条目 | P0 | ✅ 已覆盖 | `loadMoreDoesNotAppendStalePageAfterReload` |
| 56 | ConversationModelSelection | 会话不在缓存数组中时模型选择仍然生效 | 会话数组为空，指定一个 UUID | `selectModel` 后读取 `modelID/providerID/modelName` | 返回刚选中的模型，provider/model 可解析 | P0 | ✅ 已覆盖 | `selectModelAppliesToConversationOutsideCache` |
| 57 | ConversationStore | 分页按最后消息时间 keyset，创建早但最近活跃的会话不会被漏掉（**回归 #964**） | 5 条会话，创建顺序与活跃顺序相反 | 以 `lastMessageAt` 为游标、limit=2 连续翻页 | 收集到的 ID 顺序等于活跃顺序，且无重复 | P0 | ✅ 已覆盖 | `paginatesByLastMessageAtKeyset` |
| 58 | ConversationStore | 相同最后消息时间仍有稳定顺序，且分页不重复、不遗漏（**回归 #964**） | 4 条会话 `createdAt` 完全相同 | limit=2 连续翻页直到为空 | 收集到的 ID 集合等于全部 ID，数量一致 | P1 | ✅ 已覆盖 | `paginatesTiedTimestampsStably` |
| 59 | 分页会话的可操作性 | 未缓存的会话也能删除（**回归 #965**） | 会话已持久化但不在管理器的缓存窗口内 | 调用 `deleteConversation(id:)` | 持久化记录被删除 | P1 | ✅ 已覆盖 | `deletesUncachedConversation` |
| 60 | 分页会话的可操作性 | 未缓存的会话也能改名（**回归 #965**） | 会话不在缓存内 | 调用 `updateConversationTitle` | 返回 true，新标题落库 | P1 | ✅ 已覆盖 | `renamesUncachedConversation` |
| 61 | 分页会话的可操作性 | 未缓存的会话也能保存偏好（**回归 #965**） | 会话不在缓存内 | 设置 verbosity 与 reasoningEffort | 两项偏好都落库 | P1 | ✅ 已覆盖 | `persistsPreferencesForUncachedConversation` |
| 62 | 分页会话的可操作性 | 选中分页会话后会补载标题（**回归 #965**） | 会话不在缓存内 | `selectConversation(id:)` | 标题从 "No conversation" 恢复为真实标题 | P1 | ✅ 已覆盖 | `selectingPagedConversationBackfillsTitle` |
| 63 | 分页会话的可操作性 | 分页结果会进入缓存（**回归 #965**） | 会话不在缓存内 | `fetchConversationPage` | 返回的根会话出现在缓存中 | P1 | ✅ 已覆盖 | `pagedResultsEnterCache` |
| 64 | ConversationStoreSettingsViewModel | 模型与偏好变更事件按 ID 刷新对应摘要（**回归 #966**） | 首屏已加载并持有摘要快照 | 投递 `.providerChanged` 与四类偏好事件 | 该条摘要更新为 Manager 当前值，其它条目不变，且不整页重载 | P1 | ✅ 已覆盖 | `preferenceEventsRefreshCachedSummaries` |
| 65 | ConversationStoreSettingsViewModel | 重新进入页面会纠正陈旧摘要（**回归 #966**） | 首屏已加载，Manager 侧摘要已更新 | 再次调用 `loadInitialIfNeeded` | 已加载摘要就地刷新，不重新请求整页 | P1 | ✅ 已覆盖 | `reopeningRefreshesStaleSummaries` |
| 66 | ConversationManagerPreference | New Chat 默认语言跨重启保留（**回归 #983**） | 未选中任何会话 | `setGlobalLanguage(.english)` 后新建 Manager 并 `loadConversations()` | 重启后 `globalLanguage` 仍为 English | P1 | ✅ 已覆盖 | `globalLanguagePersistsAcrossRestartWithoutSelectedConversation` |
| 67 | ConversationManagerPreference | 被挤出缓存的会话保留自己的语言（**回归 #984**） | 后台会话 English，全局 Chinese | 写入 100 条更新的顶层会话把后台会话挤出窗口后调用 `language(for:)` | 仍返回该会话的 English，而非全局 Chinese | P1 | ✅ 已覆盖 | `evictedConversationKeepsItsOwnLanguage` |
| 68 | ConversationManagerPreference | New Chat 默认详细度跨重启保留（**回归 #986**） | 未选中任何会话 | `setGlobalVerbosity(.brief)` 后新建 Manager 并 `loadConversations()` | 重启后 `globalVerbosity` 仍为 brief | P1 | ✅ 已覆盖 | `globalVerbosityPersistsAcrossRestartWithoutSelectedConversation` |
| 69 | ConversationManagerPreference | 被挤出缓存的会话保留绑定的模型（**回归 #987**） | 后台会话绑定 `gpt-a/model-a` | 写入 100 条更新的顶层会话把后台会话挤出窗口后读取 `modelID(for:)` | 仍返回原模型与供应商，而非全局模型 | P1 | ✅ 已覆盖 | `evictedConversationKeepsItsBoundModel` |
| 70 | ConversationStoreSettingsViewModel | 消息变化刷新计数与选中会话预览（**回归 #995**） | 选中会话已有 2 条消息，后台会话 1 条 | 插入一条消息产生 `.inserted`，再对后台会话产生 `.updated` | 选中会话计数变 3、预览追加新消息；后台会话只更新计数 | P1 | ✅ 已覆盖 | `messageChangeRefreshesCountAndSelectedPreview` |
| 71 | ConversationStoreObserver | 消息变化转发到设置页，取消后停止（**回归 #995**） | 能力层已注册消息观察者 | 发送 `.inserted` 后取消 observer 再发送 `.updated` | 首次计数更新，取消后不再写入 | P1 | ✅ 已覆盖 | `forwardsMessageChangesUntilCancelled` |
| 72 | ConversationPagedMutation | 回填加载触发缓存淘汰后仍能写入标题（**回归 #996**） | 81 条历史会话，冷启动缓存 40 条 | 逐条 `fetchConversation` 把候选补进缓存越过 80 上限，目标被同步淘汰后更新标题 | 目标不在缓存中，更新返回 true 且标题落库 | P1 | ✅ 已覆盖 | `renamesConversationEvictedRightAfterBackfillFetch` |
| 73 | ConversationManagerPreference | 被挤出缓存的会话保留自己的自动化级别（**回归 #1008**） | 后台会话 Autonomous | 写入 100 条更新的顶层会话把后台会话挤出窗口后调用 `automationLevel(for:)` | 仍返回 `.autonomous`，不再回退 `.build` | P1 | ✅ 已覆盖 | `evictedConversationKeepsItsAutomationLevel` |
| 74 | ConversationManagerPreference | 未知会话与 nil 仍回退 Build（**回归 #1008** 护栏） | 缓存中已有 Autonomous 会话 | 对 nil 与随机 UUID 调用 `automationLevel(for:)` | 均返回 `.build`，不被其它会话的级别污染 | P1 | ✅ 已覆盖 | `unknownConversationStillDefaultsToBuild` |
| 75 | 分页会话的可操作性 | 选中未缓存会话后水合详细度会通知 UI（**回归 #1069**） | Manager 缓存没有该会话，持久化为 V1/brief | 选中会话并等待补载完成 | 补发 `.verbosityChanged(id)`，`verbosity(for:)` 变为 brief | P1 | ✅ 已覆盖 | `selectingUncachedConversationPublishesHydratedVerbosity` |
| 76 | 分页会话的可操作性 | 补载选中会话时补发详细度事件（**回归 #1069**） | 选中会话不在缓存，`fetchConversation(id:)` 负责水合 | 调用 `fetchConversation(id:)` | 补发 `.verbosityChanged(id)` | P1 | ✅ 已覆盖 | `fetchingSelectedConversationPublishesHydratedVerbosity` |
| 77 | 分页会话的可操作性 | 补载非选中会话不触发详细度刷新（**回归 #1069**） | 另一个会话处于选中状态 | 补载未选中的历史会话 | 不发送该 ID 的 `.verbosityChanged` | P2 | ✅ 已覆盖 | `hydratingUnselectedConversationStaysSilent` |
| 78 | ConversationManagerCRUD | 等待落盘的标题更新返回前已完成数据库写入（**回归 #950**） | store 支撑的 Manager 与会话 | 调用 `updateConversationTitleAndWait` 后立即查库 | 返回 true，内存与数据库标题均为新值 | P1 | ✅ 已覆盖 | `updateConversationTitleAndWaitPersistsBeforeReturning` |
| 79 | ConversationManagerCRUD | 落盘失败不发布内存新标题也不报告成功（**回归 #950**） | 绕过管理器删除库行制造 `store.updateTitle` 失败 | 调用 `updateConversationTitleAndWait` | 返回 false，内存/当前标题保持旧值且不发 `.updated` 事件 | P0 | ✅ 已覆盖 | `updateConversationTitleAndWaitLeavesMemoryUntouchedWhenPersistFails` |
| 80 | ConversationStore | 存储不可用时分页读取抛错而不是返回空页（**#932**） | Manager 未接入 store | 分别调用全库与项目两处分页读取 | 均抛出 `ConversationPageLoadError.storageUnavailable` | P1 | ✅ 已覆盖 | `loadPageWithoutStoreThrows` |
| 81 | ConversationManagerCRUD | 批量清理只报告命中的顶层会话，不把连带删除的子会话计入（**回归 #897**） | 一个过期父会话 + 两个过期子会话 + 一个新会话 | 以 `includingChildConversations: false` 调用 `deleteConversations(createdBefore:)` | 返回 `[parent]`，库中只剩新会话；「清理前计数」与「已删除条数」口径一致 | P1 | ✅ 已覆盖 | `bulkDeletionReturnsTopLevelTargetsNotCascadedChildren` |
| 82 | ConversationManagerPreference | 被挤出缓存的会话保留自己的推理强度（**回归 #892**） | 后台会话 High | 写入 100 条更新的顶层会话把后台会话挤出窗口后调用 `reasoningEffortOptional(for:)` | 仍返回 `.high`，下一次请求不会省略 reasoning_effort | P0 | ✅ 已覆盖 | `evictedConversationKeepsItsReasoningEffort` |
| 83 | ConversationManagerPreference | 会话在缓存外设置推理强度也作用于后续请求（**回归 #892**） | 后台会话已被挤出缓存 | `setReasoningEffort(.max, for:)` 后读取 | 返回 `.max` | P1 | ✅ 已覆盖 | `evictedConversationUsesReasoningSetWhileMissing` |
| 84 | ConversationManagerPreference | 缓存外清除推理强度后不残留淘汰前的旧档位（**回归 #892** 护栏） | 后台会话 High 且已被挤出缓存 | `clearReasoningEffort(for:)` 后读取 | 返回 nil | P1 | ✅ 已覆盖 | `clearedReasoningOnEvictedConversationStaysOff` |
| 85 | ConversationManagerPreference | 未知会话仍没有显式推理强度（**回归 #892** 护栏） | 缓存中已有 High 会话 | 对 nil 与随机 UUID 读取 | 均返回 nil，不被其他会话污染 | P2 | ✅ 已覆盖 | `unknownConversationHasNoReasoningEffort` |

> 说明：全部 **85 条场景**已在本包 `swift test` 中实跑通过。
> 用例名与描述取自 `Tests/` 下的真实 `@Test` 声明，改动测试时须同步本表。

## 覆盖率统计

- P0: 已覆盖 10 / 10
- P1: 已覆盖 68 / 68
- P2: 已覆盖 7 / 7
- **合计: 85 / 85**（仅表示清单场景，非源码覆盖率）

## 优先级说明

- **P0**: 描述/名称含崩溃、泄漏、截断、丢失、竞态、超时、必须、不得、重试等失效类信号的用例（10 条）
- **P1**: 其余功能性用例（68 条）
- **P2**: 稳定常量、占位、文案、空集合等边界用例（7 条）

## 跨平台说明

- Package 声明: macOS 14+, iOS 17+
- 81 条用例位于 `Tests/`，需在目标平台执行 `swift test`

## 测试执行

```bash
cd Packages/PluginConversationManager
swift test
```

## 维护规则

1. **新增公开 API** → 先在 TestPlan 登记测试用例，再写实现
2. **Bug 修复** → 追加回归用例，标注触发条件
3. **删除用例** → 在 commit message 说明理由
4. **状态同步** → 实现后更新 TestPlan，标记 ✅ 并填写测试方法名
5. **改名同步** → 重命名 `@Test` 函数后必须同步本表，否则 `Scripts/verify-testplan.py` 会报「登记方法在源码不存在」
