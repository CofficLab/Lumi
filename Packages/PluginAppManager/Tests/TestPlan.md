# TestPlan — PluginAppManager

## 包概述

AppManagerPlugin Manage installed applications for Lumi.

平台: macOS 14+, iOS 17+
测试文件: 5 个，用例总数: 44

核心组件（源码目录）:
- `Models/`
- `Services/`
- `ViewModels/`
- `Views/`

## 公开 API

包内主要类型（按声明顺序抽取，供定位被测对象）:

- `AppManagerPluginSupport`
- `PluginAppManagerLocalization`
- `AppCacheItem`
- `AppModel`
- `RelatedFile`
- `AppCleanerHelper`
- `AppService`
- `CacheStats`
- `AppManagerServicing`
- `AppSearchMembership`
- `ActionBar`
- `AppManagerAboutView`
- `AppManagerDetailView`
- `AppManagerManualView`
- `AppManagerScanningView`

## 关键行为契约（实现约定，非协议要求）

按测试模块归纳，改动对应模块时须保持既有断言成立:

- **综合**（13 条）：由 `v2PluginStateIsStable`、`activatingPluginHidesChatSectionAndDeactivatingRestoresIt`、`localizationCatalogIsPackaged` 等用例锁定；改动该模块时优先跑对应测试文件。其中关联文件扫描的路径穿越防护（`untrustedBundleNameCannotEscapeApplicationSupport`、`emptyBundleNameDoesNotSelectApplicationSupportRoot`、`pathContainmentRejectsEscapesAndDirectoryItself`、`untrustedBundleIdentifierCannotEscapeLibrary`、`validBundleIdentifierStillMatchesLibraryFiles`）要求：CFBundleName 与 CFBundleIdentifier 都必须是安全单路径分量（`AppModel.isValidPathComponent`），且每个候选路径 standardized 后仍位于对应 Library 子目录内（`AppService.isContained`），越界条目不得返回或删除；合法 Bundle ID 仍须正常命中（**回归 #211**）。
- **卸载归属保护**（4 条）：由 `nameOnlySupportMatchIsNotOwnershipVerified`、`bundleIdSupportMatchIsOwnershipVerified`、`defaultSelectionExcludesUnverifiedNameOnlyMatch`、`defaultSelectionIncludesVerifiedBundleIdMatch` 锁定（**回归 #647**）：仅凭 `CFBundleName` 同名匹配到的 Application Support 目录无法证明归属，`RelatedFile.ownershipVerified` 须为 false，卸载默认勾选不得包含它（避免误删其它厂商数据）；精确 Bundle ID 命中的目录归属确认（true）且仍须默认勾选；App 本体始终确认。改动 `AppService.scanRelatedFiles` 策略 B、`RelatedFile.ownershipVerified` 或 `AppManagerViewModel.scanRelatedFiles` 的默认勾选时优先跑对应测试。
- **无 Bundle ID 仍可卸载**（2 条）：由 `nilBundleIdentifierStillListsAppItselfForUninstall`、`nilBundleIdentifierAppIsSelectedForUninstallByDefault` 锁定（**回归 #794**）：`AppService.scanRelatedFiles` 必须先加入 App 本体再判断 Bundle ID；缺少 Bundle ID 时跳过依赖标识符的 Library 扫描，但仍须返回 App 本体（`type == .app`、`ownershipVerified == true`），使 `AppManagerViewModel` 默认勾选包含它、卸载入口可用（此前早返回 `[]` 导致无 Bundle ID 的应用无法卸载）。改动 `scanRelatedFiles` 的早返回分支或默认勾选时优先跑对应测试。
- **搜索成员缓存**（5 条）：由 `sizeOnlyUpdatesDoNotRerunLocalizedSearch`、`queryChangeRerunsLocalizedSearch`、`membershipChangeRerunsLocalizedSearch`、`emptyQueryReturnsAllAppsAndReflectsSizes`、`searchMatchesNameAndBundleIDCaseInsensitively` 锁定（**回归 #1220**）：刷新时 `performScan` 逐个回填 App 大小并多次重发 `installedApps`，搜索过滤不得在每次「仅大小变化」的重发上重跑 N 次本地化名称/Bundle ID 匹配（此前 O(N²) 主线程卡顿）。`AppSearchMembership.filtered(query:apps:)` 以「查询串 + 可搜索投影（path/displayName/bundleIdentifier，**不含 size**）」为键缓存命中集合：仅大小变化时复用缓存（`recomputeCount` 不增），输出仍按 path 成员重建并反映最新 size；查询串或成员变化时才重算；空查询返回全部并反映 size；名称与 Bundle ID 均大小写不敏感匹配。改动 `AppSearchMembership` 的键、缓存判定或 `AppManagerViewModel` 搜索管道时优先跑对应测试。
- **列表可用性**（3 条）：由 `listLoadingEndsWhenAppsPublishedWhileSizingContinues`、`initialEnumerationKeepsBlockingLoadingUntilAppsPublished`、`staleSizingCompletionDoesNotClobberNewerScanState` 锁定（**回归 #1221**）：`performScan` 枚举完成、发布 `installedApps` 后必须立即结束阻塞态 `isLoading`（`AppRailView` 仅在 `isLoading` 时用 overlay 替换整个列表），大小计算改用独立的 `isCalculatingSizes` 进度态，使已就绪的应用在逐个回填大小期间即可见、可选；阻塞 overlay 只保留给初始枚举阶段。`isLoading`/`isCalculatingSizes` 的写回与清理都受 `activeScanID == scanID` 身份校验保护：被取消的旧扫描晚到完成时不得覆盖新扫描的列表/加载/计算状态。改动 `performScan` 的加载态切换、`isCalculatingSizes` 或 `AppRailView` 列表 gating 时优先跑对应测试。
- **部分删除失败与重试**（7 条）：由 `deleteFilesSkipsAlreadyMissingItemsSoRetryIsNotBlocked`、`deleteFilesContinuesPastFailureAndReportsPartial`、`partialDeletionRemovesDeletedItemsAndKeepsFailedForRetry`、`retryAfterPartialFailureClearsRemainingAndCompletes`、`successfulExtraOnlyDeletionKeepsAppAndRescans`、`completeAppDeletionRemovesAppAndClearsSelection`、`staleDeletionResultDoesNotPolluteNewSelection` 锁定（**回归 #410**）：`AppService.deleteFiles` 必须逐项处理、不再「首错即抛」——已不存在的条目视为删除成功（跳过），单项 `trashItem` 失败只记入 `DeleteFilesResult.failed` 并继续处理后续条目，返回 `deleted`/`failed` 两组结果而非抛错。`AppManagerViewModel.deleteSelectedFiles` 拿到结果后立即从 `relatedFiles`/`selectedFileIds` 移除已删项、App 本体被删时从 `installedApps` 移除；失败项保留勾选以便重试（此前整批抛错后 UI 仍显示已删的 App 与文件，重试指向不存在的 App 路径而永久卡死）。写回受 `selectedApp?.bundleURL.path == appPath` 身份校验保护：删除进行中切换到别的 App 后，旧结果不得污染新选中项。改动 `deleteFiles` 的逐项/跳过/结果聚合或 `deleteSelectedFiles`/`applyDeletionResult` 的写回与身份校验时优先跑对应测试。
- **刷新选择协调**（4 条）：由 `refreshRemapsSelectionToNewModelByPath`、`refreshClearsSelectionWhenAppRemovedExternally`、`refreshClearsRemovedSelectionEvenWhenListNonEmpty`、`refreshPreservesRelatedFilesWhenAppStillExists` 锁定（**回归 #795**）：刷新用全新构造的 `AppModel`（每个 `id` 都是新 UUID）替换 `installedApps`，而行高亮按 `selectedApp?.id == app.id` 比较，故 `performScan` 发布新列表后必须调用 `reconcileSelection(with:)` 按稳定的 `bundleURL.path` 协调选中项——仍存在则 remap 到新模型（恢复行高亮与详情一致，且因 `AppModel.==` 按 path 相等，`AppManagerView.onChange(of: selectedApp)` 不会触发重扫，关联文件与待删除勾选保持不变）；已被外部移除则 `cancelSelection()` 清空选择/详情/关联文件/待删除勾选/确认弹窗，即使列表仍非空也不得残留矛盾状态。改动 `performScan` 发布列表后的协调、`reconcileSelection` 的 path 匹配或清空分支时优先跑对应测试。
- **应用发现范围**（4 条）：由 `scanFindsAppsInsideUtilitiesContainer`、`discoveryStopsAtOneLevelAndNeverEntersAppBundles`、`discoveryStillReturnsDirectAppChildren`、`discoverySkipsHiddenEntries` 锁定（**回归 #648**）：`AppService.scanInstalledApps` 必须经 `AppService.appBundleURLs(under:)` 枚举每个根——除直接 `.app` 子项外，还要下降标准应用容器子目录（`Utilities`，名称大小写不敏感）一层，使 `/System/Applications/Utilities` 的 Terminal/活动监视器/控制台与 `/Applications/Utilities` 内的工具可被发现和管理；下降只限这一层，不得进入 `.app` 包内部、不得递归任意目录树（`Other/`、`Utilities/Nested/` 里的包不算应用来源），根与容器内的隐藏条目都跳过，空容器不影响直接子项。改动 `appBundleURLs`、`applicationContainerDirectoryNames` 或 `scanInstalledApps` 的枚举入口时优先跑对应测试。

