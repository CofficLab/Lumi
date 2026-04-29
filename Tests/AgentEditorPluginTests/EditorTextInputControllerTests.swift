#if canImport(XCTest)
import XCTest
@testable import Lumi

@MainActor
final class EditorTextInputControllerTests: XCTestCase {
    func testSingleCursorAutoClosingProducesBracketPlan() {
        let controller = EditorTextInputController()

        let plan = controller.textInputPlan(
            text: "(",
            replacementRange: NSRange(location: 5, length: 0),
            textViewSelections: [NSRange(location: 5, length: 0)],
            multiCursorSelectionCount: 1,
            currentText: "hello world",
            languageId: "swift"
        )

        XCTAssertEqual(plan?.replacementText, "()")
        XCTAssertEqual(plan?.selectedRanges, [NSRange(location: 6, length: 0)])
        XCTAssertEqual(plan?.reason, "bracket_auto_closing")
    }

    func testInsertNewlineBuildsSmartIndentPlan() {
        let controller = EditorTextInputController()

        let plan = controller.insertNewlinePlan(
            textViewSelections: [NSRange(location: 1, length: 0)],
            multiCursorSelectionCount: 1,
            currentText: "{\n}",
            tabSize: 4,
            useSpaces: true
        )

        XCTAssertEqual(plan?.replacementRange, NSRange(location: 1, length: 0))
        XCTAssertEqual(plan?.reason, "smart_indent_enter")
    }

    func testInsertBacktabReturnsNilForMultiCursor() {
        let controller = EditorTextInputController()

        let plan = controller.insertBacktabPlan(
            textViewSelections: [NSRange(location: 0, length: 4)],
            multiCursorSelectionCount: 2,
            currentText: "    test",
            tabSize: 4,
            useSpaces: true
        )

        XCTAssertNil(plan)
    }
}
#endif
