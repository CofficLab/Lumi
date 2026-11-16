# TestPlan — PluginDiskManager

## 包概述

PluginDiskManager 的实现包，包含 15 个主要类型；当前测试覆盖 90 条用例。

平台: macOS 14+, iOS 17+
测试文件: 12 个，用例总数: 90

核心组件（源码目录）:
- `Internal/`
- `Services/`
- `Tools/`
- `ViewModels/`
- `Views/`

## 公开 API

包内主要类型（按声明顺序抽取，供定位被测对象）:

- `DiskManagerPlugin`
- `PluginDiskManagerLocalization`
- `CacheCleanupError`
- `CacheCategory`
- `DiskUsage`
- `ProjectInfo`
- `XcodeCleanCategory`
- `CacheCleanerService`
- `DirectoryTreeService`
- `ScanCache`
- `DiskService`
- `LargeFilesService`
- `ProjectCleanerService`
- `XcodeCleanService`
- `ScanControlBarVisibility`

## 关键行为契约（实现约定，非协议要求）

按测试模块归纳，改动对应模块时须保持既有断言成立:

- **CacheCleanerTrash**（2 条）：由 `scanExpandsTrashIntoChildren`、`cleanupKeepsTrashRoot` 锁定；改动废纸篓/缓存扫描与清理逻辑时优先跑对应测试文件。
- **CacheCleanerDuplicatePath**（5 条）：由 `cleanupDeduplicatesIdenticalPathsAndProcessesRest`、`cleanupToleratesAlreadyMissingPath`、`cleanupStillThrowsOnMissingPathByDefault` 锁定；改动缓存清理去重/容错逻辑时优先跑对应测试文件。
- **DiskManagerLumiTools**（27 条）：由 `formatBytesProducesHumanReadableString`、`formatBytesHandlesZero`、`formatDateReturnsUnknownForNil` 等用例锁定；改动该模块时优先跑对应测试文件。
- **DiskModelsPureLogic**（19 条）：由 `classifiesImages`、`classifiesVideos`、`classifiesAudio` 等用例锁定；改动该模块时优先跑对应测试文件。
- **综合**（7 条）：由 `pluginMetadataIsStable`、`agentToolsContributionIsAvailable`、`railTabIDIsStable` 等用例锁定；改动该模块时优先跑对应测试文件。
- **DiskManagerPlugin 运行时启停**（3 条）：由 `disablingPluginWithdrawsAgentTools`、`enablingPluginRestoresAgentTools`、`disabledToolsAreNotExecutable` 锁定。内核运行时禁用插件只撤回显式登记的贡献，不清理 Provider 侧写入；`onDisable` 必须撤回全部 10 个 Agent 工具（含缓存/项目清理与 `DeleteFilesTool` 删除），`onEnable` 必须恢复，登记/撤回经 `areAgentToolsRegistered` 标志保证幂等。禁用后工具不得再被解析或执行（**回归 #453**）。改动 `DiskManagerPlugin.onEnable/onDisable/registerAgentTools/unregisterAgentTools` 时优先跑对应测试文件。
- **DirectoryTreePackageSize**（4 条）：由 `topLevelSummaryCountsPackageContentRecursively`、`fullTreeCountsPackageContentInParentDirectory`、`fullTreeAggregatesRegularFilesIntoParentDirectory`、`nestedPackageContentIsCountedRecursively` 锁定（**回归 #850**）：`.app`/`.photoslibrary` 等 package 仍折叠为单个叶子展示，但其大小必须递归累计内部真实内容（含嵌套 package），不得只读目录记录的几十字节；该递归大小必须计入父目录与扫描进度的 `scannedBytes`。`buildTree` 的自底向上聚合必须把叶子（普通文件与 package）大小也传入父目录，否则父目录大小恒为 0。改动 `DirectoryTreeService.buildTopLevelSummary/buildTree/packageContentSize` 或聚合循环时优先跑对应测试文件（串行套件）。
- **扫描控制栏可见性**（9 条）：由 `scanningKeepsControlBarVisibleWithoutResults`、`cacheCleanerControlBarStaysVisibleWhileScanning`、`largeFilesControlBarStaysVisibleWhileScanning` 等用例锁定（**回归 #849**）：五个扫描界面（系统缓存/目录分析/大文件/项目清理/Xcode 清理）的控制栏内含唯一 Stop 分支（`isScanning` 时调用 `stopScan()`），扫描进行中必须保留控制栏使 Stop 可达——大文件在扫描开始时清空结果，仍须可见；空闲有结果时显示 Start/Refresh，空闲且无结果时隐藏。可见性统一由 `ScanControlBarVisibility.isVisible(isScanning:hasResults:)`（`isScanning || hasResults`）决定，各 ViewModel 经 `isScanControlBarVisible` 接入真实结果集合（categories/rootEntries/largeFiles/projects/itemsByCategory）。改动该 helper、五个 ViewModel 的 `isScanControlBarVisible` 或五个父视图的控制栏 gate 时优先跑对应测试文件。
- **WorkspaceIconCache**（5 条）：由 `iconQueriesOncePerPathAndReusesInstance`、`distinctPathsAreQueriedSeparately`、`cacheEvictsOldestBeyondLimit` 等用例锁定（**回归 #1223**）：大文件/目录树/缓存三个行视图过去在 `body` 内直接 `NSWorkspace.shared.icon(forFile:)`，每次 body 求值都重复同步 workspace 查询；改为经 `@MainActor WorkspaceIconCache.shared.icon(forPath:)` 按路径缓存，同一路径至多查询一次并复用同一 NSImage 实例，NSImage 仍不进入 Sendable 模型。缓存有上限并按插入顺序 FIFO 淘汰，避免无界增长；不对懒加载/无界的目录树做发布期预取。改动 `WorkspaceIconCache` 或三个行视图的 `icon` 计算属性时优先跑对应测试文件。
- **XcodeCleanerSummary**（5 条）：由 `summaryMatchesItemsAfterPublication`、`summaryIsRebuiltOncePerUpdateNotPerRead`、`toggleUpdatesSummaryByExactlyTheChangedItem` 等用例锁定（**回归 #1222**）：Xcode 清理 footer 单次 body 求值会读 `selectedSize` 两次、`totalSize` 一次，旧实现每个计算属性都重新 `flatMap`/`filter`/`reduce` 整个结果集，分类头还各自 filter/reduce 其 items。改为在 `XcodeCleanerViewModel` 维护预聚合快照（`totalSize`/`selectedSize`/`selectedCount` 与每分类 `XcodeCategorySummary`），由 `itemsByCategory` 的 `didSet` 在每次变更时单遍嵌套累加重算一次（不产生 flatMap/filter 临时数组），footer 与分类头读取存储值。`summaryRebuildCount` 仅供测试断言「每次更新只重算一次、读取不再重算」。改动该快照、`rebuildSummary()`、`didSet` 或 `XcodeCategorySection` 的 `selectedCount`/`categorySize` 时优先跑对应测试文件。

