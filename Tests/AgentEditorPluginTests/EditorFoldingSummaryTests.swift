#if canImport(XCTest)
import XCTest
@testable import Lumi

@MainActor
final class EditorFoldingSummaryTests: XCTestCase {
    func testCurrentFoldingSummaryReflectsCursorScopedRange() {
        let state = EditorState()
        state.content = NSTextStorage(string: "import Foo\n\nfunc demo() {\n    print(1)\n}\n")
        state.cursorLine = 3
        state.showFoldingRibbon = true
        state.foldingRangeProvider.ranges = [
            FoldingRangeItem(
                startLine: 2,
                endLine: 4,
                startCharacter: nil,
                kind: .region,
                collapsedText: nil
            )
        ]

        let summary = state.currentFoldingSummary

        XCTAssertEqual(summary?.title, "Region Fold")
        XCTAssertEqual(summary?.hiddenLineCount, 2)
        XCTAssertEqual(summary?.subtitle, "func demo() {")
    }

    func testCurrentFoldingSummaryRespectsFoldingVisibilityGate() {
        let state = EditorState()
        state.content = NSTextStorage(string: "func demo() {\n    print(1)\n}\n")
        state.cursorLine = 1
        state.showFoldingRibbon = false
        state.foldingRangeProvider.ranges = [
            FoldingRangeItem(
                startLine: 0,
                endLine: 2,
                startCharacter: nil,
                kind: .region,
                collapsedText: nil
            )
        ]

        XCTAssertNil(state.currentFoldingSummary)
    }
}
#endif
