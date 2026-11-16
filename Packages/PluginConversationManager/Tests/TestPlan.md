# TestPlan — PluginConversationManager

## 包概述

PluginConversationManager 的实现包，包含 14 个主要类型；当前测试覆盖 113 条用例。

平台: macOS 14+, iOS 17+
测试文件: 15 个，用例总数: 113

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
- **ConversationManagerPreference**（17 条）：由 `automationPreferenceDoesNotPublishStructuralListChange`、`globalAndConversationPreferencesUpdateCacheAndNotifyObservers`、`globalLanguagePersistsAcrossRestartWithoutSelectedConversation`、`evictedConversationKeepsItsOwnLanguage`、`globalVerbosityPersistsAcrossRestartWithoutSelectedConversation`、`evictedConversationKeepsItsBoundModel`、`evictedConversationKeepsItsAutomationLevel`、`evictedConversationKeepsItsReasoningEffort`、`evictedConversationUsesReasoningSetWhileMissing`、`clearedReasoningOnEvictedConversationStaysOff`、`unknownConversationHasNoReasoningEffort`、`unknownConversationStillDefaultsToBuild`、`createdConversationPersistsEffectiveLanguage`、`setLanguagePersistsAcrossRestart`、`globalAutomationLevelPersistsAcrossRestartWithoutSelectedConversation`、`globalChatGPTVerbosityPersistsAcrossRestartWithoutSelectedConversation` 等用例锁定；改动该模块时优先跑对应测试文件。创建时的有效语言与 `setLanguage` 都必须写入 `languageRaw`，重启后会话保留自己的语言而不是回退全局值（**回归 #169**）。
- **ConversationLanguagePersistence**（3 条）：由 `createPersistsLanguage`、`createWithoutLanguageLeavesNil`、`updateLanguagePersists` 锁定。存储层创建与偏好更新入口必须把语言写入 `languageRaw`；未显式设置时保持 nil，读取侧回退全局语言（**回归 #169**）。
- **ConversationStoreObserver**（2 条）：由 `forwardsEventsAndMigrationStateUntilCancelled`、`capabilityAdapterUsesManagerAndEmptyMessageFallbacks` 等用例锁定；改动该模块时优先跑对应测试文件。
- **ConversationStoreSettingsViewModel**（5 条）：由 `loadsPagesCountsMessagesAndSelectedConversation`、`selectionFallsBackWhenMissingAndReloadsForStructuralEvents`、`emptyLoadsFinishAndMessagesClearWithoutSelection`、`preferenceEventsRefreshCachedSummaries`、`reopeningRefreshesStaleSummaries` 等用例锁定；模型与偏好事件必须按 ID 就地刷新摘要，重进页面不得沿用陈旧快照。
- **ConversationListRefresh**（1 条）：由 `activeUpdatesAreDebounced` 等用例锁定；改动该模块时优先跑对应测试文件。
- **分页会话的可操作性**（9 条）：由 `deletesUncachedConversation`、`renamesUncachedConversation`、`selectingPagedConversationBackfillsTitle` 等用例锁定；分页返回的真实会话必须能执行与首屏会话相同的删除、改名、偏好与选择操作。
- **ConversationStore**（14 条）：由 `createAndFetch`、`createStoresOnlyModelID`、`updateVerbosity`、`updateChatGPTVerbosity` 等用例锁定；改动该模块时优先跑对应测试文件。

- **ConversationStore 项目会话 ID**（3 条）：由 `returnsOnlyProjectConversations`、`limitsToTheActivityWindow`、`emptyProjectReturnsEmptyArray` 锁定——项目维度统计靠会话存储提供「项目 → 会话 ID」的映射；`updatedSince` 把集合限制在活动窗口内，项目下没有会话时返回空数组。改动这条映射时必须优先跑该文件。

- **ConversationProviderReplacement**（4 条，#640）：由 `singleDeletionCancelsAndClearsCurrentProductionProviders`、`batchDeletionCancelsAndClearsCurrentProductionProviders`、`capabilityStatisticsReadCurrentProductionMessageManager`、`managerFallsBackToCapturedProvidersWithoutResolver` 锁定——`ConversationManager` 在 order 7 创建时捕获的默认 Message/AgentLoop 会被 order 8 插件替换；删除（单条/批量）的 `cancelTurn`/`clearMessages` 与设置页 Capability 的 count/snapshot 必须经解析器动态读取当前生产 Provider，不得停留在创建时的默认实例；无解析器时回退捕获值。改动 Provider 注入或删除/统计链路时必须优先跑该文件。