## 测试用例清单

| ID | 类别 | 描述 | 前置条件 | 操作步骤 | 预期结果 | 优先级 | 状态 | 测试方法 |
|----|------|------|----------|----------|----------|------|------|----------|
| 1 | 综合 | v2PluginStateIsStable | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `v2PluginStateIsStable` |
| 2 | 综合 | activatingPluginHidesChatSectionAndDeactivatingRestoresIt | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `activatingPluginHidesChatSectionAndDeactivatingRestoresIt` |
| 3 | 综合 | localizationCatalogIsPackaged | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `localizationCatalogIsPackaged` |
| 4 | 综合 | directoryURLSupportsSpacesAndSpecialCharacters | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `directoryURLSupportsSpacesAndSpecialCharacters` |
| 5 | 综合 | appCleanerReturnsNoRelatedFilesWhenLibraryDirectoryIsUnavailable | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `appCleanerReturnsNoRelatedFilesWhenLibraryDirectoryIsUnavailable` |
| 6 | 综合 | cacheStoreRecoversWhenDatabaseDirectoryIsBlocked | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `cacheStoreRecoversWhenDatabaseDirectoryIsBlocked` |
| 7 | 综合 | cacheManagerReportsPersistenceResults | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `cacheManagerReportsPersistenceResults` |
| 8 | 综合 | cancelledScanDoesNotClearLoadingForNewerScan | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `cancelledScanDoesNotClearLoadingForNewerScan` |
| 9 | 综合 | untrustedBundleNameCannotEscapeApplicationSupport | 临时 home，恶意 CFBundleName 含 `../` | 扫描关联文件 | 不返回 Application Support 之外的路径 | P0 | ✅ 已覆盖 | `untrustedBundleNameCannotEscapeApplicationSupport` |
| 10 | 综合 | emptyBundleNameDoesNotSelectApplicationSupportRoot | 临时 home，CFBundleName 为空 | 扫描关联文件 | 不返回 Application Support 根目录 | P0 | ✅ 已覆盖 | `emptyBundleNameDoesNotSelectApplicationSupportRoot` |
| 11 | 综合 | pathContainmentRejectsEscapesAndDirectoryItself | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `pathContainmentRejectsEscapesAndDirectoryItself` |
| 12 | 综合 | untrustedBundleIdentifierCannotEscapeLibrary（**回归 #211**） | 临时 home，恶意 CFBundleIdentifier 含 `../`，Documents 下放置目录/plist/savedState 无辜目标 | 扫描关联文件 | 不返回任何 Documents 路径，无辜目标不被删除 | P0 | ✅ 已覆盖 | `untrustedBundleIdentifierCannotEscapeLibrary` |
| 13 | 综合 | validBundleIdentifierStillMatchesLibraryFiles（**回归 #211**） | 临时 home，合法 CFBundleIdentifier `com.example.app` | 扫描关联文件 | 仍命中 Application Support 目录、Preferences plist、Saved State | P1 | ✅ 已覆盖 | `validBundleIdentifierStillMatchesLibraryFiles` |

