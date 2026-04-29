#if canImport(XCTest)
import XCTest
import CodeEditSourceEditor
@testable import Lumi

@MainActor
final class EditorCursorControllerTests: XCTestCase {
    func testObservationUpdateUsesProvidedFallbacks() {
        let controller = EditorCursorController()
        let positions = [CursorPosition(start: .init(line: 4, column: 9), end: nil)]

        let update = controller.observationUpdate(
            positions: positions,
            fallbackLine: 10,
            fallbackColumn: 20
        )

        guard case let .cursor(.observedPositions(applied, fallbackLine: fallbackLine, fallbackColumn: fallbackColumn)) = update else {
            return XCTFail("Expected observed cursor update")
        }

        XCTAssertEqual(applied, positions)
        XCTAssertEqual(fallbackLine, 10)
        XCTAssertEqual(fallbackColumn, 20)
    }

    func testResetPrimaryCursorClearsExistingPositions() {
        let controller = EditorCursorController()
        var editorState = SourceEditorState()
        editorState.cursorPositions = [CursorPosition(start: .init(line: 8, column: 3), end: nil)]

        let update = controller.resetPrimaryCursor(in: &editorState)

        XCTAssertEqual(editorState.cursorPositions, [])
        guard case let .cursor(.primary(
            line: line,
            column: column,
            existingPositions: existingPositions,
            preserveCursorSelection: preserveCursorSelection
        )) = update else {
            return XCTFail("Expected primary cursor update")
        }

        XCTAssertEqual(line, EditorViewState.initial.primaryCursorLine)
        XCTAssertEqual(column, EditorViewState.initial.primaryCursorColumn)
        XCTAssertEqual(existingPositions, [])
        XCTAssertFalse(preserveCursorSelection)
    }
}
#endif
