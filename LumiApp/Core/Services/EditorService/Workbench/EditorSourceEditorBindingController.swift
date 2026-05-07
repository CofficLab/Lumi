import Foundation
import CodeEditSourceEditor

struct EditorSourceEditorBindingUpdate {
    let viewState: EditorViewState?
    let findReplaceState: EditorFindReplaceState
}

enum EditorSourceEditorBindingController {
    static func update(
        from sourceEditorState: SourceEditorState,
        multiCursorSelectionCount: Int,
        currentFindReplaceState: EditorFindReplaceState
    ) -> EditorSourceEditorBindingUpdate {
        let viewState: EditorViewState? = if multiCursorSelectionCount > 1 {
            nil
        } else {
            EditorViewStateController.state(from: sourceEditorState.cursorPositions ?? [])
        }

        return EditorSourceEditorBindingUpdate(
            viewState: viewState,
            findReplaceState: EditorFindReplaceStateController.state(
                findText: sourceEditorState.findText ?? "",
                replaceText: sourceEditorState.replaceText ?? "",
                isFindPanelVisible: sourceEditorState.findPanelVisible ?? false,
                preserving: currentFindReplaceState
            )
        )
    }
}