## 测试用例清单

| ID | 类别 | 描述 | 前置条件 | 操作步骤 | 预期结果 | 优先级 | 状态 | 测试方法 |
|----|------|------|----------|----------|----------|------|------|----------|
| 1 | DiskManagerLumiTools | formatBytesProducesHumanReadableString | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `formatBytesProducesHumanReadableString` |
| 2 | DiskManagerLumiTools | formatBytesHandlesZero | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `formatBytesHandlesZero` |
| 3 | DiskManagerLumiTools | formatDateReturnsUnknownForNil | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `formatDateReturnsUnknownForNil` |
| 4 | DiskManagerLumiTools | formatDateProducesISO8601ForConcreteDate | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `formatDateProducesISO8601ForConcreteDate` |
| 5 | DiskManagerLumiTools | resolveScanPathFallsBackToHomeWhenEmpty | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `resolveScanPathFallsBackToHomeWhenEmpty` |
| 6 | DiskManagerLumiTools | resolveScanPathExpandsTilde | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `resolveScanPathExpandsTilde` |
| 7 | DiskManagerLumiTools | topLevelScanAggregatesNestedUsageWithoutMaterializingTree | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `topLevelScanAggregatesNestedUsageWithoutMaterializingTree` |
| 8 | DiskManagerLumiTools | topLevelScanStopsAtEntryBudget | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `topLevelScanStopsAtEntryBudget` |
| 9 | DiskManagerLumiTools | pluginRegistersAllDiskManagerTools | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `pluginRegistersAllDiskManagerTools` |
| 10 | DiskManagerLumiTools | destructiveToolsAreHighRisk | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `destructiveToolsAreHighRisk` |
| 11 | DiskManagerLumiTools | readToolsAreLowRisk | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `readToolsAreLowRisk` |
| 12 | DiskManagerLumiTools | destructiveToolsProvideDisplayDescriptions | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `destructiveToolsProvideDisplayDescriptions` |
| 13 | DiskModelsPureLogic | classifiesImages | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `classifiesImages` |
| 14 | DiskModelsPureLogic | classifiesVideos | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `classifiesVideos` |
| 15 | DiskModelsPureLogic | classifiesAudio | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `classifiesAudio` |
| 16 | DiskModelsPureLogic | classifiesArchives | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `classifiesArchives` |
| 17 | DiskModelsPureLogic | classifiesCode | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `classifiesCode` |
| 18 | DiskModelsPureLogic | classifiesDocuments | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `classifiesDocuments` |
| 19 | DiskModelsPureLogic | classifiesUnknownAsOther | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `classifiesUnknownAsOther` |
| 20 | DiskModelsPureLogic | classificationIsCaseInsensitive | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `classificationIsCaseInsensitive` |
| 21 | DiskModelsPureLogic | keepsTopNCapacity | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `keepsTopNCapacity` |
| 22 | DiskModelsPureLogic | returnsDescendingOrder | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `returnsDescendingOrder` |
| 23 | DiskModelsPureLogic | ignoresElementsBelowCurrentMinWhenFull | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `ignoresElementsBelowCurrentMinWhenFull` |
| 24 | DiskModelsPureLogic | acceptsLargerElementWhenFull | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `acceptsLargerElementWhenFull` |
| 25 | DiskModelsPureLogic | emptyHeapProducesEmptyElements | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `emptyHeapProducesEmptyElements` |
| 26 | DiskModelsPureLogic | handlesDuplicateInserts | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `handlesDuplicateInserts` |
| 27 | DiskModelsPureLogic | usedPercentageComputesFraction | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `usedPercentageComputesFraction` |
| 28 | DiskModelsPureLogic | usedPercentageZeroWhenTotalIsZero | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `usedPercentageZeroWhenTotalIsZero` |
| 29 | DiskModelsPureLogic | usedPercentageFull | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `usedPercentageFull` |
| 30 | DiskModelsPureLogic | orderingIsSafeLessThanMediumLessThanRisky | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `orderingIsSafeLessThanMediumLessThanRisky` |
| 31 | DiskModelsPureLogic | sortBySafetyLevelAscending | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `sortBySafetyLevelAscending` |
| 32 | 综合 | pluginMetadataIsStable | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `pluginMetadataIsStable` |
| 33 | 综合 | agentToolsContributionIsAvailable | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `agentToolsContributionIsAvailable` |
| 34 | 综合 | railTabIDIsStable | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `railTabIDIsStable` |
| 35 | 综合 | activatingPluginHidesChatSectionAndDeactivatingRestoresIt | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `activatingPluginHidesChatSectionAndDeactivatingRestoresIt` |
| 36 | 综合 | localizationCatalogIsPackaged | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `localizationCatalogIsPackaged` |
| 37 | 综合 | scanURLAcceptsUnescapedFileURL | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `scanURLAcceptsUnescapedFileURL` |
| 38 | 综合 | scanURLAcceptsLocalPathAndTilde | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `scanURLAcceptsLocalPathAndTilde` |
| 39 | DiskManagerLumiTools | 相对扫描路径锚定到用户主目录，绝对路径保持不变 | 主目录路径 | 解析 `Documents`、带空格的同名路径、`Documents/Invoices`、`/tmp` | 前三个得到 `~/Documents` 或 `~/Documents/Invoices`，`/tmp` 原样返回 | P1 | ✅ 已覆盖 | `resolveScanPathAnchorsRelativePathsToHome` |
| 40 | DiskManagerLumiTools | 不存在的目录树扫描根抛出可诊断错误 | 不存在的路径 | 调用 `scanTopLevelDirectoryUsage` | 抛出 `DiskManagerScanError.rootUnavailable`，说明路径不存在 | P1 | ✅ 已覆盖 | `missingScanRootThrowsRootUnavailable` |
| 41 | DiskManagerLumiTools | 存在的空目录树返回空结果而非错误 | 空临时目录 | 调用 `scanTopLevelDirectoryUsage` | 返回空数组，不抛错 | P2 | ✅ 已覆盖 | `emptyScanRootReturnsEmptyResult` |
| 42 | DiskManagerLumiTools | 不存在的大文件扫描根抛出可诊断错误 | 不存在的路径 | 调用 `LargeFilesService.scanLargeFiles` | 抛出 `DiskManagerScanError.rootUnavailable`，说明路径不存在 | P1 | ✅ 已覆盖 | `largeFileScanThrowsForMissingRoot` |
| 43 | DiskManagerLumiTools | 存在的空目录大文件扫描返回空结果 | 空临时目录 | 调用 `LargeFilesService.scanLargeFiles` | 返回空数组，不抛错 | P2 | ✅ 已覆盖 | `largeFileScanReturnsEmptyForExistingEmptyRoot` |
| 44 | DiskManagerLumiTools | 大文件工具对缺失根抛出失败 | 不存在的路径参数 | 调用 `ScanLargeFilesTool.executeResult` | 抛出 `ToolExecutionError`，不再以 `isError == false` 的成功结果返回 | P1 | ✅ 已覆盖 | `scanLargeFilesToolReportsMissingRootAsFailure` |
| 45 | DiskManagerLumiTools | 目录树工具对缺失根抛出失败 | 不存在的路径参数 | 调用 `ScanDirectoryTreeTool.executeResult` | 抛出 `ToolExecutionError`，不再以 `isError == false` 的成功结果返回 | P1 | ✅ 已覆盖 | `scanDirectoryTreeToolReportsMissingRootAsFailure` |
| 46 | CacheCleanerTrash | 废纸篓扫描枚举子项，不把 ~/.Trash 本身生成为清理项 | 临时 home 下 .Trash 含两个文件 | 调用 `scanCategory` | 返回 2 个子项，均不是废纸篓根路径 | P0 | ✅ 已覆盖 | `scanExpandsTrashIntoChildren` |
| 47 | CacheCleanerTrash | 清理废纸篓只删内部文件并保留根目录 | 临时 home 下 .Trash 含一个 256 字节文件 | 扫描后调用 `cleanup` | 释放 256 字节，~/.Trash 仍存在且为目录 | P0 | ✅ 已覆盖 | `cleanupKeepsTrashRoot` |
| 48 | DiskManagerLumiTools | 路径数组解析保留原始字符串，仅用裁剪判断是否为空 | `["/tmp/a ", "   ", "/tmp/b"]` | 调用 `DiskManagerToolSupport.paths` | 返回 `["/tmp/a ", "/tmp/b"]`，纯空白条目被剔除 | P0 | ✅ 已覆盖 | `pathsPreserveOriginalStringsAndDropBlankEntries` |
| 49 | DiskManagerLumiTools | clean-caches 删除带末尾空格的路径时不影响同名兄弟目录 | 临时目录下 `lumi-target` 与 `lumi-target ` 两个目录 | 只传 `lumi-target ` 调用 `CleanCachesTool.execute` | 后者被删除，前者保留 | P0 | ✅ 已覆盖 | `cleanCachesToolDeletesExactPathWithTrailingWhitespace` |
| 50 | DiskManagerLumiTools | clean-xcode-caches 删除带末尾空格的路径时不影响同名兄弟目录 | 临时目录下 `lumi-target` 与 `lumi-target ` 两个目录 | 只传 `lumi-target ` 调用 `CleanXcodeCachesTool.execute` | 后者被删除，前者保留 | P0 | ✅ 已覆盖 | `cleanXcodeCachesToolDeletesExactPathWithTrailingWhitespace` |
| 51 | DiskManagerLumiTools | clean-projects 删除带末尾空格的路径时不影响同名兄弟目录 | 临时目录下 `lumi-target` 与 `lumi-target ` 两个目录 | 只传 `lumi-target ` 调用 `CleanProjectsTool.execute` | 后者被删除，前者保留 | P0 | ✅ 已覆盖 | `cleanProjectsToolDeletesExactPathWithTrailingWhitespace` |
| 52 | DiskManagerLumiTools | delete-files 删除带末尾空格的路径时不影响同名兄弟目录 | 临时目录下 `lumi-target` 与 `lumi-target ` 两个目录 | 只传 `lumi-target ` 调用 `DeleteFilesTool.execute` | 后者被删除，前者保留 | P0 | ✅ 已覆盖 | `deleteFilesToolDeletesExactPathWithTrailingWhitespace` |
| 53 | DiskManagerLumiTools | 三个清理工具删除失败时抛出错误而非返回成功文本 | 不存在的绝对路径 | 调用 `executeResult` | 均抛出 `ToolExecutionError.executionFailed` | P0 | ✅ 已覆盖 | `cleanToolsThrowWhenDeletionFails` |
| 54 | ProjectCleaner | 根目录本身是可清理项目时仍会扫描 monorepo 子包 | 临时 monorepo：根与 `packages/app` 各有 `package.json` + `node_modules` | 调用 `ProjectCleanerService.scanDirectory` | 同时返回根与子包两个项目 | P1 | ✅ 已覆盖 | `scanDirectoryFindsNestedProjectsUnderCleanableRoot` |
| 55 | ProjectCleaner | 递归时不进入 node_modules 等可清理产物目录 | `node_modules/left-pad/packages/inner` 下放 `package.json` + `node_modules` | 调用 `ProjectCleanerService.scanDirectory` | 结果为空 | P2 | ✅ 已覆盖 | `scanDirectoryDoesNotEnterCleanableDirectories` |
| 56 | CacheCleanerSafety | Xcode Archives 归入需确认级别，任何安全级别规则都不含它 | 真实扫描规则集合 | 检查包含 `Xcode/Archives` 的规则 | 该规则为 `.medium`；安全级别规则均不含 Archives | P0 | ✅ 已覆盖 | `xcodeArchivesRequiresExplicitSelection` |
| 57 | CacheCleanerSafety | 开发者工具缓存不再包含 Archives | 真实扫描规则集合 | 取 `dev_cache` 规则的路径 | 路径中不含 `Xcode/Archives` | P1 | ✅ 已覆盖 | `developerToolCacheNoLongerContainsArchives` |
| 58 | DiskManagerLumiTools | clean-caches 对普通文件根路径报告真实释放字节 | 临时目录下 8192 字节普通文件 | 调用 `sizeOfPath` 与 `CleanCachesTool.execute` | 测得 8192 字节，输出含实际大小且不含 0 字节 | P0 | ✅ 已覆盖 | `cleanCachesToolReportsActualSizeForRegularFile` |
| 59 | DiskManagerLumiTools | 删除大文件成功后发出磁盘用量变化通知 | 临时目录下普通文件 | 调用 `LargeFilesService.deleteFile` | 收到 `diskManagerDiskUsageDidChange` 通知且文件已删除 | P0 | ✅ 已覆盖 | `deletingLargeFilePostsDiskUsageChangeNotification` |
| 60 | CacheCleanerDuplicatePath | 相同路径来自两个分类时只删一次、只计一次释放空间，并继续处理后续项 | 临时目录下 Firefox(128B) 与 Safari(64B)，Firefox 列出两次 | 调用 `cleanup` | 释放 192B，Firefox 只计一次，Safari 仍被删除 | P0 | ✅ 已覆盖 | `cleanupDeduplicatesIdenticalPathsAndProcessesRest` |
| 61 | CacheCleanerDuplicatePath | UI 清理遇到已不存在的路径时跳过而不中断后续项 | 一个缺失路径 + 一个有效目录(256B) | 调用 `cleanup(toleratingMissing: true)` | 释放 256B，有效项被删除，不抛错 | P0 | ✅ 已覆盖 | `cleanupToleratesAlreadyMissingPath` |
| 62 | CacheCleanerDuplicatePath | 嵌套父子路径重叠时先删父目录，子路径消失后跳过且不重复计入 | Google(含 Chrome) 父目录 192B + 子路径 Chrome 64B | 调用 `cleanup(toleratingMissing: true)` | 释放 192B，父目录删除，不抛错 | P1 | ✅ 已覆盖 | `cleanupNestedParentChildDoesNotAbort` |
| 63 | CacheCleanerDuplicatePath | 按规范化路径去重：尾斜杠变体视为同一路径 | Firefox 路径与其尾斜杠变体各一次 | 调用 `cleanup`（默认严格模式） | 释放 128B，只删一次 | P1 | ✅ 已覆盖 | `cleanupDeduplicatesByNormalizedPath` |
| 64 | CacheCleanerDuplicatePath | 工具流程（默认）删除缺失路径仍抛错，保持 #740 契约 | 不存在的绝对路径 | 调用 `cleanup`（默认） | 抛出 `CacheCleanupError` | P0 | ✅ 已覆盖 | `cleanupStillThrowsOnMissingPathByDefault` |
| 65 | DiskManagerPlugin 运行时启停 | 运行时禁用后必须撤回全部 10 个 Agent 工具，含清理与删除（**回归 #453**） | 内核已启动且插件启用，工具均在 | `kernel.disablePlugin(id:)` | 10 个工具全部解析为 nil | P0 | ✅ 已覆盖 | `disablingPluginWithdrawsAgentTools` |
| 66 | DiskManagerPlugin 运行时启停 | 运行时重新启用插件后恢复全部 Agent 工具 | 内核已启动且插件启用 | 先 disable 再 `enablePlugin` | 10 个工具全部恢复 | P1 | ✅ 已覆盖 | `enablingPluginRestoresAgentTools` |
| 67 | DiskManagerPlugin 运行时启停 | 禁用后清理与删除工具不得再进入执行路径（**回归 #453**） | 内核已启动且插件启用 | `kernel.disablePlugin(id:)` | delete-files/clean-caches 解析为 nil，allTools 无 disk-manager. 前缀 | P0 | ✅ 已覆盖 | `disabledToolsAreNotExecutable` |
| 68 | DirectoryTreePackageSize | 顶层汇总递归累计 package 内容大小并计入扫描进度（**回归 #850**） | 临时根下 Calculator.app（exec 1000B + 资源 2000B）与 root.bin 7B | 调用 `scanTopLevelDirectoryUsage` | Calculator.app 大小为 3000（非目录记录），root.bin 为 7，进度 scannedBytes 为 3007 | P0 | ✅ 已覆盖 | `topLevelSummaryCountsPackageContentRecursively` |
| 69 | DirectoryTreePackageSize | 完整目录树把 package 递归大小计入父目录，package 仍为叶子（**回归 #850**） | Applications 下 Calculator.app（3000B）与 note.txt 5B | 调用 `scanDirectoryTree` | Applications 大小 3005，Calculator.app 大小 3000、isDirectory=false、children=nil | P0 | ✅ 已覆盖 | `fullTreeCountsPackageContentInParentDirectory` |
| 70 | DirectoryTreePackageSize | 完整目录树自底向上聚合必须把普通文件大小传入父目录（**回归 #850**） | Docs/a.bin 1000B 与根 top.bin 23B | 调用 `scanDirectoryTree` | Docs 大小 1000（非 0），top.bin 大小 23 | P0 | ✅ 已覆盖 | `fullTreeAggregatesRegularFilesIntoParentDirectory` |
| 71 | DirectoryTreePackageSize | package 内嵌套 package 的内容也被递归累计（**回归 #850**） | Outer.app（exec 1000B）内 Resources/Inner.bundle/payload.bin 500B | 调用 `scanTopLevelDirectoryUsage` | Outer.app 大小 1500，嵌套 bundle 的 500B 不丢失 | P1 | ✅ 已覆盖 | `nestedPackageContentIsCountedRecursively` |
| 72 | 扫描控制栏可见性 | 扫描进行中且无结果时控制栏必须可见，Stop 入口可达（**回归 #849**） | — | 调用 `ScanControlBarVisibility.isVisible(isScanning: true, hasResults: false)` | 返回 true | P0 | ✅ 已覆盖 | `scanningKeepsControlBarVisibleWithoutResults` |
| 73 | 扫描控制栏可见性 | 扫描进行中且有结果时控制栏可见 | — | 调用 `isVisible(isScanning: true, hasResults: true)` | 返回 true | P1 | ✅ 已覆盖 | `scanningKeepsControlBarVisibleWithResults` |
| 74 | 扫描控制栏可见性 | 空闲且有结果时显示控制栏（Start/Refresh） | — | 调用 `isVisible(isScanning: false, hasResults: true)` | 返回 true | P1 | ✅ 已覆盖 | `idleWithResultsShowsControlBar` |
| 75 | 扫描控制栏可见性 | 空闲且无结果时隐藏控制栏 | — | 调用 `isVisible(isScanning: false, hasResults: false)` | 返回 false | P1 | ✅ 已覆盖 | `idleWithoutResultsHidesControlBar` |
| 76 | 扫描控制栏可见性 | 系统缓存 ViewModel 扫描中保留 Stop 入口（**回归 #849**） | 构造 `CacheCleanerViewModel` | 依次设 idle+空 categories、scanning、idle+有 categories，读 `isScanControlBarVisible` | false / true / true | P0 | ✅ 已覆盖 | `cacheCleanerControlBarStaysVisibleWhileScanning` |
| 77 | 扫描控制栏可见性 | 目录分析 ViewModel 扫描中保留 Stop 入口（**回归 #849**） | 构造 `DirectoryTreeViewModel` | 依次设 idle+空 rootEntries、scanning、idle+有 rootEntries，读 `isScanControlBarVisible` | false / true / true | P0 | ✅ 已覆盖 | `directoryTreeControlBarStaysVisibleWhileScanning` |
| 78 | 扫描控制栏可见性 | 大文件 ViewModel 扫描开始清空结果后仍保留 Stop 入口（**回归 #849**） | 构造 `LargeFilesViewModel` | 依次设 idle+空 largeFiles、scanning+空 largeFiles、idle+有 largeFiles，读 `isScanControlBarVisible` | false / true / true | P0 | ✅ 已覆盖 | `largeFilesControlBarStaysVisibleWhileScanning` |
| 79 | 扫描控制栏可见性 | 项目清理 ViewModel 扫描中保留 Stop 入口（**回归 #849**） | 构造 `ProjectCleanerViewModel` | 依次设 idle+空 projects、scanning、idle+有 projects，读 `isScanControlBarVisible` | false / true / true | P0 | ✅ 已覆盖 | `projectCleanerControlBarStaysVisibleWhileScanning` |
| 80 | 扫描控制栏可见性 | Xcode 清理 ViewModel 扫描中保留 Stop 入口（**回归 #849**） | 构造 `XcodeCleanerViewModel` | 依次设 idle+空 itemsByCategory、scanning、idle+有 itemsByCategory，读 `isScanControlBarVisible` | false / true / true | P0 | ✅ 已覆盖 | `xcodeCleanerControlBarStaysVisibleWhileScanning` |
| 81 | WorkspaceIconCache | 同一路径图标至多同步查询一次并复用同一实例（**回归 #1223**） | 注入计数 lookup 的 `WorkspaceIconCache` | 对 `/a` 连续取两次图标 | lookup 计数为 1，两次返回同一 NSImage 实例 | P0 | ✅ 已覆盖 | `iconQueriesOncePerPathAndReusesInstance` |
| 82 | WorkspaceIconCache | 不同路径各自独立查询，互不串用 | 注入计数 lookup 的 `WorkspaceIconCache` | 对 `/a`、`/b` 各重复取图标 | 两路径 lookup 计数各为 1 | P1 | ✅ 已覆盖 | `distinctPathsAreQueriedSeparately` |
| 83 | WorkspaceIconCache | 超出上限按 FIFO 淘汰最旧条目，避免无界增长（**回归 #1223**） | limit=2 的 `WorkspaceIconCache` | 依次取 `/a`、`/b`、`/c` 后再取 `/a` | `/a` 被淘汰后重查计数为 2，`/c` 仍为 1 | P0 | ✅ 已覆盖 | `cacheEvictsOldestBeyondLimit` |
| 84 | WorkspaceIconCache | 预取填充缓存后取图标不再额外查询 | 注入计数 lookup 的 `WorkspaceIconCache` | `prefetch([/a,/b])` 后各取一次图标 | 两路径 lookup 计数各为 1 | P1 | ✅ 已覆盖 | `prefetchPopulatesCacheWithoutExtraQueries` |
| 85 | WorkspaceIconCache | removeAll 清空后强制重新查询 | 注入计数 lookup 的 `WorkspaceIconCache` | 取 `/a`、`removeAll()`、再取 `/a` | lookup 计数为 2 | P2 | ✅ 已覆盖 | `removeAllForcesRequery` |
| 86 | XcodeCleanerSummary | 发布后全局与每分类聚合快照与条目一致（**回归 #1222**） | 构造 `XcodeCleanerViewModel`，derivedData(100 选中/200 未选)+logs(30 选中) | 赋值 `itemsByCategory` 后读 totalSize/selectedSize/selectedCount/categorySummary | total=330、selected=130、count=2，每分类快照精确匹配 | P1 | ✅ 已覆盖 | `summaryMatchesItemsAfterPublication` |
| 87 | XcodeCleanerSummary | 每次更新只重算一次快照，多次读取不再重算（**回归 #1222**） | 发布一个分类 | 记录 `summaryRebuildCount`，循环 50 次读取 selectedSize/totalSize/selectedCount/categorySummary | 重算次数保持为 1，不随读取增长 | P0 | ✅ 已覆盖 | `summaryIsRebuiltOncePerUpdateNotPerRead` |
| 88 | XcodeCleanerSummary | 单行切换只触发一次重算且只改变该行贡献（**回归 #1222**） | derivedData(100 未选/200 选中) | `toggleSelection(for:)` 切换 100 的项 | 重算次数 +1，selectedSize 200→300、count 1→2、totalSize 不变 | P1 | ✅ 已覆盖 | `toggleUpdatesSummaryByExactlyTheChangedItem` |
| 89 | XcodeCleanerSummary | 分类全选/反选刷新该分类与全局快照 | logs(10 未选/20 选中) | 依次 `selectAll(in:)`、`deselectAll(in:)` | 全选 selectedSize=30/count=2，反选 selectedSize=0/count=0，totalSize 恒 30 | P1 | ✅ 已覆盖 | `selectAllAndDeselectAllRefreshCategorySummary` |
| 90 | XcodeCleanerSummary | 空发布把快照重置为零 | 先发布非空再赋 `[:]` | 读 totalSize/selectedSize/selectedCount/categorySummary | 全为 0，categorySummary 为空 | P2 | ✅ 已覆盖 | `emptyPublicationResetsSummary` |

