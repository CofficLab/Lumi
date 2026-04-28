#if canImport(XCTest)
import XCTest
@testable import Lumi

final class LineEditingControllerTests: XCTestCase {

    // MARK: - Delete Line

    func testDeleteSingleLine() {
        let text = "line1\nline2\nline3"
        let selection = NSRange(location: 6, length: 0) // cursor on line2
        let result = LineEditingController.deleteLine(in: text, selections: [selection])
        XCTAssertNotNil(result)
        XCTAssertEqual(result!.replacementText, "line1\nline3")
    }

    func testDeleteFirstLine() {
        let text = "line1\nline2\nline3"
        let selection = NSRange(location: 0, length: 0) // cursor on line1
        let result = LineEditingController.deleteLine(in: text, selections: [selection])
        XCTAssertNotNil(result)
        XCTAssertEqual(result!.replacementText, "line2\nline3")
    }

    func testDeleteLastLine() {
        let text = "line1\nline2\nline3"
        let selection = NSRange(location: 12, length: 0) // cursor on line3
        let result = LineEditingController.deleteLine(in: text, selections: [selection])
        XCTAssertNotNil(result)
        XCTAssertEqual(result!.replacementText, "line1\nline2")
    }

    func testDeleteOnlyLine() {
        let text = "only line"
        let selection = NSRange(location: 0, length: 0)
        let result = LineEditingController.deleteLine(in: text, selections: [selection])
        XCTAssertNotNil(result)
        XCTAssertEqual(result!.replacementText, "")
    }

    func testDeleteLineWithSelection() {
        let text = "line1\nline2\nline3"
        let selection = NSRange(location: 6, length: 3) // selecting "lin" on line2
        let result = LineEditingController.deleteLine(in: text, selections: [selection])
        XCTAssertNotNil(result)
        XCTAssertEqual(result!.replacementText, "line1\nline3")
    }

    // MARK: - Copy Line

    func testCopyLineDown() {
        let text = "aaa\nbbb\nccc"
        let selection = NSRange(location: 4, length: 0) // cursor on "bbb"
        let result = LineEditingController.copyLineDown(in: text, selections: [selection])
        XCTAssertNotNil(result)
        XCTAssertEqual(result!.replacementText, "aaa\nbbb\nbbb\nccc")
    }

    func testCopyLineUp() {
        let text = "aaa\nbbb\nccc"
        let selection = NSRange(location: 4, length: 0) // cursor on "bbb"
        let result = LineEditingController.copyLineUp(in: text, selections: [selection])
        XCTAssertNotNil(result)
        XCTAssertEqual(result!.replacementText, "aaa\nbbb\nbbb\nccc")
    }

    func testCopyLineDownFirstLine() {
        let text = "aaa\nbbb"
        let selection = NSRange(location: 0, length: 0) // cursor on "aaa"
        let result = LineEditingController.copyLineDown(in: text, selections: [selection])
        XCTAssertNotNil(result)
        XCTAssertEqual(result!.replacementText, "aaa\naaa\nbbb")
    }

    func testCopyLineDownLastLine() {
        let text = "aaa\nbbb"
        let selection = NSRange(location: 4, length: 0) // cursor on "bbb"
        let result = LineEditingController.copyLineDown(in: text, selections: [selection])
        XCTAssertNotNil(result)
        XCTAssertEqual(result!.replacementText, "aaa\nbbb\nbbb")
    }

    // MARK: - Move Line

    func testMoveLineDown() {
        let text = "aaa\nbbb\nccc"
        let selection = NSRange(location: 0, length: 0) // cursor on "aaa"
        let result = LineEditingController.moveLineDown(in: text, selections: [selection])
        XCTAssertNotNil(result)
        XCTAssertEqual(result!.replacementText, "bbb\naaa\nccc")
    }

    func testMoveLineUp() {
        let text = "aaa\nbbb\nccc"
        let selection = NSRange(location: 8, length: 0) // cursor on "ccc"
        let result = LineEditingController.moveLineUp(in: text, selections: [selection])
        XCTAssertNotNil(result)
        XCTAssertEqual(result!.replacementText, "aaa\nccc\nbbb")
    }

    func testMoveLineUpOnFirstLineReturnsNil() {
        let text = "aaa\nbbb"
        let selection = NSRange(location: 0, length: 0) // cursor on first line
        let result = LineEditingController.moveLineUp(in: text, selections: [selection])
        XCTAssertNil(result)
    }

    func testMoveLineDownOnLastLineReturnsNil() {
        let text = "aaa\nbbb"
        let selection = NSRange(location: 4, length: 0) // cursor on last line
        let result = LineEditingController.moveLineDown(in: text, selections: [selection])
        XCTAssertNil(result)
    }

    // MARK: - Insert Line