### 卸载归属保护（回归 #647）

| ID | 类别 | 描述 | 前置条件 | 操作步骤 | 预期结果 | 优先级 | 状态 | 测试方法 |
|----|------|------|----------|----------|----------|------|------|----------|
| 14 | 卸载归属保护 | 仅同名匹配的 Application Support 目录归属未确认（回归 #647） | 厂商 A 无精确 Bundle ID 目录，存在它厂商同名 `Notes` 目录 | 扫描厂商 A 关联文件 | 同名目录仍列出但 ownershipVerified=false，App 本体为 true | P0 | ✅ 已覆盖 | `nameOnlySupportMatchIsNotOwnershipVerified` |
| 15 | 卸载归属保护 | 精确 Bundle ID 命中的目录归属确认（回归 #647） | 存在 `com.vendor-b.notes` 精确目录与同名 `Notes` 目录 | 扫描厂商 B 关联文件 | 精确目录 ownershipVerified=true，同名目录不再作为关联文件 | P1 | ✅ 已覆盖 | `bundleIdSupportMatchIsOwnershipVerified` |
| 16 | 卸载归属保护 | 默认勾选排除未确认归属的同名目录（回归 #647） | 同 14，注入临时 home 的 AppService | ViewModel 扫描关联文件 | 默认勾选不含同名目录，但含 App 本体 | P0 | ✅ 已覆盖 | `defaultSelectionExcludesUnverifiedNameOnlyMatch` |
| 17 | 卸载归属保护 | 默认勾选仍包含归属确认的精确匹配（回归 #647） | 存在精确 Bundle ID 目录 | ViewModel 扫描关联文件 | 精确匹配目录被默认勾选，过滤不误伤合法关联文件 | P1 | ✅ 已覆盖 | `defaultSelectionIncludesVerifiedBundleIdMatch` |