- **ConversationStartupSnapshotMerge**（2 条，#439）：由 `startupSnapshotMergesConversationCreatedDuringLoad`、`loadWithoutLocalChangesRestoresPersistedSelection` 锁定——启动加载是「await 读快照 → 写回内存」两段式，写回前必须比对本地改动代次：加载期间用户新建/选中的会话不得被晚到的旧快照覆盖，选中态不得被劫持回快照首项；只有加载期间无本地改动时才沿用快照并恢复持久化选中。改动 `loadConversations()` 写回链路时必须优先跑该文件。

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
| 86 | ConversationLanguagePersistence | 创建时传入的语言必须被持久化（**回归 #169**） | 临时数据库 | 以 `language: .english` 创建会话后查库 | `languageRaw` 与读回语言均为 English | P0 | ✅ 已覆盖 | `createPersistsLanguage` |
| 87 | ConversationLanguagePersistence | 创建时未传语言则保持为空，读取时回退全局 | 临时数据库 | 不传 language 创建会话后查库 | 读回语言为 nil | P2 | ✅ 已覆盖 | `createWithoutLanguageLeavesNil` |
| 88 | ConversationLanguagePersistence | 偏好更新入口可以持久化语言（**回归 #169**） | 会话已按 Chinese 创建 | `updateConversationPreferences(language: .english)` | 返回 true，读回语言为 English | P1 | ✅ 已覆盖 | `updateLanguagePersists` |
| 89 | ConversationManagerPreference | 创建时的有效语言必须落库（**回归 #169**） | 全局语言 English，带持久化层的 Manager | `createConversationAndWait` 后立即查库 | 库中语言为 English | P0 | ✅ 已覆盖 | `createdConversationPersistsEffectiveLanguage` |
| 90 | ConversationManagerPreference | setLanguage 后重启会话保留自己的语言（**回归 #169**） | 全局 Chinese，会话改为 English | 等写盘确认后新建 Manager 并 `loadConversations()` | 重启后 `language(for:)` 为 English，不回退全局值 | P1 | ✅ 已覆盖 | `setLanguagePersistsAcrossRestart` |
| 91 | ConversationManagerPreference | New Chat 默认自动化级别跨重启保留（**回归 #1144**） | 未选中任何会话 | `setGlobalAutomationLevel(.chat)` 后新建 Manager 并 `loadConversations()` | 重启后 `globalAutomationLevel` 仍为 Chat | P1 | ✅ 已覆盖 | `globalAutomationLevelPersistsAcrossRestartWithoutSelectedConversation` |
| 92 | ConversationManagerPreference | New Chat 默认 ChatGPT 详细度跨重启保留 | 未选中任何会话 | `setGlobalVerbosity(.chatGPT)` 后新建 Manager 并 `loadConversations()` | 重启后 `globalVerbosity` 仍为 chatGPT | P1 | ✅ 已覆盖 | `globalChatGPTVerbosityPersistsAcrossRestartWithoutSelectedConversation` |
| 93 | ConversationStore | ChatGPT V5 详细程度可持久化 | 临时数据库 | 创建后 `updateConversationPreferences(verbosity: .chatGPT)` | 更新成功且读回为 chatGPT | P1 | ✅ 已覆盖 | `updateChatGPTVerbosity` |
| 94 | ConversationManagerCRUD | 单条删除落库失败时还原乐观移除（**回归 #801**） | 绕过管理器删除库行制造 `store.deleteConversations` 失败 | 调用 `deleteConversation(id:)` 并等后台 Task | 内存列表、选中项与当前标题还原为该会话，不报告成功 | P0 | ✅ 已覆盖 | `singleDeletionRestoresMemoryWhenPersistFails` |
| 95 | ConversationManagerCRUD | 批量清理落库失败时返回空数组并保留内存（**回归 #801**） | 工具管理器替身在清理阶段删掉库行，使落库删除返回 false | 调用 `deleteConversations(createdBefore:)` | 返回空数组，内存列表原样保留，不报告虚假「已清理 N 条」 | P0 | ✅ 已覆盖 | `bulkDeletionReturnsEmptyAndKeepsMemoryWhenPersistFails` |
| 96 | ConversationStoreSettingsViewModel | inserted/updated 事件不触发磁盘计数查询（**回归 #1311**） | 设置页可见，已加载选中会话计数基线 | 连续投递 10 组 `.inserted`/`.updated` | COUNT 查库次数保持基线，不增加 | P1 | ✅ 已覆盖 | `insertedAndUpdatedEventsDoNotQueryDiskCount` |
| 97 | ConversationStoreSettingsViewModel | 设置页关闭期间不做计数 I/O（**回归 #1311**） | 设置页可见后关闭 | 投递 `.persisted`/`.deleted`/`.cleared` | 不查库也不写回计数，缓存保持旧值 | P1 | ✅ 已覆盖 | `closedSettingsPageDoesNoCountIO` |
| 98 | ConversationStoreSettingsViewModel | 未跟踪会话不计数（**回归 #1311**） | 设置页可见，已加载列表 | 对不在列表里的会话投递 `.persisted` | 不查库，计数字典不含该会话 | P1 | ✅ 已覆盖 | `untrackedConversationIsNotCounted` |
| 99 | ConversationStoreSettingsViewModel | 计数未变不重新发布（**回归 #1311**） | 设置页可见，两个会话已加载 | 对非选中会话投递计数不变的 `.persisted` | 不触发 `objectWillChange`，计数保持原值 | P1 | ✅ 已覆盖 | `unchangedCountDoesNotRepublish` |
| 100 | ConversationStoreSettingsViewModel | 重新打开补齐落后计数（**回归 #1311**） | 关闭期间计数变化被忽略 | 重新打开设置页 | 计数刷新为最新值 | P1 | ✅ 已覆盖 | `reopeningRefreshesStaleCounts` |
| 101 | ConversationLegacyMigration | v4 迁移必须把 lastMessageAt 映射为 updatedAt，不得回退 createdAt（**回归 #836**） | 旧库含 A（创建 day1/活跃 day10）与 B（创建 day5/活跃 day5） | 读取迁移摘要并按 lastMessageAt 降序排序 | A.lastMessageAt=day10≠createdAt，B=day5，排序为 A、B | P0 | ✅ 已覆盖 | `readerMapsLastMessageAtToUpdatedAtForActivitySorting` |
| 102 | ConversationGlobalDefaultsIsolation | 有选中会话时重启不得用会话配置反写全局默认（**回归 #786**） | 全局 brief/chat/english，选中会话 A 改为 detailed/autonomous/chinese 并落盘 | 新建 Manager 并 `loadConversations()` | 全局默认仍为 brief/chat/english，A 的会话级配置保持不变 | P0 | ✅ 已覆盖 | `restartWithSelectedConversationKeepsIndependentGlobalDefaults` |
| 103 | ConversationGlobalDefaultsIsolation | 重启后新建会话继承全局默认而非选中会话配置（**回归 #786**） | 全局 brief/chat/english，选中会话 A 为 detailed/autonomous/chinese | 重启后 `createConversationAndWait` 创建 B | B 的详细度/自动化/语言为 brief/chat/english，不继承 A | P0 | ✅ 已覆盖 | `newConversationAfterRestartInheritsGlobalDefaultsNotSelectedConversation` |
| 104 | ConversationGlobalDefaultsIsolation | 运行期改会话级详细度不得反写全局默认（**回归 #786** 护栏） | 全局 brief，会话 A 初始 brief | `setVerbosity(.detailed, for: A)` | 全局仍 brief，A 变为 detailed | P1 | ✅ 已覆盖 | `changingConversationVerbosityDoesNotRewriteGlobalDefault` |
| 105 | ConversationProviderReplacement | 单条删除必须取消并清理替换后的生产 Provider（**回归 #640**） | 解析器初始指向默认替身，随后模拟 order 8 替换为生产替身 | `deleteConversation(id:)` 并等后台清理 | 生产 AgentLoop 收到 `cancelTurn`、生产 MessageManager 收到 `clearMessages`；默认替身两者皆空 | P0 | ✅ 已覆盖 | `singleDeletionCancelsAndClearsCurrentProductionProviders` |
| 106 | ConversationProviderReplacement | 批量清理必须作用于替换后的生产 Provider（**回归 #640**） | 过期会话已落库，解析器模拟 order 8 替换 | `deleteConversations(createdBefore:)` | 返回命中 ID，生产替身收到 `cancelTurn`/`clearMessages`，默认替身皆空 | P0 | ✅ 已覆盖 | `batchDeletionCancelsAndClearsCurrentProductionProviders` |
| 107 | ConversationProviderReplacement | 设置页统计读取替换后的生产 MessageManager（**回归 #640**） | Capability 由动态解析的 Manager 构造，默认计数 0、生产计数 7 | 替换后读取 `messageCount`/`messagesSnapshot` | 计数为 7、快照来自生产替身，而非空默认 | P1 | ✅ 已覆盖 | `capabilityStatisticsReadCurrentProductionMessageManager` |
| 108 | ConversationProviderReplacement | 无解析器时回退创建时捕获的 Provider（**回归 #640** 护栏） | 直接注入捕获替身、不提供解析器 | `deleteConversation(id:)` 并等后台清理 | 捕获替身收到 `cancelTurn`/`clearMessages`，旧调用方不被破坏 | P1 | ✅ 已覆盖 | `managerFallsBackToCapturedProvidersWithoutResolver` |
| 109 | ConversationManagerCRUD | 删除进行中的复活窗口里重载与选中都排除墓碑 ID（**回归 #535**） | 会话已落库且仍在库中，标记 `pendingDeletionIDs` 模拟删除进行中 | 调用 `loadConversationPage` 与 `selectConversation(id:)` | 分页结果不含墓碑 ID（存活会话仍在），选中被拒绝；解除墓碑后该 ID 重新可见 | P0 | ✅ 已覆盖 | `deletionTombstoneExcludesConversationFromReloadAndSelection` |
| 110 | ConversationManagerCRUD | 删除同步标记墓碑、窗口内拒绝选中、清理后解除（**回归 #535**） | 会话已落库并被选中 | 调用 `deleteConversation(id:)`，同步断言后等后台清理完成 | 墓碑与乐观移除立即生效，窗口内选中幽灵 ID 被拒绝；库行消失后墓碑解除 | P0 | ✅ 已覆盖 | `deleteConversationMarksTombstoneSynchronouslyAndClearsAfterCleanup` |
| 111 | ConversationManagerCRUD | 门闩构造慢清理，墓碑持续生效直到清理完成（**回归 #535**） | 工具管理器替身在 `deleteToolCalls` 处被门闩挡住 | 删除后等清理停在门闩，重载一次，再放行 | 清理未完成期间墓碑仍生效、重载仍排除该 ID；放行后墓碑解除 | P0 | ✅ 已覆盖 | `slowCleanupHoldsTombstoneUntilCleanupFinishes` |
| 112 | ConversationStartupSnapshotMerge | 加载期间新建的会话不被晚到的旧快照覆盖，选中态不被劫持（**回归 #439**） | 门闩把只含旧会话的快照挡在写回前，持久化选中指向旧会话 | 加载停在 await 时新建并选中一个会话，再放行旧快照 | 新会话存活、旧会话被合并进来，选中态与标题停在新会话 | P0 | ✅ 已覆盖 | `startupSnapshotMergesConversationCreatedDuringLoad` |
| 113 | ConversationStartupSnapshotMerge | 加载期间无本地改动时仍恢复持久化选中（**回归 #439** 护栏） | 旧会话已落库，持久化选中指向它，无门闩无新建 | 新建 Manager 并 `loadConversations()` | 列表含旧会话，选中态恢复为旧会话 | P1 | ✅ 已覆盖 | `loadWithoutLocalChangesRestoresPersistedSelection` |

