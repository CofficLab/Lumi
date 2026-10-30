# TestPlan — ProviderEditor

## 包概述

ProviderEditor Lumi 编辑器能力契约包，定义编辑器 Provider 协议、跨层数据结构和插件贡献模型，不承载具体 UI 或业务实现。

平台: macOS 14+, iOS 17+
测试文件: 3 个，用例总数: 14

核心组件（源码目录）:
- `Editor/`

## 公开 API

包内主要类型（按声明顺序抽取，供定位被测对象）:

- `EditorThemeInfo`
- `EditorFeatureProvider`
- `EditorFeatureRequestContext`
- `EditorCallHierarchyNode`
- `EditorCommandArgument`
- `EditorSettingKey`
- `EditorContractError`
- `EditorDiagnosticSeverity`
- `EditorDiffLine`
- `EditorTextEncoding`
- `EditorDocumentSymbolKind`
- `EditorTextEdit`
- `EditorPluginAPIVersion`
- `EditorWindowID`

## 关键行为契约（实现约定，非协议要求）

按测试模块归纳，改动对应模块时须保持既有断言成立:

- **EditorEditAndDiff**（5 条）：由 `documentEditsDetectOverlappingRangesAndInteriorInsertions`、`workspaceEditsSortAndSummarizeDeterministically`、`workspaceEditResultsReportFullAndPartialSuccess` 等用例锁定；改动该模块时优先跑对应测试文件。
- **EditorFeatureAndState**（5 条）：由 `documentSelectorCombinesFiltersAndSupportsGlobMatching`、`selectorGlobSupportsEmptyAndMultipleWildcardMatches`、`pluginAPIVersionsRequireMatchingMajorAndNonNewerMinor` 等用例锁定；改动该模块时优先跑对应测试文件。
- **EditorPositionAndDocument**（4 条）：由 `positionsCompareByLineThenUTF16Character`、`rangesNormalizeAndUseHalfOpenOverlapSemantics`、`documentOffsetsRoundTripUsingUTF16ForLFAndCRLF` 等用例锁定；改动该模块时优先跑对应测试文件。

## 测试用例清单

| ID | 类别 | 描述 | 前置条件 | 操作步骤 | 预期结果 | 优先级 | 状态 | 测试方法 |
|----|------|------|----------|----------|----------|------|------|----------|
| 1 | EditorEditAndDiff | documentEditsDetectOverlappingRangesAndInteriorInsertions | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `documentEditsDetectOverlappingRangesAndInteriorInsertions` |
| 2 | EditorEditAndDiff | workspaceEditsSortAndSummarizeDeterministically | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `workspaceEditsSortAndSummarizeDeterministically` |
| 3 | EditorEditAndDiff | workspaceEditResultsReportFullAndPartialSuccess | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `workspaceEditResultsReportFullAndPartialSuccess` |
| 4 | EditorEditAndDiff | diffHunksExposeChangedLinesRangesAndStableIdentity | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `diffHunksExposeChangedLinesRangesAndStableIdentity` |
| 5 | EditorEditAndDiff | pureAddedAndUnchangedHunksHaveOptionalChangeRanges | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `pureAddedAndUnchangedHunksHaveOptionalChangeRanges` |
| 6 | EditorFeatureAndState | documentSelectorCombinesFiltersAndSupportsGlobMatching | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `documentSelectorCombinesFiltersAndSupportsGlobMatching` |
| 7 | EditorFeatureAndState | selectorGlobSupportsEmptyAndMultipleWildcardMatches | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `selectorGlobSupportsEmptyAndMultipleWildcardMatches` |
| 8 | EditorFeatureAndState | pluginAPIVersionsRequireMatchingMajorAndNonNewerMinor | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `pluginAPIVersionsRequireMatchingMajorAndNonNewerMinor` |
| 9 | EditorFeatureAndState | workbenchResolvesActiveGroupTabAndFlattenedTabs | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `workbenchResolvesActiveGroupTabAndFlattenedTabs` |
| 10 | EditorFeatureAndState | diagnosticsSnapshotCountsOnlyErrorsAndWarnings | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `diagnosticsSnapshotCountsOnlyErrorsAndWarnings` |
| 11 | EditorPositionAndDocument | positionsCompareByLineThenUTF16Character | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `positionsCompareByLineThenUTF16Character` |
| 12 | EditorPositionAndDocument | rangesNormalizeAndUseHalfOpenOverlapSemantics | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `rangesNormalizeAndUseHalfOpenOverlapSemantics` |
| 13 | EditorPositionAndDocument | documentOffsetsRoundTripUsingUTF16ForLFAndCRLF | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `documentOffsetsRoundTripUsingUTF16ForLFAndCRLF` |
| 14 | EditorPositionAndDocument | emptyDocumentHasOneValidPositionAndSummaryOmitsText | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `emptyDocumentHasOneValidPositionAndSummaryOmitsText` |

> 说明：全部 **14 条场景**已在本包 `swift test` 中实跑通过。
> 用例名与描述取自 `Tests/` 下的真实 `@Test` 声明，改动测试时须同步本表。

## 覆盖率统计

- P0: 已覆盖 0 / 0
- P1: 已覆盖 11 / 11
- P2: 已覆盖 3 / 3
- **合计: 14 / 14**（仅表示清单场景，非源码覆盖率）

## 优先级说明

- **P0**: 描述/名称含崩溃、泄漏、截断、丢失、竞态、超时、必须、不得、重试等失效类信号的用例（0 条）
- **P1**: 其余功能性用例（11 条）
- **P2**: 稳定常量、占位、文案、空集合等边界用例（3 条）

## 跨平台说明

- Package 声明: macOS 14+, iOS 17+
- 14 条用例位于 `Tests/`，需在目标平台执行 `swift test`

## 测试执行

```bash
cd Packages/ProviderEditor
swift test
```

## 维护规则

1. **新增公开 API** → 先在 TestPlan 登记测试用例，再写实现
2. **Bug 修复** → 追加回归用例，标注触发条件
3. **删除用例** → 在 commit message 说明理由
4. **状态同步** → 实现后更新 TestPlan，标记 ✅ 并填写测试方法名
5. **改名同步** → 重命名 `@Test` 函数后必须同步本表，否则 `Scripts/verify-testplan.py` 会报「登记方法在源码不存在」
