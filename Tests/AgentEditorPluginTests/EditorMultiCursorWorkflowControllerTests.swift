#if canImport(XCTest)
import XCTest
@testable import Lumi

@MainActor
final class EditorMultiCursorWorkflowControllerTests: XCTestCase {
    func testClearedStateDropsSecondarySelectionsAndSession() {
        let workflow = EditorMultiCursorWorkflowController()
        let controller = EditorMultiCursorController()
        let state = MultiCursorState(
            primary: MultiCursorSelection(location: 1, length: 0),
            secondary: [
                MultiCursorSelection(location: 4, length: 2)
            ]
        )

        let result = workflow.clearedState(currentState: state, using: controller)

        XCTAssertEqual(result.state.all.count, 1)
        XCTAssertNil(result.session)
        XCTAssertEqual(result.logAction, "clearMultiCursors")
    }

    func testSetSelectionsResultClearsSessionForMultiSelection() {
        let workflow = EditorMultiCursorWorkflowController()
        let controller = EditorMultiCursorController()
        let selections = [
            MultiCursorSelection(location: 1, length: 0),
            MultiCursorSelection(location: 3, length: 0)
        ]

        let result = workflow.setSelectionsResult(
            selections,
            existingSession: nil,
            text: "hello" as NSString,
            using: controller
        )

        XCTAssertEqual(result?.state.all, selections)
        XCTAssertNil(result?.session)
        XCTAssertEqual(result?.logAction, "setSelections")
    }
}
#endif