### 无 Bundle ID 仍可卸载（回归 #794）

| ID | 类别 | 描述 | 前置条件 | 操作步骤 | 预期结果 | 优先级 | 状态 | 测试方法 |
|----|------|------|----------|----------|----------|------|------|----------|
| 18 | 无 Bundle ID 卸载 | 无 Bundle ID 仍列出 App 本体（回归 #794） | 临时 home，Info.plist 缺少 CFBundleIdentifier 的应用 | 扫描关联文件 | 必须返回 App 本体（type=.app，ownershipVerified=true），且仅 1 条 | P0 | ✅ 已覆盖 | `nilBundleIdentifierStillListsAppItselfForUninstall` |
| 19 | 无 Bundle ID 卸载 | 无 Bundle ID 的 App 默认勾选可卸载（回归 #794） | 同 18，注入临时 home 的 AppService | ViewModel 扫描关联文件 | 默认勾选包含 App 本体，卸载按钮可用 | P1 | ✅ 已覆盖 | `nilBundleIdentifierAppIsSelectedForUninstallByDefault` |

### 搜索成员缓存（回归 #1220）

| ID | 类别 | 描述 | 前置条件 | 操作步骤 | 预期结果 | 优先级 | 状态 | 测试方法 |
|----|------|------|----------|----------|----------|------|------|----------|
| 20 | 搜索成员缓存 | 仅大小变化不得重跑本地化搜索（回归 #1220） | Alpha/Beta/Gamma 三个 App，查询 `alpha` | 首次过滤后模拟 20 轮逐 App 大小回填重发 | 每轮结果仍为 `["Alpha"]` 且反映最新 size，`recomputeCount` 始终为 1 | P0 | ✅ 已覆盖 | `sizeOnlyUpdatesDoNotRerunLocalizedSearch` |
| 21 | 搜索成员缓存 | 查询串变化才重算命中集合（回归 #1220） | Alpha/Beta 两个 App | 先查 `alpha` 再查 `beta` | 结果分别为 `["Alpha"]`/`["Beta"]`，`recomputeCount` 由 1 增至 2 | P1 | ✅ 已覆盖 | `queryChangeRerunsLocalizedSearch` |
| 22 | 搜索成员缓存 | 成员变化才重算命中集合（回归 #1220） | Alpha/Beta，查询 `alpha` | 追加 Alphabet 后再次过滤 | 结果为 `["Alpha","Alphabet"]`，`recomputeCount` 由 1 增至 2 | P1 | ✅ 已覆盖 | `membershipChangeRerunsLocalizedSearch` |
| 23 | 搜索成员缓存 | 空查询返回全部并反映最新大小（回归 #1220） | Alpha/Beta 两个 App，查询为空 | 首次过滤后回填 Alpha size=4096 再过滤 | 两次均返回 2 个 App，第二次首项 size=4096，`recomputeCount` 始终为 1 | P1 | ✅ 已覆盖 | `emptyQueryReturnsAllAppsAndReflectsSizes` |
| 24 | 搜索成员缓存 | 名称与 Bundle ID 大小写不敏感匹配（回归 #1220） | Alpha(com.test.alpha)/Beta(com.test.beta) | 分别查 `ALPHA`、`COM.TEST.BETA`、`zzz` | 依次命中 `["Alpha"]`、`["Beta"]`、空集 | P1 | ✅ 已覆盖 | `searchMatchesNameAndBundleIDCaseInsensitively` |

