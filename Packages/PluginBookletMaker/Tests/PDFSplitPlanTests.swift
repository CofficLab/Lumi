import XCTest
@testable import BookletMakerPlugin

final class PDFSplitPlanTests: XCTestCase {
    func testParsesCommaChineseCommaAndWhitespace() throws {
        let result = PDFSplitPlan.parseCutPoints("20, 50，80  90", pageCount: 100)
        XCTAssertEqual(try result.get(), [20, 50, 80, 90])
    }

    func testRejectsLastPageAndInvalidTokens() {
        XCTAssertThrowsError(try PDFSplitPlan.parseCutPoints("100", pageCount: 100).get())
        XCTAssertThrowsError(try PDFSplitPlan.parseCutPoints("20, abc", pageCount: 100).get())
    }

    func testBuildsExpectedRanges() {
        let segments = PDFSplitPlan.segments(
            pageCount: 100,
            cutPoints: [20, 50, 80]
        )

        XCTAssertEqual(segments, [
            PDFSplitSegment(index: 1, startPage: 1, endPage: 20),
            PDFSplitSegment(index: 2, startPage: 21, endPage: 50),
            PDFSplitSegment(index: 3, startPage: 51, endPage: 80),
            PDFSplitSegment(index: 4, startPage: 81, endPage: 100),
        ])
    }
}
