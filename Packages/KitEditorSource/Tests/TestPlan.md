# TestPlan — KitEditorSource

## 包概述

KitEditorSource 维护中的 CodeEdit 源码编辑器包（源自 CodeEditApp 的 `CodeEditSourceEditor`）。提供编辑器 UI 与文本编辑能力（语法高亮、Tree-sitter、查找替换等）。 ## 全局技术架构 Lumi 代码编辑器采用分层 + 插件扩展架构。完整说明见 [docs/editor-architecture.md](../../docs/editor-architecture.md)。 ```text 应用装配层 (LumiApp) ↓ 插件扩展层 (Packages/Plugin*) ↓ Host 内部服务 target (EditorService) ↓ ↓ 视图层 (EditorSource) 内核逻辑层 (EditorKernel) ↑ 本 Package ↓ 渲染基础层 (EditorTextView, EditorLanguages, EditorSymbols) ``` ## 本 Package 的位置 | 属性 | 值 | |------|-----| | **层级** | 视图层 | | **职责** | `SourceEditor` SwiftUI 组件；Tree-sitter 语法高亮管线；缩进与文本格式化规则 | | **上游依赖** | `EditorTextView`、`EditorLanguages`、`EditorSymbols`、`TextFormation` | | **下游消费者** | `EditorService`（`SourceEditorAdapter` 绑定）、`E

平台: macOS 14+, iOS 17+
测试文件: 14 个，用例总数: 68

核心组件（源码目录）:
- `EditorSource/`

## 公开 API

包内主要类型（按声明顺序抽取，供定位被测对象）:

- `EditorSourceLocalization`
- `EditorSourceSymbolsBundleToken`
- `CodeSuggestionDelegate`
- `CodeSuggestionEntry`
- `SuggestionTriggerCharacterModel`
- `SuggestionViewModel`
- `CodeSuggestionLabelView`
- `CodeSuggestionPreviewView`
- `CodeSuggestionRowView`
- `NoSlotScroller`
- `SuggestionViewController`
- `SuggestionController`
- `TextViewController`
- `BracketPairEmphasis`

## 关键行为契约（实现约定，非协议要求）

按测试模块归纳，改动对应模块时须保持既有断言成立:

- **CaptureModifier**（4 条）：由 `testStringValueFromStringRoundTrip`、`testFromStringRejectsUnknownStrings`、`testModifierSetInsertAndValues` 等用例锁定；改动该模块时优先跑对应测试文件。
- **DocumentHighlightCache**（4 条）：由 `testSameContentProducesSameKey`、`testEditedContentChangesDigest`、`testCacheHitMissAndLRU` 等用例锁定；改动该模块时优先跑对应测试文件。
- **EditorSourcePureLogic**（5 条）：由 `testBracketPairsMatching`、`testIndentOptionStringAndCount`、`testColorHexRoundTrip` 等用例锁定；改动该模块时优先跑对应测试文件。
- **CodeEditSymbols**（15 条）：由 `testAllImageStaticProperties`、`testImageInitWithSymbol`、`testImageInitWithFillVariants` 等用例锁定；改动该模块时优先跑对应测试文件。
- **Smoke**（1 条）：由 `testCanConstructImages` 等用例锁定；改动该模块时优先跑对应测试文件。
- **LineFoldCalculatorCrashRepro**（2 条）：由 `testBuildFoldsIgnoresOutOfBoundsFoldAndDoesNotCrash`、`testBuildFoldsIgnoresReverseRangeWhenClosingFold` 等用例锁定；改动该模块时优先跑对应测试文件。
- **MarkdownHighlightOverlap**（5 条）：由 `testStyledRangeContainerWithConflictingCaptures`、`testHighlightRangeOverlapDetection`、`testMultipleOverlappingHighlights` 等用例锁定；改动该模块时优先跑对应测试文件。
- **SourceEditorCore**（13 条）：由 `testFindMethodDisplayNames`、`testFindPanelModeDisplayNames`、`testFindPanelClearsStaleCurrentMatchIndex` 等用例锁定；改动该模块时优先跑对应测试文件。
- **StyledRangeContainerExport**（6 条）：由 `testExportHighlightRangesReturnsOnlyNonEmptyCaptures`、`testExportHighlightRangesForUnknownProviderIsEmpty`、`testExportHighlightRangesAfterStorageUpdateShiftsRanges` 等用例锁定；改动该模块时优先跑对应测试文件。
- **SyntaxHighlightRestorer**（1 条）：由 `testRestoreAppliesCaptureBeforeAsyncHighlight` 等用例锁定；改动该模块时优先跑对应测试文件。
- **TreeSitterDocumentStore**（1 条）：由 `testReattachSameDocumentKeyReusesStateWithoutCancelledQuery` 等用例锁定；改动该模块时优先跑对应测试文件。
- **TreeSitterHighlight**（6 条）：由 `testQueryHighlightsWithoutStateReturnsCancelled`、`testSetUpPostsStateDidUpdateNotification`、`testQueryHighlightsAfterSyncSetUpReturnsSuccess` 等用例锁定；改动该模块时优先跑对应测试文件。
- **TreeSitterLargeFilePerformance**（5 条）：由 `testTreeSitterStateInitialization`、`testHighlightQueryPerformance`、`testIncrementalParseAfterEdit` 等用例锁定；改动该模块时优先跑对应测试文件。

