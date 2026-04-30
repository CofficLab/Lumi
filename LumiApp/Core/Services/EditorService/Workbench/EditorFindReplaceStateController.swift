import Foundation
import CodeEditSourceEditor

enum EditorFindReplaceStateController {
    static func state(
        findText: String,
        replaceText: String,
        isFindPanelVisible: Bool,
        preserving existingState: EditorFindReplaceState? = nil
    ) -> EditorFindReplaceState {
        EditorFindReplaceState(
            findText: findText,
            replaceText: replaceText,
            isFindPanelVisible: isFindPanelVisible,
            options: existingState?.options ?? EditorFindReplaceOptions(),
            resultCount: existingState?.resultCount ?? 0,
            selectedMatchIndex: existingState?.selectedMatchIndex,
            selectedMatchRange: existingState?.selectedMatchRange
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
