# TestPlan — PluginProjects

## 包概述

PluginProjects 的实现包，包含 15 个主要类型；当前测试覆盖 45 条用例。

平台: macOS 14+, iOS 17+
测试文件: 11 个，用例总数: 45

核心组件（源码目录）:
- `Capabilities/`
- `Hooks/`
- `Models/`
- `Observers/`
- `Services/`
- `Support/`
- `Tools/`
- `ViewModels/`
- `Views/`

## 公开 API

包内主要类型（按声明顺序抽取，供定位被测对象）:

- `ProjectsPlugin`
- `ProjectRAGStatusCapability`
- `ProjectsProjectCapability`
- `ProjectPathInjectionHook`
- `ProjectEntry`
- `ProjectsStoreError`
- `ConversationProjectSyncObserver`
- `ProjectOpenedFilesPersistence`
- `ProjectProvidingObserver`
- `ProjectRAGStatusObserver`
- `ProjectsLegacyMigration`
- `ProjectsRuntime`
- `ProjectOpenedFiles`
- `AddProjectTool`
- `ListProjectsTool`

## 关键行为契约（实现约定，非协议要求）

按测试模块归纳，改动对应模块时须保持既有断言成立:

- **ConversationProjectSyncObserver**（7 条）：由 `selectingConversationWithProjectOpensProject`、`selectingConversationWithoutProjectDoesNotOpen`、`deselectDoesNotOpenProject` 等用例锁定；改动该模块时优先跑对应测试文件。
- **综合**（5 条）：由 `projectsPersistenceRoundTrip`、`openedFilesPersistenceRoundTrip`、`restoresAndPersistsOpenedFilesThroughProjectProviding` 等用例锁定；改动该模块时优先跑对应测试文件。
- **ProjectPathInjectionHook**（2 条）：由 `injectsConversationProject`、`skipsUnboundConversation` 等用例锁定；改动该模块时优先跑对应测试文件。
- **ListProjectsTool**（4 条）：由 `negativeLimitReturnsParameterError`、`zeroLimitReturnsParameterError`、`nonIntegerLimitReturnsParameterError`、`limitDefaultsAndCaps` 锁定；改动 limit 解析时优先跑对应测试文件。
- **AddProjectNoAutoSelect**（3 条）：由 `addWithoutSelectDoesNotOpenWhenNoCurrentProject`、`addWithoutSelectPreservesExistingCurrentProject`、`addWithSelectStillOpensAddedProject` 锁定 `add(select:false)` 只入列、不得自动打开项目（即使当前无项目），`select:true` 仍打开新增项目（**回归 #475**）；改动 `ProjectsViewModel.add` 时优先跑对应测试文件。
- **ProjectStorageDetector / ProjectStorageRefresh**（15 条）：由 `internalDiskKind`、`missingDirectoryDiffersFromUnreachableVolume`、`cachedResultIsReused`、`refreshIncrementsRevision` 等用例锁定磁盘类型判定、缓存复用与刷新失效；改动存储探测时优先跑对应测试文件。
- **ProjectLastUsed**（3 条）：由 `firstSyncPreservesPersistedLastUsed`、`selectionAdvancesLastUsed`、`resyncWithUnchangedCurrentDoesNotAdvance` 锁定启动同步保留持久化 lastUsed、选中推进使用时间、无关同步不反复刷新（**回归 #476**）；改动 `ProjectsViewModel.syncFromProvider` 时优先跑对应测试文件。

## 测试用例清单