## 测试用例清单

| ID | 类别 | 描述 | 前置条件 | 操作步骤 | 预期结果 | 优先级 | 状态 | 测试方法 |
|----|------|------|----------|----------|----------|------|------|----------|
| 1 | CaptureModifier | testStringValueFromStringRoundTrip | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testStringValueFromStringRoundTrip` |
| 2 | CaptureModifier | testFromStringRejectsUnknownStrings | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `testFromStringRejectsUnknownStrings` |
| 3 | CaptureModifier | testModifierSetInsertAndValues | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testModifierSetInsertAndValues` |
| 4 | CaptureModifier | testModifierSetValuesIgnoresGarbageBits | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testModifierSetValuesIgnoresGarbageBits` |
| 5 | DocumentHighlightCache | testSameContentProducesSameKey | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testSameContentProducesSameKey` |
| 6 | DocumentHighlightCache | testEditedContentChangesDigest | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testEditedContentChangesDigest` |
| 7 | DocumentHighlightCache | testCacheHitMissAndLRU | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testCacheHitMissAndLRU` |
| 8 | DocumentHighlightCache | testHighlightRevisionBumpInvalidatesEntries | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `testHighlightRevisionBumpInvalidatesEntries` |
| 9 | EditorSourcePureLogic | testBracketPairsMatching | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testBracketPairsMatching` |
| 10 | EditorSourcePureLogic | testIndentOptionStringAndCount | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testIndentOptionStringAndCount` |
| 11 | EditorSourcePureLogic | testColorHexRoundTrip | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testColorHexRoundTrip` |
| 12 | EditorSourcePureLogic | testStringNSRangeSubscript | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testStringNSRangeSubscript` |
| 13 | EditorSourcePureLogic | testStringNSRangeSubscriptWithEmoji | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testStringNSRangeSubscriptWithEmoji` |
| 14 | CodeEditSymbols | testAllImageStaticProperties | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testAllImageStaticProperties` |
| 15 | CodeEditSymbols | testImageInitWithSymbol | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testImageInitWithSymbol` |
| 16 | CodeEditSymbols | testImageInitWithFillVariants | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testImageInitWithFillVariants` |
| 17 | CodeEditSymbols | testImageInitWithCompoundNames | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testImageInitWithCompoundNames` |
| 18 | CodeEditSymbols | testImageInitWithDocVariants | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testImageInitWithDocVariants` |
| 19 | CodeEditSymbols | testImageInitWithNonexistentSymbol | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testImageInitWithNonexistentSymbol` |
| 20 | CodeEditSymbols | testNSImageStaticPropertiesCreation | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testNSImageStaticPropertiesCreation` |
| 21 | CodeEditSymbols | testNSImageSymbolMethodExecution | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testNSImageSymbolMethodExecution` |
| 22 | CodeEditSymbols | testNSImageSymbolMethodWithCompoundNames | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testNSImageSymbolMethodWithCompoundNames` |
| 23 | CodeEditSymbols | testNSImageSymbolMethodWithDocVariants | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testNSImageSymbolMethodWithDocVariants` |
| 24 | CodeEditSymbols | testNSImageSymbolMethodWithNonexistentName | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testNSImageSymbolMethodWithNonexistentName` |
| 25 | CodeEditSymbols | testNSImageSymbolMethodMultipleCalls | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testNSImageSymbolMethodMultipleCalls` |
| 26 | CodeEditSymbols | testBundleAccess | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testBundleAccess` |
| 27 | CodeEditSymbols | testMultipleBundleCandidates | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testMultipleBundleCandidates` |
| 28 | CodeEditSymbols | testBundleResilience | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testBundleResilience` |
| 29 | Smoke | testCanConstructImages | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testCanConstructImages` |
| 30 | LineFoldCalculatorCrashRepro | testBuildFoldsIgnoresOutOfBoundsFoldAndDoesNotCrash | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `testBuildFoldsIgnoresOutOfBoundsFoldAndDoesNotCrash` |
| 31 | LineFoldCalculatorCrashRepro | testBuildFoldsIgnoresReverseRangeWhenClosingFold | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testBuildFoldsIgnoresReverseRangeWhenClosingFold` |
| 32 | MarkdownHighlightOverlap | testStyledRangeContainerWithConflictingCaptures | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testStyledRangeContainerWithConflictingCaptures` |
| 33 | MarkdownHighlightOverlap | testHighlightRangeOverlapDetection | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testHighlightRangeOverlapDetection` |
| 34 | MarkdownHighlightOverlap | testMultipleOverlappingHighlights | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testMultipleOverlappingHighlights` |
| 35 | MarkdownHighlightOverlap | testOverlappingRangesShouldBeDeduplicated | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testOverlappingRangesShouldBeDeduplicated` |
| 36 | MarkdownHighlightOverlap | testQueryHighlightsShouldNotReturnOverlappingRanges | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testQueryHighlightsShouldNotReturnOverlappingRanges` |
| 37 | SourceEditorCore | testFindMethodDisplayNames | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testFindMethodDisplayNames` |
| 38 | SourceEditorCore | testFindPanelModeDisplayNames | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testFindPanelModeDisplayNames` |
| 39 | SourceEditorCore | testFindPanelClearsStaleCurrentMatchIndex | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testFindPanelClearsStaleCurrentMatchIndex` |
| 40 | SourceEditorCore | testFindPanelKeepsValidCurrentMatchIndex | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testFindPanelKeepsValidCurrentMatchIndex` |
| 41 | SourceEditorCore | testFindPanelReplacementShiftsLaterMatchesByReplacementDelta | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testFindPanelReplacementShiftsLaterMatchesByReplacementDelta` |
| 42 | SourceEditorCore | testInvisibleCharactersEmptyDisablesAllTriggers | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `testInvisibleCharactersEmptyDisablesAllTriggers` |
| 43 | SourceEditorCore | testInvisibleCharactersTriggerCharactersFollowEnabledGroups | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testInvisibleCharactersTriggerCharactersFollowEnabledGroups` |
| 44 | SourceEditorCore | testInvisibleCharactersCodableRoundTripPreservesReplacements | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testInvisibleCharactersCodableRoundTripPreservesReplacements` |
| 45 | SourceEditorCore | testTreeSitterByteRangeDoublesUTF16Offsets | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testTreeSitterByteRangeDoublesUTF16Offsets` |
| 46 | SourceEditorCore | testTreeSitterByteRangeRejectsNegativeRanges | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `testTreeSitterByteRangeRejectsNegativeRanges` |
| 47 | SourceEditorCore | testTreeSitterByteRangeRejectsOverflowingRanges | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `testTreeSitterByteRangeRejectsOverflowingRanges` |
| 48 | SourceEditorCore | testRangeStoreIgnoresInvalidStorageEditRanges | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `testRangeStoreIgnoresInvalidStorageEditRanges` |
| 49 | SourceEditorCore | testRangeStoreIgnoresOverflowingStorageEditRanges | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testRangeStoreIgnoresOverflowingStorageEditRanges` |
| 50 | StyledRangeContainerExport | testExportHighlightRangesReturnsOnlyNonEmptyCaptures | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `testExportHighlightRangesReturnsOnlyNonEmptyCaptures` |
| 51 | StyledRangeContainerExport | testExportHighlightRangesForUnknownProviderIsEmpty | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `testExportHighlightRangesForUnknownProviderIsEmpty` |
| 52 | StyledRangeContainerExport | testExportHighlightRangesAfterStorageUpdateShiftsRanges | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testExportHighlightRangesAfterStorageUpdateShiftsRanges` |
| 53 | StyledRangeContainerExport | testThrowOrReturnSuccess | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testThrowOrReturnSuccess` |
| 54 | StyledRangeContainerExport | testThrowOrReturnFailureThrows | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testThrowOrReturnFailureThrows` |
| 55 | StyledRangeContainerExport | testIsSuccess | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testIsSuccess` |
| 56 | SyntaxHighlightRestorer | testRestoreAppliesCaptureBeforeAsyncHighlight | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testRestoreAppliesCaptureBeforeAsyncHighlight` |
| 57 | TreeSitterDocumentStore | testReattachSameDocumentKeyReusesStateWithoutCancelledQuery | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testReattachSameDocumentKeyReusesStateWithoutCancelledQuery` |
| 58 | TreeSitterHighlight | testQueryHighlightsWithoutStateReturnsCancelled | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testQueryHighlightsWithoutStateReturnsCancelled` |
| 59 | TreeSitterHighlight | testSetUpPostsStateDidUpdateNotification | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testSetUpPostsStateDidUpdateNotification` |
| 60 | TreeSitterHighlight | testQueryHighlightsAfterSyncSetUpReturnsSuccess | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testQueryHighlightsAfterSyncSetUpReturnsSuccess` |
| 61 | TreeSitterHighlight | testSetLanguageDoesNotClearExistingAttributesWhenPolicyPreserve | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testSetLanguageDoesNotClearExistingAttributesWhenPolicyPreserve` |
| 62 | TreeSitterHighlight | testCancelledQueryDoesNotApplyHighlightsUntilRetrySucceeds | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `testCancelledQueryDoesNotApplyHighlightsUntilRetrySucceeds` |
| 63 | TreeSitterHighlight | testCancelledQueryDoesNotApplyHighlightsImmediately | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testCancelledQueryDoesNotApplyHighlightsImmediately` |
| 64 | TreeSitterLargeFilePerformance | testTreeSitterStateInitialization | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testTreeSitterStateInitialization` |
| 65 | TreeSitterLargeFilePerformance | testHighlightQueryPerformance | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testHighlightQueryPerformance` |
| 66 | TreeSitterLargeFilePerformance | testIncrementalParseAfterEdit | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testIncrementalParseAfterEdit` |
| 67 | TreeSitterLargeFilePerformance | testFullFileHighlighting | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testFullFileHighlighting` |
| 68 | TreeSitterLargeFilePerformance | testDifferentLanguageParsing | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testDifferentLanguageParsing` |

