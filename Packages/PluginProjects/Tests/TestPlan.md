# TestPlan — PluginProjects

## 包概述

PluginProjects 的实现包，包含 15 个主要类型；当前测试覆盖 55 条用例。

平台: macOS 14+, iOS 17+
测试文件: 14 个，用例总数: 59

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

- **ConversationProjectSyncObserver**（11 条）：由 `selectingConversationWithProjectOpensProject`、`selectingConversationWithoutProjectDoesNotOpen`、`deselectDoesNotOpenProject`、`externalOpenSurvivesLateConversationSync`、`userSelectedAfterExternalOpenReenablesSync`、`conversationSwitchAfterExternalOpenStillSwitches`、`restoreSelectionOpensProjectWithoutExternalOpen` 等用例锁定；改动该模块时优先跑对应测试文件。外部打开（`.externalOpen`）优先级高于对话联动，晚到的选中对话不得覆盖外部打开的项目（**回归 #131**）。
- **ProjectsAppRestore**（3 条）：由 `appRestoreYieldsToExternalOpen`、`appRestoreTaskRechecksAfterExternalOpen`、`appRestoreOpensStoredProjectWhenEmpty` 锁定启动恢复（`.appRestore`）必须在写入前重新校验 `currentProject == nil`，外部打开已设置项目时让位（**回归 #131**）；改动 `ProjectsPlugin.restoreCurrentProjectIfNeeded` 时优先跑对应测试文件。
- **ProjectsOpenedFilesWriteOrder**（5 条）：由 `writeRunsOffMainThread`、`staleWriteDoesNotOverwriteNewerSnapshot`、`continuousNavigationCoalescesWrites`、`rapidSavesLeaveLatestSnapshotOnDisk`、`cacheUpdatesBeforeWriteCompletes` 锁定打开文件快照后台串行合并写入、晚到旧快照不覆盖新状态（**回归 #1238**）；改动 `ProjectsStore.saveOpenedFiles` 时优先跑对应测试文件。
- **综合**（5 条）：由 `projectsPersistenceRoundTrip`、`openedFilesPersistenceRoundTrip`、`restoresAndPersistsOpenedFilesThroughProjectProviding` 等用例锁定；改动该模块时优先跑对应测试文件。
- **ProjectPathInjectionHook**（2 条）：由 `injectsConversationProject`、`skipsUnboundConversation` 等用例锁定；改动该模块时优先跑对应测试文件。
- **ListProjectsTool**（4 条）：由 `negativeLimitReturnsParameterError`、`zeroLimitReturnsParameterError`、`nonIntegerLimitReturnsParameterError`、`limitDefaultsAndCaps` 锁定；改动 limit 解析时优先跑对应测试文件。
- **AddProjectNoAutoSelect**（3 条）：由 `addWithoutSelectDoesNotOpenWhenNoCurrentProject`、`addWithoutSelectPreservesExistingCurrentProject`、`addWithSelectStillOpensAddedProject` 锁定 `add(select:false)` 只入列、不得自动打开项目（即使当前无项目），`select:true` 仍打开新增项目（**回归 #475**）；改动 `ProjectsViewModel.add` 时优先跑对应测试文件。
- **Projects 添加选中保留语言**（2 条，**回归 #477**）：由 `addWithSelectKeepsDetectedLanguage`、`addWithSelectStillOpensPlainDirectory` 锁定——`add(select:true)` 必须先把 store 探测到的语言随条目 `synchronizeProjects` 入列，再按路径打开，否则 Provider 会为该路径补一个无语言条目、UI 语言显示 Unknown；无特征文件目录仍正常打开（语言为 nil）。改动 `ProjectsViewModel.add` 的 shouldSelect 分支时优先跑对应测试文件。
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
| 46 | ConversationProjectSyncObserver | 外部打开的项目不会被随后到达的对话联动覆盖（**回归 #131**） | 绑定 cofficlab 的对话 + 记录用 Provider | 先 `.externalOpen` 打开 gitok，再取消并重新选中绑定对话 | 当前项目仍为 gitok，联动让位不打开 cofficlab | P0 | ✅ 已覆盖 | `externalOpenSurvivesLateConversationSync` |
| 47 | ConversationProjectSyncObserver | 外部打开后用户主动选择项目会恢复对话联动（**回归 #131**） | 绑定 cofficlab 的对话 + 记录用 Provider | `.externalOpen` 后再 `.userSelected` 打开 manual，再选中绑定对话 | 联动恢复，当前项目切到 cofficlab | P1 | ✅ 已覆盖 | `userSelectedAfterExternalOpenReenablesSync` |
| 48 | ProjectsAppRestore | 外部打开已设置项目时启动恢复直接让位不覆盖（**回归 #131**） | DefaultProjectProvider 已 `.externalOpen` 打开 gitok | 调用 `restoreCurrentProjectIfNeeded` 恢复 cofficlab | 当前项目仍为 gitok | P0 | ✅ 已覆盖 | `appRestoreYieldsToExternalOpen` |
| 49 | ProjectsAppRestore | 恢复 Task 排队期间外部打开抢先执行，Task 内部重新校验后让位（**回归 #131**） | 当前项目为空时调度恢复 Task | 恢复 Task 执行前先 `.externalOpen` 打开 gitok，再 await Task | 晚到的恢复 Task 不覆盖 gitok | P0 | ✅ 已覆盖 | `appRestoreTaskRechecksAfterExternalOpen` |
| 50 | ProjectsAppRestore | 仍无当前项目时启动恢复照常打开持久化项目（**回归 #131**） | DefaultProjectProvider 当前项目为空 | 调用 `restoreCurrentProjectIfNeeded` 恢复 cofficlab | 当前项目变为 cofficlab | P1 | ✅ 已覆盖 | `appRestoreOpensStoredProjectWhenEmpty` |
| 51 | ProjectsOpenedFilesWriteOrder | 编码与写入不在主线程执行（**回归 #1238**） | 隔离 Store + 记录用 writer | `saveOpenedFiles` 后检查落盘线程 | 写入不在主线程，磁盘内容为该快照 | P1 | ✅ 已覆盖 | `writeRunsOffMainThread` |
| 52 | ProjectsOpenedFilesWriteOrder | 晚到的旧快照不覆盖新快照（**回归 #1238**） | 门闩卡住第一份写入 | 旧快照写入挂起时提交新快照，再释放门闩 | 最后一次落盘为新快照，磁盘内容为新快照 | P0 | ✅ 已覆盖 | `staleWriteDoesNotOverwriteNewerSnapshot` |
| 53 | ProjectsOpenedFilesWriteOrder | 连续导航合并成一次写入（**回归 #1238**） | 门闩卡住首份写入 | 连续提交 6 份快照后释放门闩 | 仅 2 次落盘，磁盘内容为最新 step-5 | P1 | ✅ 已覆盖 | `continuousNavigationCoalescesWrites` |
| 54 | ProjectsOpenedFilesWriteOrder | 真实写入路径下最终磁盘内容是最新快照（**回归 #1238**） | 隔离 Store | 连续 30 次 `saveOpenedFiles` 后 await 最后一个 | 磁盘为 file-29，无 .tmp 残留 | P0 | ✅ 已覆盖 | `rapidSavesLeaveLatestSnapshotOnDisk` |
| 55 | ProjectsOpenedFilesWriteOrder | 内存缓存立即更新不等磁盘写入（**回归 #1238**） | 门闩卡住写入 | 写入挂起时读取缓存与修订号 | 缓存已为 pending 快照，修订号为 1 | P1 | ✅ 已覆盖 | `cacheUpdatesBeforeWriteCompletes` |
| 56 | ConversationProjectSyncObserver | 外部打开项目之后，用户切换对话仍应切换到对话绑定项目 | 绑定 cofficlab 的对话，先有外部打开历史 | 用户主动选中该对话 | 联动切换项目到 cofficlab，currentProject 指向 cofficlab | P1 | ✅ 已覆盖 | `conversationSwitchAfterExternalOpenStillSwitches` |
| 57 | ConversationProjectSyncObserver | 启动恢复的选中对话在没有外部打开时仍会联动打开项目 | 启动恢复流程 + 选中对话绑定 cofficlab，无外部打开 | 执行启动恢复 | 联动打开 cofficlab | P1 | ✅ 已覆盖 | `restoreSelectionOpensProjectWithoutExternalOpen` |
| 58 | Projects 添加选中保留语言 | select:true 打开新增项目时保留已检测的语言（**回归 #477**） | 隔离 Store + 模拟 Provider 语义的能力桩，目录含 `Package.swift` | `add(select:true)` 新增并打开 | Provider 列表条目与 currentProject 均携带 `swift` | P0 | ✅ 已覆盖 | `addWithSelectKeepsDetectedLanguage` |
| 59 | Projects 添加选中保留语言 | select:true 对无特征文件的项目仍正常打开（语言为 nil） | 隔离 Store + 能力桩，目录无特征文件 | `add(select:true)` 新增并打开 | 正常打开，语言为 nil | P1 | ✅ 已覆盖 | `addWithSelectStillOpensPlainDirectory` |