    func testInsertLineBelow() {
        let text = "  hello"
        let selection = NSRange(location: 3, length: 0)
        let result = LineEditingController.insertLineBelow(in: text, selections: [selection])
        XCTAssertNotNil(result)
        XCTAssertEqual(result!.replacementText, "  hello\n  ")
        // 光标应在新行的缩进后
        XCTAssertNotNil(result!.selectedRanges.first)
        XCTAssertEqual(result!.selectedRanges.first!.location, 9) // "  hello\n  ".count = 9, 光标在末尾
    }

    func testInsertLineAbove() {
        let text = "  hello"
        let selection = NSRange(location: 3, length: 0)
        let result = LineEditingController.insertLineAbove(in: text, selections: [selection])
        XCTAssertNotNil(result)
        XCTAssertEqual(result!.replacementText, "  \n  hello")
        // 光标应在新行的缩进后
        XCTAssertNotNil(result!.selectedRanges.first)
        XCTAssertEqual(result!.selectedRanges.first!.location, 2) // "  ".count = 2
    }

    func testInsertLineBelowInMiddle() {
        let text = "line1\n  line2\nline3"
        let selection = NSRange(location: 8, length: 0) // cursor on "  line2"
        let result = LineEditingController.insertLineBelow(in: text, selections: [selection])
        XCTAssertNotNil(result)
        XCTAssertEqual(result!.replacementText, "line1\n  line2\n  \nline3")
    }

    // MARK: - Sort Lines

    func testSortLinesAscending() {
        let text = "cherry\napple\nbanana"
        let selection = NSRange(location: 0, length: (text as NSString).length)
        let result = LineEditingController.sortLines(in: text, selections: [selection], descending: false)
        XCTAssertNotNil(result)
        XCTAssertEqual(result!.replacementText, "apple\nbanana\ncherry")
    }

    func testSortLinesDescending() {
        let text = "apple\ncherry\nbanana"
        let selection = NSRange(location: 0, length: (text as NSString).length)
        let result = LineEditingController.sortLines(in: text, selections: [selection], descending: true)
        XCTAssertNotNil(result)
        XCTAssertEqual(result!.replacementText, "cherry\nbanana\napple")
    }

    func testSortLinesSingleLineReturnsNil() {
        let text = "only"
        let selection = NSRange(location: 0, length: 4)
        let result = LineEditingController.sortLines(in: text, selections: [selection], descending: false)
        XCTAssertNil(result)
    }

    func testSortLinesNoSelectionReturnsNil() {
        let text = "cherry\napple"
        let selection = NSRange(location: 0, length: 0)
        let result = LineEditingController.sortLines(in: text, selections: [selection], descending: false)
        XCTAssertNil(result)
    }

    // MARK: - Toggle Line Comment

    func testToggleCommentAdd() {
        let text = "hello\nworld"
        let selection = NSRange(location: 0, length: 0) // cursor on first line
        let result = LineEditingController.toggleLineComment(
            in: text, selections: [selection], commentPrefix: "//"
        )
        XCTAssertNotNil(result)
        XCTAssertEqual(result!.replacementText, "// hello\nworld")
    }

    func testToggleCommentRemove() {
        let text = "// hello\nworld"
        let selection = NSRange(location: 0, length: 0)
        let result = LineEditingController.toggleLineComment(
            in: text, selections: [selection], commentPrefix: "//"
        )
        XCTAssertNotNil(result)
        XCTAssertEqual(result!.replacementText, "hello\nworld")
    }

    func testToggleCommentRemoveWithSpace() {
        let text = "//  hello\nworld"
        let selection = NSRange(location: 0, length: 0)
        let result = LineEditingController.toggleLineComment(
            in: text, selections: [selection], commentPrefix: "//"
        )
        XCTAssertNotNil(result)
        XCTAssertEqual(result!.replacementText, " hello\nworld")
    }

    // MARK: - Merge Ranges

    func testMergeOverlappingRanges() {
        let ranges = [
            NSRange(location: 0, length: 5),
            NSRange(location: 3, length: 5),
            NSRange(location: 10, length: 3),
        ]
        let merged = LineEditingController.mergeOverlappingRanges(ranges)
        XCTAssertEqual(merged.count, 2)
        XCTAssertEqual(merged[0], NSRange(location: 0, length: 8))
        XCTAssertEqual(merged[1], NSRange(location: 10, length: 3))
    }

    func testMergeAdjacentRanges() {
        let ranges = [
            NSRange(location: 0, length: 5),
            NSRange(location: 5, length: 5),
        ]
        let merged = LineEditingController.mergeOverlappingRanges(ranges)
        XCTAssertEqual(merged.count, 1)
        XCTAssertEqual(merged[0], NSRange(location: 0, length: 10))
    }

    func testMergeNonOverlappingRanges() {
        let ranges = [
            NSRange(location: 10, length: 3),
            NSRange(location: 0, length: 5),
        ]
        let merged = LineEditingController.mergeOverlappingRanges(ranges)
        XCTAssertEqual(merged.count, 2)
        XCTAssertEqual(merged[0], NSRange(location: 0, length: 5))
        XCTAssertEqual(merged[1], NSRange(location: 10, length: 3))
    }
}

#endif
