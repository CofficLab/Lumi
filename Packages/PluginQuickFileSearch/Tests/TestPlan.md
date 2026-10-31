# TestPlan — PluginQuickFileSearch

## 包概述

QuickFileSearchPlugin Fast file search with Cmd+P

平台: macOS 14+, iOS 17+
测试文件: 1 个，用例总数: 24

核心组件（源码目录）:
- `Models/`
- `Observers/`
- `Services/`
- `Views/`

## 公开 API

包内主要类型（按声明顺序抽取，供定位被测对象）:

- `QuickFileSearchPlugin`
- `FileIndexStore`
- `FileSearchHotkeyManager`
- `QuickFileSearchSignpost`
- `QuickFileSearchBridge`
- `FileSearchOverlay`
- `FileSearchPanelView`
- `FileSearchResultRow`
- `QuickFileSearchAboutView`
- `QuickFileSearchManualView`
- `QuickFileSearchSettingsView`

## 关键行为契约（实现约定，非协议要求）

按测试模块归纳，改动对应模块时须保持既有断言成立:

- **综合**（24 条）：由 `v2PluginPreservesQuickOpenIdentity`、`fileIndexStoreNeedsReindexWhenNeverUpdated`、`fileIndexStoreDoesNotNeedReindexAfterFreshUpdate` 等用例锁定；改动该模块时优先跑对应测试文件。

## 测试用例清单

| ID | 类别 | 描述 | 前置条件 | 操作步骤 | 预期结果 | 优先级 | 状态 | 测试方法 |
|----|------|------|----------|----------|----------|------|------|----------|
| 1 | 综合 | v2PluginPreservesQuickOpenIdentity | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `v2PluginPreservesQuickOpenIdentity` |
| 2 | 综合 | fileIndexStoreNeedsReindexWhenNeverUpdated | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `fileIndexStoreNeedsReindexWhenNeverUpdated` |
| 3 | 综合 | fileIndexStoreDoesNotNeedReindexAfterFreshUpdate | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `fileIndexStoreDoesNotNeedReindexAfterFreshUpdate` |
| 4 | 综合 | fileIndexStoreClearsAllState | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `fileIndexStoreClearsAllState` |
| 5 | 综合 | fileIndexExpiresAfterFiveMinutes | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `fileIndexExpiresAfterFiveMinutes` |
| 6 | 综合 | fuzzyMatchIsCaseSensitiveSubsequenceCheck | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `fuzzyMatchIsCaseSensitiveSubsequenceCheck` |
| 7 | 综合 | fuzzyMatchSingleCharAndFullMatch | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `fuzzyMatchSingleCharAndFullMatch` |
| 8 | 综合 | searchInFilesReturnsFilesSortedByScore | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `searchInFilesReturnsFilesSortedByScore` |
| 9 | 综合 | searchInFilesEmptyQueryReturnsEmpty | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `searchInFilesEmptyQueryReturnsEmpty` |
| 10 | 综合 | fileSearchResultRowMapsFileIconsByExtension | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `fileSearchResultRowMapsFileIconsByExtension` |
| 11 | 综合 | fileSearchResultRowDefaultsUnknownExtensionsToDoc | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `fileSearchResultRowDefaultsUnknownExtensionsToDoc` |
| 12 | 综合 | fileSearchResultRowKnownNonCodeExtensionsReturnDocText | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `fileSearchResultRowKnownNonCodeExtensionsReturnDocText` |
| 13 | 综合 | quickOpenResultsWithEmptyQueryReturnsEmpty | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `quickOpenResultsWithEmptyQueryReturnsEmpty` |
| 14 | 综合 | quickOpenResultsOnEmptyIndexReturnsEmpty | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `quickOpenResultsOnEmptyIndexReturnsEmpty` |
| 15 | 综合 | staleSearchResultsTrimmedQueriesAreEquivalent | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `staleSearchResultsTrimmedQueriesAreEquivalent` |
| 16 | 综合 | scanProjectFilesOnlyDropsRootPrefix | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `scanProjectFilesOnlyDropsRootPrefix` |
| 17 | 综合 | relativePathRejectsSiblingWithSharedPrefix | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `relativePathRejectsSiblingWithSharedPrefix` |
| 18 | 综合 | scanProjectFilesSkipsRootBuildAndDependencyDirectories | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `scanProjectFilesSkipsRootBuildAndDependencyDirectories` |
| 19 | 综合 | shouldSkipPathMatchesDirectoryComponentAtPathEnd | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `shouldSkipPathMatchesDirectoryComponentAtPathEnd` |
| 20 | 综合 | staleSearchResultsDoNotApplyToChangedQuery | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `staleSearchResultsDoNotApplyToChangedQuery` |
| 21 | 综合 | indexCompletionRefreshesOnlyActiveQueries | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `indexCompletionRefreshesOnlyActiveQueries` |
| 22 | 综合 | quickOpenResultsClampsNonPositiveLimits | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `quickOpenResultsClampsNonPositiveLimits` |
| 23 | 综合 | fuzzyMatchRejectsEmptyQuery | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `fuzzyMatchRejectsEmptyQuery` |
| 24 | 综合 | fileSearchResultRowMapsCommonFileIconsWithoutDuplicateCases | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `fileSearchResultRowMapsCommonFileIconsWithoutDuplicateCases` |

> 说明：全部 **24 条场景**已在本包 `swift test` 中实跑通过。
> 用例名与描述取自 `Tests/` 下的真实 `@Test` 声明，改动测试时须同步本表。

## 覆盖率统计

- P0: 已覆盖 3 / 3
- P1: 已覆盖 15 / 15
- P2: 已覆盖 6 / 6
- **合计: 24 / 24**（仅表示清单场景，非源码覆盖率）

## 优先级说明

- **P0**: 描述/名称含崩溃、泄漏、截断、丢失、竞态、超时、必须、不得、重试等失效类信号的用例（3 条）
- **P1**: 其余功能性用例（15 条）
- **P2**: 稳定常量、占位、文案、空集合等边界用例（6 条）

## 跨平台说明

- Package 声明: macOS 14+, iOS 17+
- 24 条用例位于 `Tests/`，需在目标平台执行 `swift test`

## 测试执行

```bash
cd Packages/PluginQuickFileSearch
swift test
```

## 维护规则

1. **新增公开 API** → 先在 TestPlan 登记测试用例，再写实现
2. **Bug 修复** → 追加回归用例，标注触发条件
3. **删除用例** → 在 commit message 说明理由
4. **状态同步** → 实现后更新 TestPlan，标记 ✅ 并填写测试方法名
5. **改名同步** → 重命名 `@Test` 函数后必须同步本表，否则 `Scripts/verify-testplan.py` 会报「登记方法在源码不存在」