> 说明：全部 **90 条场景**已在本包 `swift test` 中实跑通过。
> 用例名与描述取自 `Tests/` 下的真实 `@Test` 声明，改动测试时须同步本表。

> 变异验证（**#453**，`DiskManagerPlugin.onDisable/onEnable`）：
> - **M1** `onDisable` 改为无操作（复现原 bug）→ `disablingPluginWithdrawsAgentTools` 转红（10 个工具未撤回），`disabledToolsAreNotExecutable` 转红（delete/clean 仍可解析，3 处断言）；`enablingPluginRestoresAgentTools` 仍绿。
> - **M2** `onEnable` 改为无操作 → `enablingPluginRestoresAgentTools` 转红（10 个工具未恢复）；两条禁用用例仍绿。
> - 还原完整修复（onDisable 撤回 + onEnable 恢复，幂等标志）→ 67 条全绿。

> 变异验证（**#850**，`DirectoryTreeService` package 递归大小与父目录聚合）：
> - **M1** 两处 `size` 改回只读 `values.fileSize`（复现原 bug）→ `topLevelSummaryCountsPackageContentRecursively` 转红（package 大小塌为目录记录、scannedBytes 只剩 7），`fullTreeCountsPackageContentInParentDirectory` 转红（package 与父目录大小丢失），`nestedPackageContentIsCountedRecursively` 转红；`fullTreeAggregatesRegularFilesIntoParentDirectory` 仍绿。
> - **M2** 聚合循环恢复 `&& node.isDirectory` 过滤 → `fullTreeCountsPackageContentInParentDirectory` 转红（父目录塌为 0），`fullTreeAggregatesRegularFilesIntoParentDirectory` 转红（Docs 塌为 0）；两条顶层汇总用例仍绿。
> - **M3** `packageContentSize` 枚举加回 `.skipsPackageDescendants` → `nestedPackageContentIsCountedRecursively` 转红（嵌套 bundle 的 500B 丢失，只剩 1000）；其余三条仍绿。
> - 还原完整修复（递归 package 大小 + 全叶子自底向上聚合 + 嵌套下降）→ 80 条全绿。

