# TestPlan — KitEditorTextView

## 包概述

KitEditorTextView 面向代码文档的高性能文本视图（源自 CodeEditApp 的 [EditorCodeEditTextView](https://github.com/CodeEditApp/EditorCodeEditTextView)）。提供自研 `TextView`（`NSView`），用于替代部分场景下的 `NSTextView`，支持快速布局与大文档编辑。 ## 全局技术架构 Lumi 代码编辑器采用分层 + 插件扩展架构。完整说明见 [docs/plans/2026-06-13-editor-architecture.md](../../../docs/plans/2026-06-13-editor-architecture.md)。 ```text 应用装配层 (LumiApp) ↓ 插件扩展层 (Packages/Plugin*) ↓ Host 内部服务 target (EditorService) ↓ ↓ 视图层 (EditorSource) 内核逻辑层 (EditorKernel) ↓ 渲染基础层 (EditorTextView, EditorLanguages, EditorSymbols) ↑ 本 Kit package ``` ## 本 Package 的位置 | 属性 | 值 | |------|-----| | **层级** | 渲染基础层 | | **职责** | 高性能 `NSView` 文本渲染、布局、输入处理；大文档编辑性能优化 | | **上游依赖** | `TextStory`、`swift-collections` | | **下游消费者** | `EditorSource`（核心文

平台: macOS 14+, iOS 17+
测试文件: 14 个，用例总数: 93

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
- **IME proposedRange 越界**（#574，5 条）：`TextView.attributedSubstring(forProposedRange:actualRange:)` 对完全落在文档之外的非空请求必须返回 nil，不得把 `{0,0}` 交集扩成首字符；部分相交返回交集并设置 actualRange，文档内零长度请求仍返回光标处字符（非 nil），保持既有行为。由 `EditorTextViewProposedRangeTests` 锁定。
- **词级移动 UTF-16 长度**（#575，4 条）：`TextSelectionManager.rangeOfSelection(...destination: .word)` 累加范围必须用 UTF-16 长度 `(substring as NSString).length`，不得用 `substring.count`，否则 emoji 代理对被劈开；前向/后向词级移动跨越 emoji 时返回完整 UTF-16 范围。由 `EditorTextViewWordUTF16Tests` 锁定。
- **IME selectedRange 映射**（#576，4 条）：`TextView.setMarkedText(_:selectedRange:replacementRange:)` 必须把输入法给出的 `selectedRange`（相对插入串起点）映射为绝对选区 `markedRange.location + selectedRange.location`，不得一律跳到组合末尾；`selectedRange.location == NSNotFound` 时回退到 `markedRange.max`，保持既有行为。由 `EditorTextViewMarkedTextSelectionTests` 锁定。

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

### IME proposedRange 越界（回归 #574）

| ID | 类别 | 描述 | 前置条件 | 操作步骤 | 预期结果 | 优先级 | 状态 | 测试方法 |
|----|------|------|----------|----------|----------|------|------|----------|
| 81 | IME proposedRange 越界 | 完全越界的 proposedRange 必须返回 nil，不得返回首字符（回归 #574） | TextView(string: "abc") | `attributedSubstring(forProposedRange: NSRange(10,1), actualRange: nil)` | 返回 nil | P0 | ✅ 已覆盖 | `test_proposedRangeCompletelyOutsideReturnsNil` |
| 82 | IME proposedRange 越界 | 起点落在文档末尾之外的 proposedRange 返回 nil（回归 #574） | TextView(string: "abc") | `attributedSubstring(forProposedRange: NSRange(3,1), actualRange: nil)` | 返回 nil | P0 | ✅ 已覆盖 | `test_proposedRangeStartingAtDocumentEndReturnsNil` |
| 83 | IME proposedRange 越界 | 部分相交的 proposedRange 返回交集内容并设置 actualRange（回归 #574） | TextView(string: "abc") | `attributedSubstring(forProposedRange: NSRange(2,5), actualRange: &actual)` | 返回 "c"，actualRange == {2,1} | P1 | ✅ 已覆盖 | `test_proposedRangePartialIntersectionReturnsIntersection` |
| 84 | IME proposedRange 越界 | 完全落在文档内的 proposedRange 返回完整子串（回归 #574） | TextView(string: "abc") | `attributedSubstring(forProposedRange: NSRange(0,3), actualRange: &actual)` | 返回 "abc"，actualRange == {0,3} | P1 | ✅ 已覆盖 | `test_proposedRangeFullyInsideReturnsFullSubstring` |
| 85 | IME proposedRange 越界 | 文档内零长度 proposedRange 返回光标处字符而非 nil，保持既有行为（回归 #574） | TextView(string: "abc") | `attributedSubstring(forProposedRange: NSRange(1,0), actualRange: nil)` | 返回非 nil，内容为光标处字符 "b" | P1 | ✅ 已覆盖 | `test_proposedRangeZeroLengthInsideReturnsCharacterAtCaret` |

### 词级移动 UTF-16 长度（回归 #575）

| ID | 类别 | 描述 | 前置条件 | 操作步骤 | 预期结果 | 优先级 | 状态 | 测试方法 |
|----|------|------|----------|----------|----------|------|------|----------|
| 86 | 词级移动 UTF-16 长度 | 后向词级移动跨越 emoji 必须返回完整 UTF-16 范围，不得劈开代理对（回归 #575） | TextSelectionManager("😀") | `rangeOfSelection(from: 2, direction: .backward, destination: .word)` | 返回 {0,2} | P0 | ✅ 已覆盖 | `test_backwardWordOverEmojiReturnsFullUTF16Range` |
| 87 | 词级移动 UTF-16 长度 | 前向词级移动跨越 emoji 必须返回完整 UTF-16 范围，不得劈开代理对（回归 #575） | TextSelectionManager("😀") | `rangeOfSelection(from: 0, direction: .forward, destination: .word)` | 返回 {0,2} | P0 | ✅ 已覆盖 | `test_forwardWordOverEmojiReturnsFullUTF16Range` |
| 88 | 词级移动 UTF-16 长度 | 后向词级移动跨越混合字符串尾部 emoji 返回完整 UTF-16 范围（回归 #575） | TextSelectionManager("ab😀") | `rangeOfSelection(from: 4, direction: .backward, destination: .word)` | 返回 {0,4} | P1 | ✅ 已覆盖 | `test_backwardWordOverTrailingEmojiInMixedString` |
| 89 | 词级移动 UTF-16 长度 | 前向词级移动跨越混合字符串首部 emoji 返回完整 UTF-16 范围（回归 #575） | TextSelectionManager("😀cd") | `rangeOfSelection(from: 0, direction: .forward, destination: .word)` | 返回 {0,4} | P1 | ✅ 已覆盖 | `test_forwardWordOverLeadingEmojiInMixedString` |

### IME selectedRange 映射（回归 #576）

| ID | 类别 | 描述 | 前置条件 | 操作步骤 | 预期结果 | 优先级 | 状态 | 测试方法 |
|----|------|------|----------|----------|----------|------|------|----------|
| 90 | IME selectedRange 映射 | setMarkedText 必须采用输入法相对 selectedRange，不得一律跳到组合末尾（回归 #576） | TextView(string: "")，光标 {0,0} | `setMarkedText("abc", selectedRange: {1,1}, replacementRange: .notFound)` | string=="abc"，selections==[{1,1}] | P0 | ✅ 已覆盖 | `test_setMarkedTextHonorsRelativeSelectedRange` |
| 91 | IME selectedRange 映射 | selectedRange 起点为 0 时光标落在组合开头（回归 #576） | TextView(string: "")，光标 {0,0} | `setMarkedText("abc", selectedRange: {0,0}, replacementRange: .notFound)` | string=="abc"，selections==[{0,0}] | P1 | ✅ 已覆盖 | `test_setMarkedTextCaretAtStartFromSelectedRange` |
| 92 | IME selectedRange 映射 | selectedRange 为 NSNotFound 时回退到组合末尾，保持既有行为（回归 #576） | TextView(string: "")，光标 {0,0} | `setMarkedText("abc", selectedRange: .notFound, replacementRange: .notFound)` | string=="abc"，selections==[{3,0}] | P1 | ✅ 已覆盖 | `test_setMarkedTextNotFoundSelectedRangeFallsBackToEnd` |
| 93 | IME selectedRange 映射 | 替换已有组合文本时 selectedRange 仍相对新标记起点映射（回归 #576） | TextView(string: "")，先 setMarkedText("abc",{3,0}) | `setMarkedText("abcd", selectedRange: {2,1}, replacementRange: .notFound)` | string=="abcd"，selections==[{2,1}] | P1 | ✅ 已覆盖 | `test_setMarkedTextSelectedRangeMapsOntoExistingMarkedText` |

> 说明：全部 **93 条场景**已在本包 `swift test` 中实跑通过。
> 用例名与描述取自 `Tests/` 下的真实 `@Test` 声明，改动测试时须同步本表。
>
> 变异验证（#574）：M1 删除越界守卫 → 用例 81/82 失败（完全越界请求返回首字符 "a"）；M2 守卫放宽为 `clamped.length == 0` → 用例 85 失败（文档内零长度请求误返回 nil）；M3 守卫放宽为 `range.length > 0` → 用例 83/84 失败（部分相交/完全内含请求误返回 nil）。三处变异各自命中独立守卫，恢复后 85 条全绿。
>
> 变异验证（#575）：M1 把长度累加改回 `substring.count` → 用例 86/87/88/89 全部失败（范围长度少计 emoji 的 UTF-16 单元）；M2 把后向 location 递减改回 `substring.count` → 用例 86/88 失败（后向范围起点落在代理对中间），前向用例 87/89 不受影响。两处变异各自命中长度/位置独立守卫，恢复后 89 条全绿。
>
> 变异验证（#576）：M1 把选区映射改回一律 `NSRange(location: markedRange.max, length: 0)` → 用例 90/91/93 失败（选区跳到组合末尾而非输入法指定位置），用例 92（NSNotFound 回退）不受影响；M2 把 NSNotFound 回退分支改成 `markedRange.location` → 用例 92 失败（回退落到组合开头而非末尾），用例 90/91/93 不受影响。两处变异各自命中映射/回退独立守卫，恢复后 93 条全绿。

## 覆盖率统计

- P0: 已覆盖 9 / 9
- P1: 已覆盖 80 / 80
- P2: 已覆盖 4 / 4
- **合计: 93 / 93**（仅表示清单场景，非源码覆盖率）

## 优先级说明

- **P0**: 描述/名称含崩溃、泄漏、截断、丢失、竞态、超时、必须、不得、重试等失效类信号的用例（9 条）
- **P1**: 其余功能性用例（80 条）
- **P2**: 稳定常量、占位、文案、空集合等边界用例（4 条）

## 跨平台说明

- Package 声明: macOS 14+, iOS 17+
- 93 条用例位于 `Tests/`，需在目标平台执行 `swift test`

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
