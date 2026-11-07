import Testing
@testable import BookletMakerCore

@Suite("PDFSplitPlan")
struct PDFSplitPlanTests {
    @Test("parses comma, whitespace, and full-width separators")
    func parsesCutPoints() {
        #expect(PDFSplitPlan.parseCutPoints("2， 5 8", pageCount: 10) == .success([2, 5, 8]))
        #expect(PDFSplitPlan.parseCutPoints("2, 2, 5", pageCount: 10) == .success([2, 5]))
    }

    @Test("rejects invalid and out-of-range cut points")
    func rejectsInvalidPoints() {
        #expect(PDFSplitPlan.parseCutPoints("two", pageCount: 10) == .failure(.invalidToken("two")))
        #expect(PDFSplitPlan.parseCutPoints("10", pageCount: 10) == .failure(.cutPointOutOfRange(10, pageCount: 10)))
    }

    @Test("builds stable one-based segments")
    func buildsSegments() {
        let segments = PDFSplitPlan.segments(pageCount: 10, cutPoints: [6, 2, 2, 99])

        #expect(segments.map(\.index) == [1, 2, 3])
        #expect(segments.map(\.startPage) == [1, 3, 7])
        #expect(segments.map(\.endPage) == [2, 6, 10])
        #expect(segments[1].fileName(baseName: "story") == "story-part-2.pdf")
    }
}