> 变异验证（**#849**，`ScanControlBarVisibility.isVisible` 与五个 ViewModel 的 `isScanControlBarVisible`）：
> - **M1** helper 改回旧 gate `!isScanning && hasResults`（复现原 bug）→ `scanningKeepsControlBarVisibleWithoutResults`、`scanningKeepsControlBarVisibleWithResults` 转红，五个 ViewModel 用例（cache/directoryTree/largeFiles/project/xcode）扫描中断言全部转红（共 7 处）；`idleWithResultsShowsControlBar`、`idleWithoutResultsHidesControlBar` 仍绿。
> - **M2** 仅把 `LargeFilesViewModel.isScanControlBarVisible` 改回内联 `!isScanning && !largeFiles.isEmpty` → `largeFilesControlBarStaysVisibleWhileScanning` 转红（1 处），其余四个 ViewModel 用例与四条 helper 用例仍绿，证明各 ViewModel 独立接入真实结果集合。
> - 还原完整修复（helper `isScanning || hasResults` + 五个 ViewModel 经 helper 接入）→ 80 条全绿。

> 变异验证（**#1223**，`WorkspaceIconCache.icon(forPath:)` 缓存命中）：
> - **M1** 删除 `if let cached = storage[path] { return cached }` 命中提前返回（复现原 bug：每次重复查询）→ `iconQueriesOncePerPathAndReusesInstance` 转红（同路径计数 >1、实例不复用），`distinctPathsAreQueriedSeparately`、`prefetchPopulatesCacheWithoutExtraQueries`、`removeAllForcesRequery` 相应转红；`swift test --filter WorkspaceIconCacheTests` 退出码 1。
> - 还原完整修复（命中提前返回 + FIFO 淘汰）→ 85 条全绿。

