# TestPlan — PluginDiskManager

## 包概述

PluginDiskManager 的实现包，包含 14 个主要类型；当前测试覆盖 38 条用例。

平台: macOS 14+, iOS 17+
测试文件: 3 个，用例总数: 38

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

- **DiskManagerLumiTools**（12 条）：由 `formatBytesProducesHumanReadableString`、`formatBytesHandlesZero`、`formatDateReturnsUnknownForNil` 等用例锁定；改动该模块时优先跑对应测试文件。
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

> 说明：全部 **38 条场景**已在本包 `swift test` 中实跑通过。
> 用例名与描述取自 `Tests/` 下的真实 `@Test` 声明，改动测试时须同步本表。

## 覆盖率统计

- P0: 已覆盖 0 / 0
- P1: 已覆盖 33 / 33
- P2: 已覆盖 5 / 5
- **合计: 38 / 38**（仅表示清单场景，非源码覆盖率）

## 优先级说明

- **P0**: 描述/名称含崩溃、泄漏、截断、丢失、竞态、超时、必须、不得、重试等失效类信号的用例（0 条）
- **P1**: 其余功能性用例（33 条）
- **P2**: 稳定常量、占位、文案、空集合等边界用例（5 条）

## 跨平台说明

- Package 声明: macOS 14+, iOS 17+
- 38 条用例位于 `Tests/`，需在目标平台执行 `swift test`

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
