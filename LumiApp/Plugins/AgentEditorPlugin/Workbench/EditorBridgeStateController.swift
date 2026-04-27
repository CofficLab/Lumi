import Foundation
import CodeEditSourceEditor

struct EditorBridgeState {
    let viewState: EditorViewState
    let findReplaceState: EditorFindReplaceState?
}

enum EditorBridgeStateController {
    static func state(
        for update: EditorCursorUpdate
    ) -> EditorBridgeState {
        switch update {
        case let .observedPositions(positions, fallbackLine, fallbackColumn),
             let .explicitPositions(positions, fallbackLine, fallbackColumn):
            return state(
                cursorPositions: positions,
                fallbackLine: fallbackLine,
                fallbackColumn: fallbackColumn
            )
        case let .primary(line, column, existingPositions, preserveCursorSelection):
            return state(
                line: line,
                column: column,
                existingPositions: existingPositions,
                preserveCursorSelection: preserveCursorSelection
            )
        }
    }

    static func state(
        viewState: EditorViewState,
        findReplaceState: EditorFindReplaceState? = nil
    ) -> EditorBridgeState {
        EditorBridgeState(
            viewState: viewState,
            findReplaceState: findReplaceState
        )
    }

    static func state(
        from restoreResult: EditorSessionRestoreResult
    ) -> EditorBridgeState {
        let cursorPositions = if restoreResult.cursorPositions.isEmpty {
            [
                CursorPosition(
                    start: .init(
                        line: restoreResult.cursorLine,
                        column: restoreResult.cursorColumn
                    ),
                    end: nil
                )
            ]
        } else {
            restoreResult.cursorPositions
        }

        return state(
            cursorPositions: cursorPositions,
            findReplaceState: restoreResult.findReplaceState,
            fallbackLine: restoreResult.cursorLine,
            fallbackColumn: restoreResult.cursorColumn
        )
    }

    static func state(
        from editorState: SourceEditorState,
        cursorLine: Int,
        cursorColumn: Int
    ) -> EditorBridgeState {
        state(
            cursorPositions: editorState.cursorPositions ?? [],
            findReplaceState: EditorFindReplaceStateController.state(
                findText: editorState.findText ?? "",
                replaceText: editorState.replaceText ?? "",
                isFindPanelVisible: editorState.findPanelVisible ?? false
            ),
            fallbackLine: max(cursorLine, 1),
            fallbackColumn: max(cursorColumn, 1)
        )
    }

    static func state(
        cursorPositions: [CursorPosition],
        findReplaceState: EditorFindReplaceState? = nil,
        fallbackLine: Int = EditorViewState.initial.primaryCursorLine,
        fallbackColumn: Int = EditorViewState.initial.primaryCursorColumn
    ) -> EditorBridgeState {
        EditorBridgeState(
            viewState: EditorViewStateController.state(
                from: cursorPositions,
                fallbackLine: fallbackLine,
                fallbackColumn: fallbackColumn
            ),
            findReplaceState: findReplaceState
        )
    }

    static func state(
        line: Int,
        column: Int,
        existingPositions: [CursorPosition],
        preserveCursorSelection: Bool
    ) -> EditorBridgeState {
        EditorBridgeState(
            viewState: EditorViewStateController.state(
                line: line,
                column: column,
                existingPositions: existingPositions,
                preserveCursorSelection: preserveCursorSelection
            ),
            findReplaceState: nil
        )
    }
}