> 变异验证（**#1222**，`XcodeCleanerViewModel` 聚合快照与 `itemsByCategory.didSet`）：
> - **M1** 把 `totalSize`/`selectedSize`/`selectedCount` 改回每次读取都 `flatMap`/`filter`/`reduce` 的计算属性（复现原 bug：读取即重算）→ `summaryIsRebuiltOncePerUpdateNotPerRead` 转红（50 次读取使重算计数增长），`toggleUpdatesSummaryByExactlyTheChangedItem` 转红（断言读取额外重算，计数 != +1）；三条值正确性用例仍绿。
> - **M2** 移除 `itemsByCategory` 的 `didSet { rebuildSummary() }`（快照不再随更新重算）→ `summaryMatchesItemsAfterPublication`、`selectAllAndDeselectAllRefreshCategorySummary`、`toggleUpdatesSummaryByExactlyTheChangedItem`、`emptyPublicationResetsSummary` 值断言全部转红，`summaryIsRebuiltOncePerUpdateNotPerRead` 基线计数转红。
> - 还原完整修复（didSet 单遍重算 + 存储快照共享读取）→ 90 条全绿。

## 覆盖率统计

- P0: 已覆盖 28 / 28
- P1: 已覆盖 52 / 52
- P2: 已覆盖 10 / 10
- **合计: 90 / 90**（仅表示清单场景，非源码覆盖率）

## 优先级说明

- **P0**: 描述/名称含崩溃、泄漏、截断、丢失、竞态、超时、必须、不得、重试等失效类信号的用例（28 条）
- **P1**: 其余功能性用例（52 条）
- **P2**: 稳定常量、占位、文案、空集合等边界用例（10 条）

## 跨平台说明

- Package 声明: macOS 14+, iOS 17+
- 90 条用例位于 `Tests/`，需在目标平台执行 `swift test`

## 测试执行

```bash
cd Packages/PluginDiskManager
swift test
```

## 维护规则

1. **新增公开 API** → 先在 TestPlan 登记测试用例，再写实现
2. **Bug 修复** → 追加回归用例，标注触发条件
3. **删除用例** → 在 commit message 说明理由
4. **状态同步** → 实现后更新 TestPlan，标记 ✅ 并填写测试方法名
5. **改名同步** → 重命名 `@Test` 函数后必须同步本表，否则 `Scripts/verify-testplan.py` 会报「登记方法在源码不存在」
