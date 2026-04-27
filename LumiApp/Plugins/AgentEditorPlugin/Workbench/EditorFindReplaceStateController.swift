import Foundation
import CodeEditSourceEditor

enum EditorFindReplaceStateController {
    static func state(
        findText: String,
        replaceText: String,
        isFindPanelVisible: Bool
    ) -> EditorFindReplaceState {
        EditorFindReplaceState(
            findText: findText,
            replaceText: replaceText,
            isFindPanelVisible: isFindPanelVisible
        )
    }

    static func apply(
        _ state: EditorFindReplaceState,
        to editorState: inout SourceEditorState
    ) {
        editorState.findText = state.findText
        editorState.replaceText = state.replaceText
        editorState.findPanelVisible = state.isFindPanelVisible
    }
}