| ID | 类别 | 描述 | 前置条件 | 操作步骤 | 预期结果 | 优先级 | 状态 | 测试方法 |
|----|------|------|----------|----------|----------|------|------|----------|
| 1 | ConversationProjectSyncObserver | 创建并选中绑定项目的对话会调用 openProject 切换到该对话的项目 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `selectingConversationWithProjectOpensProject` |
| 2 | ConversationProjectSyncObserver | 选中未绑定项目的对话不会打开任何项目 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `selectingConversationWithoutProjectDoesNotOpen` |
| 3 | ConversationProjectSyncObserver | 取消选中（nil）不会打开任何项目 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `deselectDoesNotOpenProject` |
| 4 | ConversationProjectSyncObserver | 当前项目已等于对话绑定项目时不重复打开 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `selectingAlreadyBoundProjectDoesNotReopen` |
| 5 | ConversationProjectSyncObserver | 切换选中到已存在的绑定项目对话会打开该项目 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `selectingExistingConversationOpensProject` |
| 6 | ConversationProjectSyncObserver | 项目切换尚未完成时快速选择另一对话，最终项目跟随最新选择 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `rapidSelectionChangesSynchronizeLatestProject` |
| 7 | ConversationProjectSyncObserver | cancel 后不再响应选中变化 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `cancelStopsObserving` |
| 8 | 综合 | projectsPersistenceRoundTrip | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `projectsPersistenceRoundTrip` |
| 9 | 综合 | openedFilesPersistenceRoundTrip | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `openedFilesPersistenceRoundTrip` |
| 10 | 综合 | restoresAndPersistsOpenedFilesThroughProjectProviding | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `restoresAndPersistsOpenedFilesThroughProjectProviding` |
| 11 | 综合 | addProjectValidatesDirectory | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `addProjectValidatesDirectory` |
| 12 | 综合 | storageDirectoryUsesPluginID | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `storageDirectoryUsesPluginID` |
| 13 | ProjectPathInjectionHook | injects the conversation project instead of the currently open project | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `injectsConversationProject` |
| 14 | ProjectPathInjectionHook | does not inject when the conversation has no project | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `skipsUnboundConversation` |
| 15 | ListProjectsTool | 负数 limit 返回参数错误，不进入 prefix 的负数 precondition | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `negativeLimitReturnsParameterError` |
| 16 | ListProjectsTool | 0 limit 返回参数错误，语义固定为「非法」而非「不限制」 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `zeroLimitReturnsParameterError` |
| 17 | ListProjectsTool | 非整数 limit（如 1e100）返回参数错误，不静默回退默认值 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `nonIntegerLimitReturnsParameterError` |
| 18 | ListProjectsTool | limit 缺省为 5，超过 500 安全截断 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `limitDefaultsAndCaps` |
| 19 | ProjectsStore | 并发保存不遗留临时文件 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `concurrentSavesLeaveNoTemporaryFiles` |
| 20 | ProjectsStore | 并发保存后文件仍可读取 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `concurrentSavesLeaveReadableFile` |
| 21 | ProjectsSettingsOpenedFiles | 打开文件记录变更后设置页缓存刷新 | 隔离 Store | `startObservingOpenedFiles` 后两次 `saveOpenedFiles` | 缓存跟随最新写入，而非首次快照 | P0 | ✅ 已覆盖 | `openedFilesProjectionRefreshesWhenStoreChanges` |
| 22 | ProjectsSettingsOpenedFiles | preview-only 当前文件显示 Active 而非空态 | `openFileURLs` 为空、`currentFileURL` 非空 | 调用 `openedFilesSectionState` | 返回 `.content`，仅两者皆空才返回 `.empty` | P0 | ✅ 已覆盖 | `previewOnlyCurrentFileShowsActiveRow` |
| 23 | ProjectsPlugin RAG 状态观察者 | 重复构建详情区块会注销旧观察者 | kernel 注册计数用 RAG Provider | 对同一路径连续调用两次 `makeRAGStatusSection` | 旧观察者被 cancel，Provider 中只剩一个存活观察者 | P1 | ✅ 已覆盖 | `repeatedSectionCreationReplacesObserver` |
| 24 | ProjectsPlugin RAG 状态观察者 | 切换到另一个项目会注销不可见详情的观察者 | kernel 注册计数用 RAG Provider | 依次为两个项目构建详情区块 | 第一个项目的观察者被 cancel，Provider 中只剩一个存活观察者 | P1 | ✅ 已覆盖 | `switchingProjectCancelsInvisibleObserver` |
| 25 | AddProjectNoAutoSelect | select:false 且当前无项目时只入列、不得自动打开项目 | 隔离 Store + 记录用能力桩，当前无项目 | 创建真实目录后 `add(select:false)` | 不触发 openProject，currentProject 保持 nil，新项目入列 | P0 | ✅ 已覆盖 | `addWithoutSelectDoesNotOpenWhenNoCurrentProject` |
| 26 | AddProjectNoAutoSelect | select:false 保留已有当前项目，不打开新增项目 | 能力桩已有当前项目 | `add(select:false)` 新增另一目录 | 不触发 openProject，当前项目不变，列表增至 2 | P1 | ✅ 已覆盖 | `addWithoutSelectPreservesExistingCurrentProject` |
| 27 | AddProjectNoAutoSelect | select:true 仍会打开新增项目 | 隔离 Store + 记录用能力桩 | `add(select:true)` | openProject 以新增项目路径调用一次，currentProject 指向该项目 | P1 | ✅ 已覆盖 | `addWithSelectStillOpensAddedProject` |
| 28 | ProjectStorageDetector | 内置磁盘判定为 internalDisk | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `internalDiskKind` |
| 29 | ProjectStorageDetector | 外置设备判定为 externalDisk | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `externalDiskKind` |
| 30 | ProjectStorageDetector | 网络卷判定为 networkVolume | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `networkVolumeKind` |
| 31 | ProjectStorageDetector | 目录不存在判定为 missingDirectory | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `missingDirectoryKind` |
| 32 | ProjectStorageDetector | 卷属性读不到判定为 unreachableVolume | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `unreachableVolumeKind` |
| 33 | ProjectStorageDetector | 目录缺失与卷不可达互不混淆 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `missingDirectoryDiffersFromUnreachableVolume` |
| 34 | ProjectStorageDetector | 不可用状态使用特殊符号并被标记 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `unavailableStatesUseDistinctSymbols` |
| 35 | ProjectStorageDetector | 缓存命中后不再重复解析 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `cachedResultIsReused` |
| 36 | ProjectStorageDetector | 失效缓存后重新解析 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `invalidatedCacheIsReprobed` |
| 37 | ProjectStorageDetector | 真实路径判定为本机磁盘 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `realPathIsInternalDisk` |
| 38 | ProjectStorageDetector | 真实不存在路径判定为目录缺失 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `realMissingPathIsMissingDirectory` |
| 39 | ProjectStorageDetector | 目录删除后刷新能感知到缺失 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `deletedDirectoryIsDetectedAfterRefresh` |
| 40 | ProjectStorageRefresh | 刷新会递增存储状态修订号 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `refreshIncrementsRevision` |
| 41 | ProjectStorageRefresh | 刷新会清空探测缓存 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `refreshInvalidatesDetectorCache` |
| 42 | ProjectStorageRefresh | 仅不可用状态给出提示文案 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `hintOnlyForUnavailableStates` |
| 43 | ProjectLastUsed | 启动首次同步保留持久化的 lastUsed，不得重置为启动时刻 | 隔离 Store 持久化两个旧时间项目，当前项目为空 | `syncFromProvider(persist:false)` | 各项目 lastUsed 等于持久化旧值 | P0 | ✅ 已覆盖 | `firstSyncPreservesPersistedLastUsed` |
| 44 | ProjectLastUsed | 选中项目推进其 lastUsed，未选中项目不被刷新 | 隔离 Store + 能力桩，先同步空当前再选中 A | 两次 `syncFromProvider` | A 与当前快照 lastUsed 推进，B 保持旧值 | P0 | ✅ 已覆盖 | `selectionAdvancesLastUsed` |
| 45 | ProjectLastUsed | 当前项目不变时重复同步不得再次推进 lastUsed | 能力桩当前项目恒为 A | 连续两次 `syncFromProvider` | 两次 lastUsed 相等 | P1 | ✅ 已覆盖 | `resyncWithUnchangedCurrentDoesNotAdvance` |