> 说明：全部 **68 条场景**已在本包 `swift test` 中实跑通过。
> 用例名与描述取自 `Tests/` 下的真实 `@Test` 声明，改动测试时须同步本表。

## 覆盖率统计

- P0: 已覆盖 7 / 7
- P1: 已覆盖 58 / 58
- P2: 已覆盖 3 / 3
- **合计: 68 / 68**（仅表示清单场景，非源码覆盖率）

## 优先级说明

- **P0**: 描述/名称含崩溃、泄漏、截断、丢失、竞态、超时、必须、不得、重试等失效类信号的用例（7 条）
- **P1**: 其余功能性用例（58 条）
- **P2**: 稳定常量、占位、文案、空集合等边界用例（3 条）

## 跨平台说明

- Package 声明: macOS 14+, iOS 17+
- 68 条用例位于 `Tests/`，需在目标平台执行 `swift test`

## 测试执行

```bash
cd Packages/KitEditorSource
swift test
```

## 维护规则

1. **新增公开 API** → 先在 TestPlan 登记测试用例，再写实现
2. **Bug 修复** → 追加回归用例，标注触发条件
3. **删除用例** → 在 commit message 说明理由
4. **状态同步** → 实现后更新 TestPlan，标记 ✅ 并填写测试方法名
5. **改名同步** → 重命名 `@Test` 函数后必须同步本表，否则 `Scripts/verify-testplan.py` 会报「登记方法在源码不存在」
