# TestPlan — PluginConversationManager

## 包概述

PluginConversationManager 的实现包，包含 14 个主要类型；当前测试覆盖 27 条用例。

平台: macOS 14+, iOS 17+
测试文件: 8 个，用例总数: 27

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
- **ConversationManagerCRUD**（2 条）：由 `creationInheritsGlobalPreferencesAndKeepsChildOutOfRootCache`、`selectionTitleActivityAndDeletionUpdateCachedStateAndEvents` 等用例锁定；改动该模块时优先跑对应测试文件。
- **ConversationManagerObserverTransfer**（1 条）：由 `transferredObserversStayAliveAndCancelWithTheirOriginalHandles` 等用例锁定；改动该模块时优先跑对应测试文件。
- **ConversationManagerPreference**（2 条）：由 `automationPreferenceDoesNotPublishStructuralListChange`、`globalAndConversationPreferencesUpdateCacheAndNotifyObservers` 等用例锁定；改动该模块时优先跑对应测试文件。
- **ConversationStoreObserver**（2 条）：由 `forwardsEventsAndMigrationStateUntilCancelled`、`capabilityAdapterUsesManagerAndEmptyMessageFallbacks` 等用例锁定；改动该模块时优先跑对应测试文件。
- **ConversationStoreSettingsViewModel**（3 条）：由 `loadsPagesCountsMessagesAndSelectedConversation`、`selectionFallsBackWhenMissingAndReloadsForStructuralEvents`、`emptyLoadsFinishAndMessagesClearWithoutSelection` 等用例锁定；改动该模块时优先跑对应测试文件。
- **ConversationListRefresh**（1 条）：由 `activeUpdatesAreDebounced` 等用例锁定；改动该模块时优先跑对应测试文件。
- **ConversationStore**（10 条）：由 `createAndFetch`、`createStoresOnlyModelID`、`updateVerbosity` 等用例锁定；改动该模块时优先跑对应测试文件。

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

> 说明：全部 **27 条场景**已在本包 `swift test` 中实跑通过。
> 用例名与描述取自 `Tests/` 下的真实 `@Test` 声明，改动测试时须同步本表。

## 覆盖率统计

- P0: 已覆盖 2 / 2
- P1: 已覆盖 20 / 20
- P2: 已覆盖 5 / 5
- **合计: 27 / 27**（仅表示清单场景，非源码覆盖率）

## 优先级说明

- **P0**: 描述/名称含崩溃、泄漏、截断、丢失、竞态、超时、必须、不得、重试等失效类信号的用例（2 条）
- **P1**: 其余功能性用例（20 条）
- **P2**: 稳定常量、占位、文案、空集合等边界用例（5 条）

## 跨平台说明

- Package 声明: macOS 14+, iOS 17+
- 27 条用例位于 `Tests/`，需在目标平台执行 `swift test`

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
