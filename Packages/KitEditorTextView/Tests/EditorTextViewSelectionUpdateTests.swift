import XCTest
@testable import EditorTextView

/// Tests for `TextSelectionManager.didReplaceCharacters` selection adjustment logic.
final class EditorTextViewSelectionUpdateTests: XCTestCase {
    private var textStorage: NSTextStorage!
    private var layoutManager: TextLayoutManager!
    private var selectionManager: TextSelectionManager!

    override func setUp() {
        super.setUp()
        textStorage = NSTextStorage(string: "abcdef")
        layoutManager = TextLayoutManager(
            textStorage: textStorage,
            lineHeightMultiplier: 1.0,
            wrapLines: false,
            textView: NSView(),
            delegate: nil
        )
        selectionManager = TextSelectionManager(
            layoutManager: layoutManager,
            textStorage: textStorage,
            textView: nil,
            delegate: nil
        )
    }

    private func selectionsAfterReplacing(
        _ range: NSRange,
        with replacement: String
    ) -> [NSRange] {
        selectionManager.setSelectedRange(NSRange(location: 5, length: 0))
        selectionManager.didReplaceCharacters(in: range, replacementLength: (replacement as NSString).length)
        return selectionManager.textSelections.map(\.range)
    }

    func testPureInsertionBeforeCursorShiftsSelectionByInsertedLength() {
        // Insert "XYZ" at (1, 0): cursor after the edit point shifts by 3.
        XCTAssertEqual(selectionsAfterReplacing(NSRange(location: 1, length: 0), with: "XYZ"),
                       [NSRange(location: 8, length: 0)])
    }

    func testPureDeletionBeforeCursorShiftsSelectionByDeletedLength() {
        // Delete "bc" (range (1,2)): cursor at 5 shifts to 3.
        XCTAssertEqual(selectionsAfterReplacing(NSRange(location: 1, length: 2), with: ""),
                       [NSRange(location: 3, length: 0)])
    }

    func testAsymmetricReplacementBeforeCursorShiftsByLengthDelta() {
        // Replace "bc" (2 chars) with "XYZ" (3 chars): net delta is +1, cursor at 5 -> 6.
        XCTAssertEqual(selectionsAfterReplacing(NSRange(location: 1, length: 2), with: "XYZ"),
                       [NSRange(location: 6, length: 0)])
    }

    func testShrinkingReplacementBeforeCursorShiftsBackwards() {
        // Replace "bcd" (3 chars) with "x" (1 char): net delta is -2, cursor at 5 -> 3.
        XCTAssertEqual(selectionsAfterReplacing(NSRange(location: 1, length: 3), with: "x"),
                       [NSRange(location: 3, length: 0)])
    }

    func testCursorIntersectingReplacedRangeLandsAfterReplacement() {
        selectionManager.setSelectedRange(NSRange(location: 1, length: 2))
        selectionManager.didReplaceCharacters(in: NSRange(location: 1, length: 2), replacementLength: 3)
        XCTAssertEqual(selectionManager.textSelections.map(\.range), [NSRange(location: 4, length: 0)])
    }

    func testCursorAtRangeMaxIsTreatedAsIntersecting() {
        selectionManager.setSelectedRange(NSRange(location: 3, length: 0))
        selectionManager.didReplaceCharacters(in: NSRange(location: 1, length: 2), replacementLength: 1)
        XCTAssertEqual(selectionManager.textSelections.map(\.range), [NSRange(location: 2, length: 0)])
    }

    func testDuplicateSelectionsAreRemovedAfterEdit() {
        selectionManager.setSelectedRanges([
            NSRange(location: 4, length: 2),
            NSRange(location: 0, length: 2)
        ])
        // Both selections intersect the replaced range (0, 6) and collapse to the same range.
        selectionManager.didReplaceCharacters(in: NSRange(location: 0, length: 6), replacementLength: 2)
        XCTAssertEqual(selectionManager.textSelections.count, 1)
        XCTAssertEqual(selectionManager.textSelections.first?.range, NSRange(location: 2, length: 0))
    }
}