> 说明：全部 **113 条场景**已在本包 `swift test` 中实跑通过。
> 用例名与描述取自 `Tests/` 下的真实 `@Test` 声明，改动测试时须同步本表。
>
> 变异验证（#640）：将 `ConversationManager.messageManager`/`agentTurn` 计算属性还原为只返回 `capturedMessageManager`/`capturedAgentTurn`（忽略解析器）→ `singleDeletionCancelsAndClearsCurrentProductionProviders`、`batchDeletionCancelsAndClearsCurrentProductionProviders`、`capabilityStatisticsReadCurrentProductionMessageManager` 转红（生产替身收不到调用、统计读到空默认），`managerFallsBackToCapturedProvidersWithoutResolver` 仍绿。变异单独施加并确认转红后还原，最终 108 条全绿。
>
> 变异验证（#535）：① 把 `loadConversationPage`/`fetchConversationPage` 的墓碑过滤改为恒真 → `deletionTombstoneExcludesConversationFromReloadAndSelection` 转红（重载复活墓碑 ID）；② 移除 `selectConversation` 的墓碑守卫 → 同用例转红（幽灵 ID 被选中）；③ 移除 `deleteConversation` 的同步 `pendingDeletionIDs.insert` → `deleteConversationMarksTombstoneSynchronouslyAndClearsAfterCleanup` 转红；④ 移除清理成功后的 `pendingDeletionIDs.subtract` → `slowCleanupHoldsTombstoneUntilCleanupFinishes` 转红（墓碑永不解除）。变异单独施加并确认转红后还原，最终 111 条全绿。
>
> 变异验证（#439）：把 `loadConversations()` 写回处的代次判断 `if self.conversationMutationGeneration == startGeneration` 改为恒真（永远走覆盖分支）→ `startupSnapshotMergesConversationCreatedDuringLoad` 转红（新建会话被旧快照抹掉、选中态被劫持回旧会话、标题退回旧值），`loadWithoutLocalChangesRestoresPersistedSelection` 仍绿。变异确认转红后还原，最终 113 条全绿。

## 覆盖率统计

- P0: 已覆盖 23 / 23
- P1: 已覆盖 82 / 82
- P2: 已覆盖 8 / 8
- **合计: 113 / 113**（仅表示清单场景，非源码覆盖率）

## 优先级说明

- **P0**: 描述/名称含崩溃、泄漏、截断、丢失、竞态、超时、必须、不得、重试等失效类信号的用例（23 条）
- **P1**: 其余功能性用例（82 条）
- **P2**: 稳定常量、占位、文案、空集合等边界用例（8 条）

## 跨平台说明

- Package 声明: macOS 14+, iOS 17+
- 113 条用例位于 `Tests/`，需在目标平台执行 `swift test`

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