### 列表可用性（回归 #1221）

| ID | 类别 | 描述 | 前置条件 | 操作步骤 | 预期结果 | 优先级 | 状态 | 测试方法 |
|----|------|------|----------|----------|----------|------|------|----------|
| 25 | 列表可用性 | 列表发布后必须立即结束阻塞态，大小计算期间列表可见（回归 #1221） | Alpha/Beta 两个未缓存 App，大小门闩挂起 | 扫描发布列表后观察中间态，再释放门闩 | `isLoading=false`、`installedApps=["Alpha","Beta"]`、`isCalculatingSizes=true`；释放后大小回填为 4096/8192 且 `isCalculatingSizes=false` | P0 | ✅ 已覆盖 | `listLoadingEndsWhenAppsPublishedWhileSizingContinues` |
| 26 | 列表可用性 | 初始枚举阶段仍保留阻塞 overlay（回归 #1221） | 枚举门闩挂起，单个未缓存 App | 枚举未完成时观察，再依次释放枚举/大小门闩 | 枚举期 `isLoading=true`、列表空、`isCalculatingSizes=false`；枚举完成后 `isLoading=false`、`isCalculatingSizes=true`；大小完成后归位 | P1 | ✅ 已覆盖 | `initialEnumerationKeepsBlockingLoadingUntilAppsPublished` |
| 27 | 列表可用性 | 旧扫描大小计算晚到不得覆盖新扫描状态（回归 #1221） | 旧/新扫描各有枚举与大小门闩 | 旧扫描进入大小计算后启动新扫描接管，再释放旧大小门闩 | 旧扫描晚到完成后 `installedApps` 仍为 `["Fresh"]`（size 未被写入 100）、`isLoading=false`、`isCalculatingSizes=true`；新扫描完成后 size=200 | P0 | ✅ 已覆盖 | `staleSizingCompletionDoesNotClobberNewerScanState` |

### 部分删除失败与重试（回归 #410）

| ID | 类别 | 描述 | 前置条件 | 操作步骤 | 预期结果 | 优先级 | 状态 | 测试方法 |
|----|------|------|----------|----------|----------|------|------|----------|
| 28 | 部分删除失败与重试 | 已不存在的条目视为删除成功，重试不被阻塞（回归 #410） | 真实 AppService，首项路径已缺失、尾项存在 | 调用 deleteFiles | 全部计入 deleted、failed 为空，不抛错 | P0 | ✅ 已覆盖 | `deleteFilesSkipsAlreadyMissingItemsSoRetryIsNotBlocked` |
| 29 | 部分删除失败与重试 | 单项失败不中断整批，逐项报告部分结果（回归 #410） | 真实 AppService，appDir + 置 immutable 的 lockedFile + tailFile | 调用 deleteFiles | deleted=[app,tail]、failed=[locked]，失败后续项仍被处理 | P0 | ✅ 已覆盖 | `deleteFilesContinuesPastFailureAndReportsPartial` |
| 30 | 部分删除失败与重试 | 部分失败后移除已删项、保留失败项供重试（回归 #410） | fake：deleted=[appFile,support]、failed=[cache] | ViewModel 删除选中项 | installedApps 失去 App、relatedFiles=[cache]、selectedFileIds=Set([cache.id])、selectedApp 保留、errorMessage 非空 | P0 | ✅ 已覆盖 | `partialDeletionRemovesDeletedItemsAndKeepsFailedForRetry` |
| 31 | 部分删除失败与重试 | 重试仅针对剩余失败项并完成清理（回归 #410） | fake handler 按是否含 .app 分支 | 部分失败后再次删除 | 第二次 deleteFiles 入参==[cache]，最终 selectedApp=nil、relatedFiles 空、errorMessage=nil | P0 | ✅ 已覆盖 | `retryAfterPartialFailureClearsRemainingAndCompletes` |
| 32 | 部分删除失败与重试 | 仅删附加项成功时保留 App 并重扫（回归 #410） | 仅勾选 support，App 本体仍在 | ViewModel 删除选中项 | App 保留，relatedFiles 重扫为 refreshed=[appFile] | P1 | ✅ 已覆盖 | `successfulExtraOnlyDeletionKeepsAppAndRescans` |
| 33 | 部分删除失败与重试 | 完整删除 App 后移除 App 并清空选中（回归 #410） | 勾选含 App 本体且全部删除成功 | ViewModel 删除选中项 | installedApps 失去 App、selectedApp=nil、relatedFiles 空、selectedFileIds 空 | P1 | ✅ 已覆盖 | `completeAppDeletionRemovesAppAndClearsSelection` |
| 34 | 部分删除失败与重试 | 删除进行中切换 App，旧结果不得污染新选中（回归 #410） | DeletionGate 挂起，selectedApp A→B | 释放旧删除门闩 | B 的 relatedFiles/selectedFileIds/installedApps 不被旧结果改写 | P0 | ✅ 已覆盖 | `staleDeletionResultDoesNotPolluteNewSelection` |

