#if canImport(XCTest)
import XCTest
@testable import Lumi

final class EditorUndoManagerTests: XCTestCase {

    func testRecordChangeEnablesUndoAndClearsRedo() {
        let manager = EditorUndoManager()
        let before = EditorUndoState(
            text: "a",
            selections: [EditorSelection(range: EditorRange(location: 1, length: 0))]
        )
        let after = EditorUndoState(
            text: "ab",
            selections: [EditorSelection(range: EditorRange(location: 2, length: 0))]
        )

        manager.recordChange(from: before, to: after, reason: "typing")

        XCTAssertTrue(manager.canUndo)
        XCTAssertFalse(manager.canRedo)
        XCTAssertEqual(manager.undoStack.count, 1)
        XCTAssertEqual(manager.redoStack.count, 0)
    }

    func testUndoReturnsBeforeStateAndEnablesRedo() {
        let manager = EditorUndoManager()
        let before = EditorUndoState(
            text: "a",
            selections: [EditorSelection(range: EditorRange(location: 1, length: 0))]
        )
        let after = EditorUndoState(
            text: "ab",
            selections: [EditorSelection(range: EditorRange(location: 2, length: 0))]
        )
        manager.recordChange(from: before, to: after, reason: "typing")

        let undone = manager.undo()

        XCTAssertEqual(undone, before)
        XCTAssertFalse(manager.canUndo)
        XCTAssertTrue(manager.canRedo)
    }

    func testRedoReturnsAfterState() {
        let manager = EditorUndoManager()
        let before = EditorUndoState(
            text: "a",
            selections: [EditorSelection(range: EditorRange(location: 1, length: 0))]
        )
        let after = EditorUndoState(
            text: "ab",
            selections: [EditorSelection(range: EditorRange(location: 2, length: 0))]
        )
        manager.recordChange(from: before, to: after, reason: "typing")
        _ = manager.undo()

        let redone = manager.redo()

        XCTAssertEqual(redone, after)
        XCTAssertTrue(manager.canUndo)
        XCTAssertFalse(manager.canRedo)
    }

    func testResetClearsHistory() {
        let manager = EditorUndoManager()
        manager.recordChange(
            from: EditorUndoState(text: "a", selections: [EditorSelection(range: EditorRange(location: 1, length: 0))]),
            to: EditorUndoState(text: "ab", selections: [EditorSelection(range: EditorRange(location: 2, length: 0))]),
            reason: "typing"
        )

        manager.reset()

        XCTAssertFalse(manager.canUndo)
        XCTAssertFalse(manager.canRedo)
        XCTAssertTrue(manager.undoStack.isEmpty)
        XCTAssertTrue(manager.redoStack.isEmpty)
    }
}
#endif