> 说明：全部 **45 条场景**已在本包 `swift test` 中实跑通过。
> 用例名与描述取自 `Tests/` 下的真实 `@Test` 声明，改动测试时须同步本表。
>
> 回归 #475 变异验证：M1 在 `add(select:false)` 分支重新加入「`currentProject == nil` 时自动 `openProject`」→ `addWithoutSelectDoesNotOpenWhenNoCurrentProject` 失败（`openedPaths` 非空、`currentProject` 非 nil，RED）；M2 移除 `select:true` 分支的 `openProject` → `addWithSelectStillOpensAddedProject` 失败（RED）；还原后 45 条全绿。
>
> 回归 #476 变异验证：M1 把 `syncFromProvider` 的 `?? persistedLastUsed(for:) ?? Date()` 兜底改回 `?? Date()` → `firstSyncPreservesPersistedLastUsed` 失败（lastUsed 被重置为启动时刻，RED）；M2 移除「当前项目路径变化时推进 lastUsed」整段 → `selectionAdvancesLastUsed` 失败（RED）；M3 去掉 `current.path != previousCurrentPath` 守卫改为每次同步都推进 → `resyncWithUnchangedCurrentDoesNotAdvance` 失败（RED）；还原后 45 条全绿。

## 覆盖率统计

- P0: 已覆盖 8 / 8
- P1: 已覆盖 37 / 37
- P2: 已覆盖 0 / 0
- **合计: 45 / 45**（仅表示清单场景，非源码覆盖率）

## 优先级说明

- **P0**: 描述/名称含崩溃、泄漏、截断、丢失、竞态、超时、必须、不得、重试等失效类信号的用例（8 条）
- **P1**: 其余功能性用例（37 条）
- **P2**: 稳定常量、占位、文案、空集合等边界用例（0 条）

## 跨平台说明

- Package 声明: macOS 14+, iOS 17+
- 45 条用例位于 `Tests/`，需在目标平台执行 `swift test`

## 测试执行

```bash
cd Packages/PluginProjects
swift test
```

## 维护规则

1. **新增公开 API** → 先在 TestPlan 登记测试用例，再写实现
2. **Bug 修复** → 追加回归用例，标注触发条件
3. **删除用例** → 在 commit message 说明理由
4. **状态同步** → 实现后更新 TestPlan，标记 ✅ 并填写测试方法名
5. **改名同步** → 重命名 `@Test` 函数后必须同步本表，否则 `Scripts/verify-testplan.py` 会报「登记方法在源码不存在」