### 刷新选择协调（回归 #795）

| ID | 类别 | 描述 | 前置条件 | 操作步骤 | 预期结果 | 优先级 | 状态 | 测试方法 |
|----|------|------|----------|----------|----------|------|------|----------|
| 35 | 刷新选择协调 | 刷新后按 path 把选中映射到新模型，恢复行高亮（回归 #795） | force:false→[old]、force:true→[new]，同 path 不同 id | 选中 old 后刷新 | selectedApp.id==installedApps[0].id 且 !=oldID，path 不变 | P0 | ✅ 已覆盖 | `refreshRemapsSelectionToNewModelByPath` |
| 36 | 刷新选择协调 | 应用被外部移除后刷新清空选择与详情（回归 #795） | force:false→[alpha]、force:true→[]，已置关联文件/勾选/确认弹窗 | 选中 alpha 后刷新 | selectedApp=nil、relatedFiles/selectedFileIds 空、showUninstallConfirmation=false、isScanningFiles=false | P0 | ✅ 已覆盖 | `refreshClearsSelectionWhenAppRemovedExternally` |
| 37 | 刷新选择协调 | 列表仍非空时被移除的选中项仍须清空（回归 #795） | force:false→[alpha,beta]、force:true→[alphaNew] | 选中 beta 后刷新 | installedApps==[alpha]、selectedApp=nil、relatedFiles/selectedFileIds 空 | P1 | ✅ 已覆盖 | `refreshClearsRemovedSelectionEvenWhenListNonEmpty` |
| 38 | 刷新选择协调 | 应用仍在时仅 remap 选中，保留关联文件与勾选（回归 #795） | force:false→[old]、force:true→[new]，已置关联文件/勾选 | 选中 old 后刷新 | selectedApp.id==installedApps[0].id，relatedFiles/selectedFileIds 保持不变 | P1 | ✅ 已覆盖 | `refreshPreservesRelatedFilesWhenAppStillExists` |
| 39 | 应用发现范围 | 扫描必须发现 Utilities 容器内的应用（回归 #648） | 临时根含 Top.app、Utilities/Terminal.app、Utilities/Activity Monitor.app，注入独立缓存库 | AppService.scanInstalledApps(force: true) | displayName 集合=={Top, Terminal, Activity Monitor}，Terminal 的 bundleURL 解析符号链接后指向 Utilities 子目录 | P0 | ✅ 已覆盖 | `scanFindsAppsInsideUtilitiesContainer` |
| 40 | 应用发现范围 | 只下降容器一层，不得进入 .app 包或任意目录（回归 #648） | 根含 Top.app、Utilities/Terminal.app、Utilities/Nested/Deep.app、Other/Stray.app、Top.app/Contents/Inner.app | AppService.appBundleURLs(under:) | 仅返回 {Top.app, Terminal.app}，更深层/非容器/包内部条目均不出现 | P0 | ✅ 已覆盖 | `discoveryStopsAtOneLevelAndNeverEntersAppBundles` |
| 41 | 应用发现范围 | 空容器不影响直接子项的既有发现（回归 #648） | 根含 Direct.app 与空的 Utilities 目录 | AppService.appBundleURLs(under:) | 返回 [Direct.app] | P1 | ✅ 已覆盖 | `discoveryStillReturnsDirectAppChildren` |
| 42 | 应用发现范围 | 隐藏条目在根与容器内都被跳过（回归 #648） | 根含 Visible.app、.Hidden.app、Utilities/Console.app、Utilities/.Secret.app | AppService.appBundleURLs(under:) | 仅返回 {Visible.app, Console.app} | P1 | ✅ 已覆盖 | `discoverySkipsHiddenEntries` |
| 43 | 体积统计 | 目录体积必须包含 .app 包内的隐藏文件（**回归 #796**） | 临时目录含 Contents/Resources/visible.bin 与 .payload | AppService.calculateSize(for:) | 返回值 == 可见 + 隐藏内容字节之和 | P0 | ✅ 已覆盖 | `sizeIncludesHiddenFilesInsideBundle` |
| 44 | 体积统计 | 隐藏目录的子孙文件同样计入体积（**回归 #796**） | 临时目录含 Contents/.cache/nested/deep.bin | AppService.calculateSize(for:) | 返回值 == deep.bin 字节数 | P1 | ✅ 已覆盖 | `sizeIncludesDescendantsOfHiddenDirectories` |

