import CoreGraphics
import XCTest
@testable import BookletMakerPlugin

// MARK: - Booklet Layout Engine Tests

final class BookletLayoutEngineTests: XCTestCase {

    // MARK: - Padding

    func testPaddingEvenStaysUnchanged() {
        XCTAssertEqual(BookletLayoutEngine.padInputCount(4, pad: true), 4)
        XCTAssertEqual(BookletLayoutEngine.padInputCount(4, pad: false), 4)
    }

    func testPaddingOddGetsOneExtra() {
        XCTAssertEqual(BookletLayoutEngine.padInputCount(5, pad: true), 6)
    }

    func testPaddingOddWhenPadDisabled() {
        XCTAssertEqual(BookletLayoutEngine.padInputCount(5, pad: false), 5)
    }

    // MARK: - Sheet count

    func testSheetCountForEvenPaddedInputs() {
        XCTAssertEqual(BookletLayoutEngine.sheetCount(forPaddedInputCount: 2), 1)
        XCTAssertEqual(BookletLayoutEngine.sheetCount(forPaddedInputCount: 4), 2)
        XCTAssertEqual(BookletLayoutEngine.sheetCount(forPaddedInputCount: 6), 3)
        XCTAssertEqual(BookletLayoutEngine.sheetCount(forPaddedInputCount: 100), 50)
    }

    func testSheetCountForZeroIsZero() {
        XCTAssertEqual(BookletLayoutEngine.sheetCount(forPaddedInputCount: 0), 0)
    }

    // MARK: - Booklet fold mapping (the key business logic)

    private func assertFold(
        _ result: (left: Int, right: Int),
        left: Int,
        right: Int,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertEqual(result.left,  left,  "left mismatch",  file: file, line: line)
        XCTAssertEqual(result.right, right, "right mismatch", file: file, line: line)
    }

    func testBookletFold_N4() {
        // 4 pages → [1,4] [2,3]
        assertFold(BookletLayoutEngine.bookletFoldMapping(outputIndex: 0, paddedInputCount: 4),
                   left: 1, right: 4)
        assertFold(BookletLayoutEngine.bookletFoldMapping(outputIndex: 1, paddedInputCount: 4),
                   left: 2, right: 3)
    }

    func testBookletFold_N6() {
        // 6 pages → [1,6] [2,5] [3,4]
        assertFold(BookletLayoutEngine.bookletFoldMapping(outputIndex: 0, paddedInputCount: 6),
                   left: 1, right: 6)
        assertFold(BookletLayoutEngine.bookletFoldMapping(outputIndex: 1, paddedInputCount: 6),
                   left: 2, right: 5)
        assertFold(BookletLayoutEngine.bookletFoldMapping(outputIndex: 2, paddedInputCount: 6),
                   left: 3, right: 4)
    }

    func testBookletFold_N8() {
        // 8 pages → [1,8] [2,7] [3,6] [4,5]
        assertFold(BookletLayoutEngine.bookletFoldMapping(outputIndex: 0, paddedInputCount: 8),
                   left: 1, right: 8)
        assertFold(BookletLayoutEngine.bookletFoldMapping(outputIndex: 1, paddedInputCount: 8),
                   left: 2, right: 7)
        assertFold(BookletLayoutEngine.bookletFoldMapping(outputIndex: 2, paddedInputCount: 8),
                   left: 3, right: 6)
        assertFold(BookletLayoutEngine.bookletFoldMapping(outputIndex: 3, paddedInputCount: 8),
                   left: 4, right: 5)
    }

    /// The classic "booklet fold" test: a 100-page book should map to
    /// 50 output sheets and the last page of the book should appear on
    /// the right side of the first output sheet.
    func testBookletFold_100PageBook() {
        let sheets = BookletLayoutEngine.buildSheets(
            inputPageCount: 100,
            settings: BookletSettings()
        )
        XCTAssertEqual(sheets.count, 50)
        XCTAssertEqual(sheets.first?.leftPage, 1)
        XCTAssertEqual(sheets.first?.rightPage, 100)
        XCTAssertEqual(sheets.last?.leftPage, 50)
        XCTAssertEqual(sheets.last?.rightPage, 51)
    }

    func testBookletFold_PadsOddInput() {
        let sheets = BookletLayoutEngine.buildSheets(
            inputPageCount: 5,
            settings: BookletSettings()
        )
        // 5 → pad to 6 → 3 sheets, all positions used because booklet
        // fold always fills both sides of the spread.
        XCTAssertEqual(sheets.count, 3)
        XCTAssertEqual(sheets[0], OutputSheet(index: 0, leftPage: 1, rightPage: 6))
        XCTAssertEqual(sheets[1], OutputSheet(index: 1, leftPage: 2, rightPage: 5))
        XCTAssertEqual(sheets[2], OutputSheet(index: 2, leftPage: 3, rightPage: 4))
    }

    // MARK: - Simple pair mapping

    func testSimplePair_N5_Padded() {
        // 5 → pad to 6 → [1,2] [3,4] [5,6(blank rendered)]
        let sheets = BookletLayoutEngine.buildSheets(
            inputPageCount: 5,
            settings: BookletSettings(layout: .simplePair)
        )
        XCTAssertEqual(sheets.count, 3)
        XCTAssertEqual(sheets[0], OutputSheet(index: 0, leftPage: 1, rightPage: 2))
        XCTAssertEqual(sheets[1], OutputSheet(index: 1, leftPage: 3, rightPage: 4))
        XCTAssertEqual(sheets[2], OutputSheet(index: 2, leftPage: 5, rightPage: 6))
    }

    func testSimplePair_N4_NoPadding() {
        // 4 → [1,2] [3,4]
        let sheets = BookletLayoutEngine.buildSheets(
            inputPageCount: 4,
            settings: BookletSettings(layout: .simplePair, padBlankPage: false)
        )
        XCTAssertEqual(sheets.count, 2)
        XCTAssertEqual(sheets[0], OutputSheet(index: 0, leftPage: 1, rightPage: 2))
        XCTAssertEqual(sheets[1], OutputSheet(index: 1, leftPage: 3, rightPage: 4))
    }

    // MARK: - fitRect

    func testFitRectWideSourceFitsByHeight() {
        // Source cell 1:1 vs source 2:1 means
        // we fit by height: 100x50, centred.
        let r = BookletLayoutEngine.fitRect(aspectRatio: 2.0,
                                            into: CGRect(x: 0, y: 0, width: 100, height: 100))
        XCTAssertEqual(r.width,  200, accuracy: 0.001)
        XCTAssertEqual(r.height, 100, accuracy: 0.001)
    }

    func testFitRectTallSourceFitsByWidth() {
        // Source 1:2, cell 100x100 → fit by width: 50x100.
        let r = BookletLayoutEngine.fitRect(aspectRatio: 0.5,
                                            into: CGRect(x: 0, y: 0, width: 100, height: 100))
        XCTAssertEqual(r.width,  100, accuracy: 0.001)
        XCTAssertEqual(r.height, 200, accuracy: 0.001)
    }

    func testFitRectDegenerateInputsReturnTarget() {
        let target = CGRect(x: 0, y: 0, width: 100, height: 100)
        XCTAssertEqual(BookletLayoutEngine.fitRect(aspectRatio: 0,   into: target), target)
        XCTAssertEqual(BookletLayoutEngine.fitRect(aspectRatio: 1.0, into: .zero),   .zero)
    }
}
