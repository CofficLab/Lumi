# TestPlan — KitEditorTextView

## 包概述

KitEditorTextView 面向代码文档的高性能文本视图（源自 CodeEditApp 的 [EditorCodeEditTextView](https://github.com/CodeEditApp/EditorCodeEditTextView)）。提供自研 `TextView`（`NSView`），用于替代部分场景下的 `NSTextView`，支持快速布局与大文档编辑。 ## 全局技术架构 Lumi 代码编辑器采用分层 + 插件扩展架构。完整说明见 [docs/editor-architecture.md](../../docs/editor-architecture.md)。 ```text 应用装配层 (LumiApp) ↓ 插件扩展层 (Packages/Plugin*) ↓ Host 内部服务 target (EditorService) ↓ ↓ 视图层 (EditorSource) 内核逻辑层 (EditorKernel) ↓ 渲染基础层 (EditorTextView, EditorLanguages, EditorSymbols) ↑ 本 Kit package ``` ## 本 Package 的位置 | 属性 | 值 | |------|-----| | **层级** | 渲染基础层 | | **职责** | 高性能 `NSView` 文本渲染、布局、输入处理；大文档编辑性能优化 | | **上游依赖** | `TextStory`、`swift-collections` | | **下游消费者** | `EditorSource`（核心文

平台: macOS 14+, iOS 17+
测试文件: 11 个，用例总数: 80

核心组件（源码目录）:
- `NSRange+/`
- `TextAttachments/`
- `Typesetter/`
- `SelectionManipulation/`

## 公开 API

包内主要类型（按声明顺序抽取，供定位被测对象）:

- `CodeEditTextView`
- `CursorSelectionMode`
- `CursorTimer`
- `Emphasis`
- `EmphasisManager`
- `EmphasisStyle`
- `InvisibleCharacterStyle`
- `MarkedRanges`
- `MarkedTextManager`
- `EditorTextViewLocalization`
- `TextLayoutRangeValidator`
- `TextLayoutManager`
- `TextLayoutManagerDelegate`
- `TextLayoutManagerRenderDelegate`

## 关键行为契约（实现约定，非协议要求）

按测试模块归纳，改动对应模块时须保持既有断言成立:

- **EditorTextViewCore**（13 条）：由 `testNSRangeIsEmptyReflectsLength`、`testNSRangeTranslateMovesLocationOnly`、`testEmphasisStyleEqualityIncludesAssociatedValues` 等用例锁定；改动该模块时优先跑对应测试文件。
- **EditorTextViewKillRing**（4 条）：由 `test_killRingYank`、`test_killRingYankAndSelect`、`test_textViewYank` 等用例锁定；改动该模块时优先跑对应测试文件。
- **EditorTextViewLineEnding**（9 条）：由 `test_lineEndingCreateUnix`、`test_lineEndingCreateCRLF`、`test_lineEndingCreateMacOS` 等用例锁定；改动该模块时优先跑对应测试文件。
- **EditorTextViewLineStorage**（6 条）：由 `test_insert`、`test_update`、`test_delete` 等用例锁定；改动该模块时优先跑对应测试文件。
- **EditorTextViewMarkedText**（10 条）：由 `test_markedTextSingleChar`、`test_markedTextSingleCharInStrings`、`test_markedTextReplaceSelection` 等用例锁定；改动该模块时优先跑对应测试文件。
- **EditorTextViewMenuLocalization**（1 条）：由 `loadsSimplifiedChineseCutCopyPaste` 等用例锁定；改动该模块时优先跑对应测试文件。
- **EditorTextViewPureExtension**（6 条）：由 `testBoundingRect`、`testApproximateEqual`、`testGrayscale` 等用例锁定；改动该模块时优先跑对应测试文件。
- **EditorTextViewSelectionManipulation**（14 条）：由 `test_updateSelectionLeft`、`test_updateSelectionRight`、`test_updateSelectionLeftWord` 等用例锁定；改动该模块时优先跑对应测试文件。
- **EditorTextViewSelectionUpdate**（7 条）：由 `testPureInsertionBeforeCursorShiftsSelectionByInsertedLength`、`testPureDeletionBeforeCursorShiftsSelectionByDeletedLength`、`testAsymmetricReplacementBeforeCursorShiftsByLengthDelta` 等用例锁定；改动该模块时优先跑对应测试文件。
- **EditorTextViewTextView**（4 条）：由 `delegateChangesText`、`sharedTextStorage`、`customUndoManagerReceivesEvents` 等用例锁定；改动该模块时优先跑对应测试文件。
- **LargeFilePerformance**（6 条）：由 `testNSTextStorageInitialization`、`testTextViewCompleteInitialization`、`testVeryLargeFilePerformance` 等用例锁定；改动该模块时优先跑对应测试文件。

## 测试用例清单

| ID | 类别 | 描述 | 前置条件 | 操作步骤 | 预期结果 | 优先级 | 状态 | 测试方法 |
|----|------|------|----------|----------|----------|------|------|----------|
| 1 | EditorTextViewCore | testNSRangeIsEmptyReflectsLength | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `testNSRangeIsEmptyReflectsLength` |
| 2 | EditorTextViewCore | testNSRangeTranslateMovesLocationOnly | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testNSRangeTranslateMovesLocationOnly` |
| 3 | EditorTextViewCore | testEmphasisStyleEqualityIncludesAssociatedValues | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testEmphasisStyleEqualityIncludesAssociatedValues` |
| 4 | EditorTextViewCore | testEmphasisStyleShapeRadiusMatchesStyle | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testEmphasisStyleShapeRadiusMatchesStyle` |
| 5 | EditorTextViewCore | testSmoothPathSkipsConsecutiveDuplicatePoints | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testSmoothPathSkipsConsecutiveDuplicatePoints` |
| 6 | EditorTextViewCore | testDragSelectionRangeBuildsCharacterRangeBetweenOffsets | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testDragSelectionRangeBuildsCharacterRangeBetweenOffsets` |
| 7 | EditorTextViewCore | testLineEndingDetectsCarriageReturnLineFeedBeforeLineFeed | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testLineEndingDetectsCarriageReturnLineFeedBeforeLineFeed` |
| 8 | EditorTextViewCore | testDragSelectionRangeRejectsNegativeOffsets | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `testDragSelectionRangeRejectsNegativeOffsets` |
| 9 | EditorTextViewCore | testDragSelectionRangeEnclosesWordOrLineRanges | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testDragSelectionRangeEnclosesWordOrLineRanges` |
| 10 | EditorTextViewCore | testDragSelectionRangeRejectsOverflowingRanges | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `testDragSelectionRangeRejectsOverflowingRanges` |
| 11 | EditorTextViewCore | testTextLayoutRangeValidatorClampsOverflowingDocumentRanges | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testTextLayoutRangeValidatorClampsOverflowingDocumentRanges` |
| 12 | EditorTextViewCore | testTextLayoutRangeValidatorRejectsInvalidRanges | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `testTextLayoutRangeValidatorRejectsInvalidRanges` |
| 13 | EditorTextViewCore | testTextLayoutRangeValidatorKeepsValidEmptyRangesWhenAllowed | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `testTextLayoutRangeValidatorKeepsValidEmptyRangesWhenAllowed` |
| 14 | EditorTextViewKillRing | test_killRingYank | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `test_killRingYank` |
| 15 | EditorTextViewKillRing | test_killRingYankAndSelect | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `test_killRingYankAndSelect` |
| 16 | EditorTextViewKillRing | test_textViewYank | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `test_textViewYank` |
| 17 | EditorTextViewKillRing | test_textViewYankMultipleCursors | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `test_textViewYankMultipleCursors` |
| 18 | EditorTextViewLineEnding | test_lineEndingCreateUnix | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `test_lineEndingCreateUnix` |
| 19 | EditorTextViewLineEnding | test_lineEndingCreateCRLF | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `test_lineEndingCreateCRLF` |
| 20 | EditorTextViewLineEnding | test_lineEndingCreateMacOS | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `test_lineEndingCreateMacOS` |
| 21 | EditorTextViewLineEnding | test_lineEndingRejectsTextWithoutLineEnding | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `test_lineEndingRejectsTextWithoutLineEnding` |
| 22 | EditorTextViewLineEnding | test_detectLineEndingDefault | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `test_detectLineEndingDefault` |
| 23 | EditorTextViewLineEnding | test_detectLineEndingUnix | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `test_detectLineEndingUnix` |
| 24 | EditorTextViewLineEnding | test_detectLineEndingCRLF | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `test_detectLineEndingCRLF` |
| 25 | EditorTextViewLineEnding | test_detectLineEndingMacOS | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `test_detectLineEndingMacOS` |
| 26 | EditorTextViewLineEnding | test_detectLineEndingTieBreaksToLineFeed | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `test_detectLineEndingTieBreaksToLineFeed` |
| 27 | EditorTextViewLineStorage | test_insert | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `test_insert` |
| 28 | EditorTextViewLineStorage | test_update | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `test_update` |
| 29 | EditorTextViewLineStorage | test_delete | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `test_delete` |
| 30 | EditorTextViewLineStorage | test_getLineQueries | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `test_getLineQueries` |
| 31 | EditorTextViewLineStorage | test_buildFromTextStorageSplitsLines | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `test_buildFromTextStorageSplitsLines` |
| 32 | EditorTextViewLineStorage | test_transplantWithExistingLeftNodes | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `test_transplantWithExistingLeftNodes` |
| 33 | EditorTextViewMarkedText | test_markedTextSingleChar | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `test_markedTextSingleChar` |
| 34 | EditorTextViewMarkedText | test_markedTextSingleCharInStrings | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `test_markedTextSingleCharInStrings` |
| 35 | EditorTextViewMarkedText | test_markedTextReplaceSelection | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `test_markedTextReplaceSelection` |
| 36 | EditorTextViewMarkedText | test_markedTextMultipleSelection | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `test_markedTextMultipleSelection` |
| 37 | EditorTextViewMarkedText | test_markedTextMultipleSelectionReplaceSelection | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `test_markedTextMultipleSelectionReplaceSelection` |
| 38 | EditorTextViewMarkedText | test_markedTextMultipleSelectionMultipleChar | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `test_markedTextMultipleSelectionMultipleChar` |
| 39 | EditorTextViewMarkedText | test_cancelMarkedText | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `test_cancelMarkedText` |
| 40 | EditorTextViewMarkedText | test_cancelMarkedTextMultipleCursor | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `test_cancelMarkedTextMultipleCursor` |
| 41 | EditorTextViewMarkedText | test_markedTextManagerUpdateForNewSelections | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `test_markedTextManagerUpdateForNewSelections` |
| 42 | EditorTextViewMarkedText | test_markedTextManagerMarkedRangesInLine | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `test_markedTextManagerMarkedRangesInLine` |
| 43 | EditorTextViewMenuLocalization | loads simplified Chinese cut copy paste strings | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `loadsSimplifiedChineseCutCopyPaste` |
| 44 | EditorTextViewPureExtension | testBoundingRect | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testBoundingRect` |
| 45 | EditorTextViewPureExtension | testApproximateEqual | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testApproximateEqual` |
| 46 | EditorTextViewPureExtension | testGrayscale | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testGrayscale` |
| 47 | EditorTextViewPureExtension | testNSColorHexInit | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testNSColorHexInit` |
| 48 | EditorTextViewPureExtension | testPixelAligned | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testPixelAligned` |
| 49 | EditorTextViewPureExtension | testEmphasisDefaults | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `testEmphasisDefaults` |
| 50 | EditorTextViewSelectionManipulation | test_updateSelectionLeft | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `test_updateSelectionLeft` |
| 51 | EditorTextViewSelectionManipulation | test_updateSelectionRight | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `test_updateSelectionRight` |
| 52 | EditorTextViewSelectionManipulation | test_updateSelectionLeftWord | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `test_updateSelectionLeftWord` |
| 53 | EditorTextViewSelectionManipulation | test_updateSelectionRightWord | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `test_updateSelectionRightWord` |
| 54 | EditorTextViewSelectionManipulation | test_updateSelectionLeftLine | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `test_updateSelectionLeftLine` |
| 55 | EditorTextViewSelectionManipulation | test_updateSelectionRightLine | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `test_updateSelectionRightLine` |
| 56 | EditorTextViewSelectionManipulation | test_updateSelectionUpDocument | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `test_updateSelectionUpDocument` |
| 57 | EditorTextViewSelectionManipulation | test_updateSelectionDownDocument | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `test_updateSelectionDownDocument` |
| 58 | EditorTextViewSelectionManipulation | test_selectionEndOfDocumentHasXPos | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `test_selectionEndOfDocumentHasXPos` |
| 59 | EditorTextViewSelectionManipulation | test_moveSelectionsCharacterForwardAndBackward | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `test_moveSelectionsCharacterForwardAndBackward` |
| 60 | EditorTextViewSelectionManipulation | test_moveSelectionsCollapsesSelectionInDirection | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `test_moveSelectionsCollapsesSelectionInDirection` |
| 61 | EditorTextViewSelectionManipulation | test_moveSelectionsToDocumentBoundaries | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `test_moveSelectionsToDocumentBoundaries` |
| 62 | EditorTextViewSelectionManipulation | test_moveSelectionsByWord | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `test_moveSelectionsByWord` |
| 63 | EditorTextViewSelectionManipulation | test_moveSelectionsByLine | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `test_moveSelectionsByLine` |
| 64 | EditorTextViewSelectionUpdate | testPureInsertionBeforeCursorShiftsSelectionByInsertedLength | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testPureInsertionBeforeCursorShiftsSelectionByInsertedLength` |
| 65 | EditorTextViewSelectionUpdate | testPureDeletionBeforeCursorShiftsSelectionByDeletedLength | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testPureDeletionBeforeCursorShiftsSelectionByDeletedLength` |
| 66 | EditorTextViewSelectionUpdate | testAsymmetricReplacementBeforeCursorShiftsByLengthDelta | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testAsymmetricReplacementBeforeCursorShiftsByLengthDelta` |
| 67 | EditorTextViewSelectionUpdate | testShrinkingReplacementBeforeCursorShiftsBackwards | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testShrinkingReplacementBeforeCursorShiftsBackwards` |
| 68 | EditorTextViewSelectionUpdate | testCursorIntersectingReplacedRangeLandsAfterReplacement | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testCursorIntersectingReplacedRangeLandsAfterReplacement` |
| 69 | EditorTextViewSelectionUpdate | testCursorAtRangeMaxIsTreatedAsIntersecting | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testCursorAtRangeMaxIsTreatedAsIntersecting` |
| 70 | EditorTextViewSelectionUpdate | testDuplicateSelectionsAreRemovedAfterEdit | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testDuplicateSelectionsAreRemovedAfterEdit` |
| 71 | EditorTextViewTextView | delegateChangesText | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `delegateChangesText` |
| 72 | EditorTextViewTextView | sharedTextStorage | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `sharedTextStorage` |
| 73 | EditorTextViewTextView | Custom UndoManager class receives events | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `customUndoManagerReceivesEvents` |
| 74 | EditorTextViewTextView | Asymmetric replacement keeps later cursor position correct | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `asymmetricReplacementUpdatesLaterCursors` |
| 75 | LargeFilePerformance | testNSTextStorageInitialization | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testNSTextStorageInitialization` |
| 76 | LargeFilePerformance | testTextViewCompleteInitialization | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testTextViewCompleteInitialization` |
| 77 | LargeFilePerformance | testVeryLargeFilePerformance | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testVeryLargeFilePerformance` |
| 78 | LargeFilePerformance | test1KLines | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `test1KLines` |
| 79 | LargeFilePerformance | test5KLines | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `test5KLines` |
| 80 | LargeFilePerformance | test10KLines | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `test10KLines` |

> 说明：全部 **80 条场景**已在本包 `swift test` 中实跑通过。
> 用例名与描述取自 `Tests/` 下的真实 `@Test` 声明，改动测试时须同步本表。

## 覆盖率统计

- P0: 已覆盖 4 / 4
- P1: 已覆盖 72 / 72
- P2: 已覆盖 4 / 4
- **合计: 80 / 80**（仅表示清单场景，非源码覆盖率）

## 优先级说明

- **P0**: 描述/名称含崩溃、泄漏、截断、丢失、竞态、超时、必须、不得、重试等失效类信号的用例（4 条）
- **P1**: 其余功能性用例（72 条）
- **P2**: 稳定常量、占位、文案、空集合等边界用例（4 条）

## 跨平台说明

- Package 声明: macOS 14+, iOS 17+
- 80 条用例位于 `Tests/`，需在目标平台执行 `swift test`

## 测试执行

```bash
cd Packages/KitEditorTextView
swift test
```

## 维护规则

1. **新增公开 API** → 先在 TestPlan 登记测试用例，再写实现
2. **Bug 修复** → 追加回归用例，标注触发条件
3. **删除用例** → 在 commit message 说明理由
4. **状态同步** → 实现后更新 TestPlan，标记 ✅ 并填写测试方法名
5. **改名同步** → 重命名 `@Test` 函数后必须同步本表，否则 `Scripts/verify-testplan.py` 会报「登记方法在源码不存在」
