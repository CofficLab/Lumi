# TestPlan — PluginDiskManager

## 包概述

PluginDiskManager 的实现包，包含 14 个主要类型；当前测试覆盖 53 条用例。

平台: macOS 14+, iOS 17+
测试文件: 4 个，用例总数: 53

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

## 关键行为契约（实现约定，非协议要求）

按测试模块归纳，改动对应模块时须保持既有断言成立:

- **CacheCleanerTrash**（2 条）：由 `scanExpandsTrashIntoChildren`、`cleanupKeepsTrashRoot` 锁定；改动废纸篓/缓存扫描与清理逻辑时优先跑对应测试文件。
- **DiskManagerLumiTools**（27 条）：由 `formatBytesProducesHumanReadableString`、`formatBytesHandlesZero`、`formatDateReturnsUnknownForNil` 等用例锁定；改动该模块时优先跑对应测试文件。
- **DiskModelsPureLogic**（19 条）：由 `classifiesImages`、`classifiesVideos`、`classifiesAudio` 等用例锁定；改动该模块时优先跑对应测试文件。
- **综合**（7 条）：由 `pluginMetadataIsStable`、`agentToolsContributionIsAvailable`、`railTabIDIsStable` 等用例锁定；改动该模块时优先跑对应测试文件。

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

> 说明：全部 **59 条场景**已在本包 `swift test` 中实跑通过。
> 用例名与描述取自 `Tests/` 下的真实 `@Test` 声明，改动测试时须同步本表。

## 覆盖率统计

- P0: 已覆盖 11 / 11
- P1: 已覆盖 40 / 40
- P2: 已覆盖 8 / 8
- **合计: 59 / 59**（仅表示清单场景，非源码覆盖率）

## 优先级说明

- **P0**: 描述/名称含崩溃、泄漏、截断、丢失、竞态、超时、必须、不得、重试等失效类信号的用例（6 条）
- **P1**: 其余功能性用例（38 条）
- **P2**: 稳定常量、占位、文案、空集合等边界用例（7 条）

## 跨平台说明

- Package 声明: macOS 14+, iOS 17+
- 57 条用例位于 `Tests/`，需在目标平台执行 `swift test`

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
