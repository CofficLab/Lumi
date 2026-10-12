import Foundation

public enum EditorFindReplaceStateController {
    public static func state(
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
}
