import Foundation
import CodeEditSourceEditor

@MainActor
final class EditorCursorController {
    func observationUpdate(
        positions: [CursorPosition],
        fallbackLine: Int,
        fallbackColumn: Int
    ) -> EditorInteractionUpdate {
        .cursor(
            .observedPositions(
                positions,
                fallbackLine: fallbackLine,
                fallbackColumn: fallbackColumn
            )
        )
    }

    func explicitPositionsUpdate(_ positions: [CursorPosition]) -> EditorInteractionUpdate {
        .cursor(
            .explicitPositions(
                positions,
                fallbackLine: EditorViewState.initial.primaryCursorLine,
                fallbackColumn: EditorViewState.initial.primaryCursorColumn
            )
        )
    }

    func primaryPositionUpdate(
        line: Int,
        column: Int,
        existingPositions: [CursorPosition],
        preserveCursorSelection: Bool
    ) -> EditorInteractionUpdate {
        .cursor(
            .primary(
                line: line,
                column: column,
                existingPositions: existingPositions,
                preserveCursorSelection: preserveCursorSelection
            )
        )
    }

    func resetPrimaryCursor(in editorState: inout SourceEditorState) -> EditorInteractionUpdate {
        editorState.cursorPositions = []
        return primaryPositionUpdate(
            line: EditorViewState.initial.primaryCursorLine,
            column: EditorViewState.initial.primaryCursorColumn,
            existingPositions: [],
            preserveCursorSelection: false
        )
    }
}