> 说明：全部 **42 条场景**已在本包 `swift test` 中实跑通过。
> 用例名与描述取自 `Tests/` 下的真实 `@Test` 声明，改动测试时须同步本表。

> 变异验证（#794）：把 `AppService.scanRelatedFiles` 无 Bundle ID 分支的 `return relatedFiles` 改回 `return []`（恢复缺陷），`nilBundleIdentifierStillListsAppItselfForUninstall`、`nilBundleIdentifierAppIsSelectedForUninstallByDefault` 两条转红（扫描结果为空、拿不到 App 本体），其余 17 条（合法 Bundle ID / 路径穿越 / 归属保护 / 缓存 / 插件状态）保持绿；还原后 19 条全绿。

> 变异验证（#1220，`AppSearchMembership.filtered`）：
> - **M1** 缓存判定 `if query != lastQuery || keys != lastKeys` 改为 `if true`（每次重算，复现 O(N²)）→ `sizeOnlyUpdatesDoNotRerunLocalizedSearch`、`emptyQueryReturnsAllAppsAndReflectsSizes` 转红（`recomputeCount != 1`），其余 3 条仍绿。
> - **M2** 把 `size` 加入 `Key` 与投影（大小变化即触发重算）→ 同上两条转红（`recomputeCount != 1`），其余 3 条仍绿。
> - **M3** 忽略缓存命中集合、末尾直接 `return apps`（不过滤）→ `sizeOnlyUpdatesDoNotRerunLocalizedSearch`、`queryChangeRerunsLocalizedSearch`、`membershipChangeRerunsLocalizedSearch`、`searchMatchesNameAndBundleIDCaseInsensitively` 四条转红（结果含未命中项），`emptyQueryReturnsAllAppsAndReflectsSizes` 仍绿。
> - 还原完整修复 → 24 条全绿。

> 变异验证（#1221，`AppManagerViewModel.performScan`）：
> - **M1** 删除发布 `installedApps` 后的 `isLoading = false`（恢复「列表就绪仍被 overlay 遮蔽」缺陷）→ `listLoadingEndsWhenAppsPublishedWhileSizingContinues`、`initialEnumerationKeepsBlockingLoadingUntilAppsPublished`、`staleSizingCompletionDoesNotClobberNewerScanState` 三条转红（`waitFor { !isLoading }` 超时、`isLoading` 仍为 true）。
> - **M2** 把 `defer` 中的 `isCalculatingSizes = false` 移出 `activeScanID == scanID` 身份校验（旧扫描收尾无条件清进度态）→ `staleSizingCompletionDoesNotClobberNewerScanState` 转红（旧大小门闩晚到释放后 `isCalculatingSizes` 被误清为 false），其余 2 条仍绿。
> - **M3** 发布后把 `isCalculatingSizes = apps.contains { $0.size == 0 }` 改为 `isCalculatingSizes = false`（不进入大小进度态）→ 三条全部转红（中间态 `isCalculatingSizes == true` 断言失败）。
> - 还原完整修复 → 27 条全绿。

