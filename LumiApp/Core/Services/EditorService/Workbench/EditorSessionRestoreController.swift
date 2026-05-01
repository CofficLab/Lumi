import Foundation
import CodeEditSourceEditor

struct EditorSessionRestoreResult {
    let cursorLine: Int
    let cursorColumn: Int
    let findReplaceState: EditorFindReplaceState
    let scrollState: EditorScrollState
    let cursorPositions: [CursorPosition]
}

@MainActor
enum EditorSessionRestoreController {
    static func restoreResult(
        from session: EditorSession,
        fallbackCursorPositions: [CursorPosition]
    ) -> EditorSessionRestoreResult {
        let cursorPositions = session.viewState.cursorPositions.isEmpty
            ? fallbackCursorPositions
            : session.viewState.cursorPositions

        let viewState = cursorPositions.isEmpty
            ? session.viewState
            : EditorViewStateController.state(
                from: cursorPositions,
                fallbackLine: session.viewState.primaryCursorLine,
                fallbackColumn: session.viewState.primaryCursorColumn
            )

        return EditorSessionRestoreResult(
            cursorLine: max(viewState.primaryCursorLine, 1),
            cursorColumn: max(viewState.primaryCursorColumn, 1),
            findReplaceState: session.findReplaceState,
            scrollState: session.scrollState,
            cursorPositions: cursorPositions
        )
    }
}
