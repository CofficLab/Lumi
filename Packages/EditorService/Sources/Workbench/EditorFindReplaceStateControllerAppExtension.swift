import CodeEditSourceEditor
import EditorKernel

extension EditorFindReplaceStateController {
    static func apply(
        _ state: EditorFindReplaceState,
        to editorState: inout SourceEditorState
    ) {
        editorState.findText = state.findText
        editorState.replaceText = state.replaceText
        editorState.findPanelVisible = state.isFindPanelVisible
    }
}