> 变异验证（#410，`AppService.deleteFiles` / `AppManagerViewModel.applyDeletionResult`）：
> - **M1** 在 `failed.append(...)` 后加 `break`（恢复「首错即中断整批」缺陷）→ `deleteFilesContinuesPastFailureAndReportsPartial` 转红（失败项之后的 tailFile 未被处理，deleted 缺失），其余仍绿。
> - **M2** 删除「已不存在则视为删除成功」的 guard-skip 分支（缺失项落入 trashItem 失败）→ `deleteFilesSkipsAlreadyMissingItemsSoRetryIsNotBlocked` 转红（缺失首项被记入 failed），其余仍绿。
> - **M3** 删除 `applyDeletionResult` 中 `relatedFiles.removeAll { deletedIds.contains($0.id) }` 与 `selectedFileIds.subtract(deletedIds)`（已删项不从 UI 移除）→ `partialDeletionRemovesDeletedItemsAndKeepsFailedForRetry` 转红（relatedFiles/selectedFileIds 仍含已删项），其余仍绿。
> - **M4** 删除写回前的 `guard self.selectedApp?.bundleURL.path == appPath else { return }` 身份校验（旧结果无条件写回）→ `staleDeletionResultDoesNotPolluteNewSelection` 转红（切换到 B 后旧删除结果污染 B 的状态），其余仍绿。
> - 还原完整修复 → 34 条全绿。

> 变异验证（#795，`AppManagerViewModel.reconcileSelection`）：
> - **M1** 删除 `performScan` 发布列表后的 `reconcileSelection(with: apps)` 调用（恢复「选中与详情脱节」缺陷）→ 4 条全部转红（remap 两条 `selectedApp.id != installedApps[0].id`，清空两条 `selectedApp` 仍非 nil）。
> - **M2** 把 `else { cancelSelection() }` 改为 `else { }`（应用被移除时不清空）→ `refreshClearsSelectionWhenAppRemovedExternally`、`refreshClearsRemovedSelectionEvenWhenListNonEmpty` 转红（selectedApp/relatedFiles 残留），remap 两条仍绿。
> - **M3** 把 path 匹配 `$0.bundleURL.path == selected.bundleURL.path` 改为 `$0.id == selected.id`（按瞬时 id 匹配，新批次永远不命中）→ `refreshRemapsSelectionToNewModelByPath`、`refreshPreservesRelatedFilesWhenAppStillExists` 转红（选中被误清空而非 remap），清空两条仍绿。
> - 还原完整修复 → 38 条全绿。

> 变异验证（#648，`AppService.appBundleURLs` / `scanInstalledApps` 枚举入口）：
> - **M1** 把 `scanInstalledApps` 的 `for appURL in Self.appBundleURLs(under: url)` 换回「只枚举根的直接子项并过滤 `pathExtension == "app"`」（复现原缺陷）→ `scanFindsAppsInsideUtilitiesContainer` 转红（Utilities 里的 Terminal/Activity Monitor 未被发现），helper 三条仍绿。
> - **M2** 把 `applicationContainerDirectoryNames` 置为空集合（helper 不再下降任何容器）→ `scanFindsAppsInsideUtilitiesContainer`、`discoveryStopsAtOneLevelAndNeverEntersAppBundles`、`discoverySkipsHiddenEntries` 转红（结果缺少容器内应用），`discoveryStillReturnsDirectAppChildren` 仍绿。
> - **M3** 把容器名判定 `applicationContainerDirectoryNames.contains(...)` 改为 `true`（任意目录都被下降一层）→ `discoveryStopsAtOneLevelAndNeverEntersAppBundles` 转红（`Other/Stray.app` 被当成应用来源），其余三条仍绿。
> - 还原完整修复 → 42 条全绿。

## 覆盖率统计

- P0: 已覆盖 19 / 19
- P1: 已覆盖 24 / 24
- P2: 已覆盖 1 / 1
- **合计: 44 / 44**（仅表示清单场景，非源码覆盖率）

## 优先级说明

- **P0**: 描述/名称含崩溃、泄漏、截断、丢失、竞态、超时、必须、不得、重试等失效类信号的用例（19 条）
- **P1**: 其余功能性用例（24 条）
- **P2**: 稳定常量、占位、文案、空集合等边界用例（1 条）

## 跨平台说明

- Package 声明: macOS 14+, iOS 17+
- 42 条用例位于 `Tests/`，需在目标平台执行 `swift test`

## 测试执行

```bash
cd Packages/PluginAppManager
swift test
```

## 维护规则

1. **新增公开 API** → 先在 TestPlan 登记测试用例，再写实现
2. **Bug 修复** → 追加回归用例，标注触发条件
3. **删除用例** → 在 commit message 说明理由
4. **状态同步** → 实现后更新 TestPlan，标记 ✅ 并填写测试方法名
5. **改名同步** → 重命名 `@Test` 函数后必须同步本表，否则 `Scripts/verify-testplan.py` 会报「登记方法在源码不存在」
