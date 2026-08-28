import CoreGraphics
import XCTest
@testable import BookletMakerPlugin

// MARK: - Booklet Layout Engine Tests

final class BookletLayoutEngineTests: XCTestCase {

    // MARK: - Padding

    func testBookletPaddingRoundsUpToMultipleOfFour() {
        XCTAssertEqual(BookletLayoutEngine.paddedInputCount(1, layout: .bookletFold, pad: true), 4)
        XCTAssertEqual(BookletLayoutEngine.paddedInputCount(4, layout: .bookletFold, pad: true), 4)
        XCTAssertEqual(BookletLayoutEngine.paddedInputCount(5, layout: .bookletFold, pad: true), 8)
        XCTAssertEqual(BookletLayoutEngine.paddedInputCount(6, layout: .bookletFold, pad: true), 8)
        XCTAssertEqual(BookletLayoutEngine.paddedInputCount(8, layout: .bookletFold, pad: true), 8)
    }

    func testBookletPaddingCannotBeDisabled() {
        XCTAssertEqual(BookletLayoutEngine.paddedInputCount(5, layout: .bookletFold, pad: false), 8)
    }

    func testSimplePairRetainsOptionalEvenPadding() {
        XCTAssertEqual(BookletLayoutEngine.paddedInputCount(5, layout: .simplePair, pad: true), 6)
        XCTAssertEqual(BookletLayoutEngine.paddedInputCount(5, layout: .simplePair, pad: false), 5)
    }

    // MARK: - Counts

    func testOutputSideAndPhysicalSheetCounts() {
        XCTAssertEqual(BookletLayoutEngine.outputSideCount(forPaddedInputCount: 4), 2)
        XCTAssertEqual(BookletLayoutEngine.physicalSheetCount(forPaddedInputCount: 4), 1)
        XCTAssertEqual(BookletLayoutEngine.outputSideCount(forPaddedInputCount: 8), 4)
        XCTAssertEqual(BookletLayoutEngine.physicalSheetCount(forPaddedInputCount: 8), 2)
        XCTAssertEqual(BookletLayoutEngine.outputSideCount(forPaddedInputCount: 100), 50)
        XCTAssertEqual(BookletLayoutEngine.physicalSheetCount(forPaddedInputCount: 100), 25)
    }

    func testCountsForZeroAreZero() {
        XCTAssertEqual(BookletLayoutEngine.outputSideCount(forPaddedInputCount: 0), 0)
        XCTAssertEqual(BookletLayoutEngine.physicalSheetCount(forPaddedInputCount: 0), 0)
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
        // One physical sheet: front [4,1], back [2,3].
        assertFold(BookletLayoutEngine.bookletFoldMapping(outputIndex: 0, paddedInputCount: 4),
                   left: 4, right: 1)
        assertFold(BookletLayoutEngine.bookletFoldMapping(outputIndex: 1, paddedInputCount: 4),
                   left: 2, right: 3)
    }

    func testBookletFold_N8() {
        // Two physical sheets, each represented by adjacent front/back sides.
        assertFold(BookletLayoutEngine.bookletFoldMapping(outputIndex: 0, paddedInputCount: 8),
                   left: 8, right: 1)
        assertFold(BookletLayoutEngine.bookletFoldMapping(outputIndex: 1, paddedInputCount: 8),
                   left: 2, right: 7)
        assertFold(BookletLayoutEngine.bookletFoldMapping(outputIndex: 2, paddedInputCount: 8),
                   left: 6, right: 3)
        assertFold(BookletLayoutEngine.bookletFoldMapping(outputIndex: 3, paddedInputCount: 8),
                   left: 4, right: 5)
    }

    /// The classic "booklet fold" test: a 100-page book should map to
    /// 50 output sheets and the last page of the book should appear on
    /// the right side of the first output sheet.
    func testBookletFold_100PageBook() {
        let outputSides = BookletLayoutEngine.buildOutputSides(
            inputPageCount: 100,
            settings: BookletSettings()
        )
        let physicalSheets = BookletLayoutEngine.buildPhysicalSheets(
            inputPageCount: 100,
            settings: BookletSettings()
        )
        XCTAssertEqual(outputSides.count, 50)
        XCTAssertEqual(physicalSheets.count, 25)
        XCTAssertEqual(outputSides.first?.leftPage, 100)
        XCTAssertEqual(outputSides.first?.rightPage, 1)
        XCTAssertEqual(outputSides.last?.leftPage, 50)
        XCTAssertEqual(outputSides.last?.rightPage, 51)
    }

    func testBookletFoldPadsFivePagesToTwoPhysicalSheets() {
        let sides = BookletLayoutEngine.buildOutputSides(
            inputPageCount: 5,
            settings: BookletSettings()
        )
        XCTAssertEqual(sides.count, 4)
        assertOutputSide(sides[0], index: 0, physicalSheet: 0, side: .front, left: 0, right: 1)
        assertOutputSide(sides[1], index: 1, physicalSheet: 0, side: .back, left: 2, right: 0)
        assertOutputSide(sides[2], index: 2, physicalSheet: 1, side: .front, left: 0, right: 3)
        assertOutputSide(sides[3], index: 3, physicalSheet: 1, side: .back, left: 4, right: 5)
    }

    // MARK: - Simple pair mapping

    func testSimplePair_N5_Padded() {
        // 5 → pad to 6 → [1,2] [3,4] [5,6(blank rendered)]
        let sheets = BookletLayoutEngine.buildOutputSides(
            inputPageCount: 5,
            settings: BookletSettings(layout: .simplePair)
        )
        XCTAssertEqual(sheets.count, 3)
        assertOutputSide(sheets[0], index: 0, physicalSheet: 0, side: .front, left: 1, right: 2)
        assertOutputSide(sheets[1], index: 1, physicalSheet: 1, side: .front, left: 3, right: 4)
        assertOutputSide(sheets[2], index: 2, physicalSheet: 2, side: .front, left: 5, right: 0)
    }

    func testSimplePair_N4_NoPadding() {
        // 4 → [1,2] [3,4]
        let sheets = BookletLayoutEngine.buildOutputSides(
            inputPageCount: 4,
            settings: BookletSettings(layout: .simplePair, padBlankPage: false)
        )
        XCTAssertEqual(sheets.count, 2)
        assertOutputSide(sheets[0], index: 0, physicalSheet: 0, side: .front, left: 1, right: 2)
        assertOutputSide(sheets[1], index: 1, physicalSheet: 1, side: .front, left: 3, right: 4)
    }

    private func assertOutputSide(
        _ outputSide: OutputSheet,
        index: Int,
        physicalSheet: Int,
        side: OutputSheet.Side,
        left: Int,
        right: Int,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertEqual(outputSide.index, index, file: file, line: line)
        XCTAssertEqual(outputSide.physicalSheetIndex, physicalSheet, file: file, line: line)
        XCTAssertEqual(outputSide.side, side, file: file, line: line)
        XCTAssertEqual(outputSide.leftPage, left, file: file, line: line)
        XCTAssertEqual(outputSide.rightPage, right, file: file, line: line)
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
