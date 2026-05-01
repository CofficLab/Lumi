#if canImport(XCTest)
import XCTest
@testable import Lumi

@MainActor
final class EditorUndoControllerTests: XCTestCase {
    func testRecordChangeUpdatesAvailability() {
        let controller = EditorUndoController()
        let manager = EditorUndoManager()
        let before = EditorUndoState(text: "a", selections: [])
        let after = EditorUndoState(text: "ab", selections: [])

        let availability = controller.recordChange(
            in: manager,
            from: before,
            to: after,
            reason: "typing",
            isRestoringUndoState: false
        )

        XCTAssertTrue(availability.canUndo)
        XCTAssertFalse(availability.canRedo)
    }

    func testUndoAndRedoReturnUpdatedAvailability() {
        let controller = EditorUndoController()
        let manager = EditorUndoManager()
        manager.recordChange(
            from: EditorUndoState(text: "a", selections: []),
            to: EditorUndoState(text: "ab", selections: []),
            reason: "typing"
        )

        let undoResult = controller.performUndo(in: manager)
        XCTAssertEqual(undoResult?.state.text, "a")
        XCTAssertFalse(undoResult?.canUndo ?? true)
        XCTAssertTrue(undoResult?.canRedo ?? false)

        let redoResult = controller.performRedo(in: manager)
        XCTAssertEqual(redoResult?.state.text, "ab")
        XCTAssertTrue(redoResult?.canUndo ?? false)
        XCTAssertFalse(redoResult?.canRedo ?? true)
    }
}
#endif