> 说明：全部 **59 条场景**已在本包 `swift test` 中实跑通过。
> 用例名与描述取自 `Tests/` 下的真实 `@Test` 声明，改动测试时须同步本表。
> ID 56/57 为补登的历史用例（`ConversationProjectSyncObserverTests` 此前未登记）。
> ID 58/59 为本轮新增的语言保留回归用例（`ProjectsAddSelectedLanguageTests`，见 #477）。
> #477 回归：`add(select:true)` 此前只按路径 `openProject`，Provider 为该路径构造无语言的 `ProjectInfo`，store 已探测到的语言被丢弃（UI 显示 Unknown）。修复在打开前先把带语言的条目 `synchronizeProjects` 入列（与 select:false 分支一致）。变异验证（还原为纯路径 openProject）令 `addWithSelectKeepsDetectedLanguage` 转红（Provider 列表与 currentProject 语言均为 nil）；还原后 59 条全绿。
>
> 回归 #475 变异验证：M1 在 `add(select:false)` 分支重新加入「`currentProject == nil` 时自动 `openProject`」→ `addWithoutSelectDoesNotOpenWhenNoCurrentProject` 失败（`openedPaths` 非空、`currentProject` 非 nil，RED）；M2 移除 `select:true` 分支的 `openProject` → `addWithSelectStillOpensAddedProject` 失败（RED）；还原后 45 条全绿。
>
> 回归 #476 变异验证：M1 把 `syncFromProvider` 的 `?? persistedLastUsed(for:) ?? Date()` 兜底改回 `?? Date()` → `firstSyncPreservesPersistedLastUsed` 失败（lastUsed 被重置为启动时刻，RED）；M2 移除「当前项目路径变化时推进 lastUsed」整段 → `selectionAdvancesLastUsed` 失败（RED）；M3 去掉 `current.path != previousCurrentPath` 守卫改为每次同步都推进 → `resyncWithUnchangedCurrentDoesNotAdvance` 失败（RED）；还原后 45 条全绿。
>
> 回归 #131 变异验证：M1 移除 `restoreCurrentProjectIfNeeded` 内的 `guard currentProject == nil` → `appRestoreYieldsToExternalOpen` 与 `appRestoreTaskRechecksAfterExternalOpen` 失败（外部打开的 gitok 被 cofficlab 覆盖，RED），`appRestoreOpensStoredProjectWhenEmpty` 仍绿；M2 移除 `ConversationProjectSyncObserver` 的 `guard lastProjectChangeReason != .externalOpen` → `externalOpenSurvivesLateConversationSync` 失败（联动打开 cofficlab 覆盖 gitok，RED），`userSelectedAfterExternalOpenReenablesSync` 仍绿；还原后 55 条全绿。

## 覆盖率统计

- P0: 已覆盖 14 / 14
- P1: 已覆盖 45 / 45
- P2: 已覆盖 0 / 0
- **合计: 59 / 59**（仅表示清单场景，非源码覆盖率）

## 优先级说明

- **P0**: 描述/名称含崩溃、泄漏、截断、丢失、竞态、超时、必须、不得、重试等失效类信号的用例（14 条）
- **P1**: 其余功能性用例（45 条）
- **P2**: 稳定常量、占位、文案、空集合等边界用例（0 条）

## 跨平台说明

- Package 声明: macOS 14+, iOS 17+
- 59 条用例位于 `Tests/`，需在目标平台执行 `swift test`

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
