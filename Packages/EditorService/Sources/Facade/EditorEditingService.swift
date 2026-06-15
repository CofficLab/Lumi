import Foundation

@MainActor
public final class EditorEditingService {
    private let state: EditorState

    init(state: EditorState) {
        self.state = state
    }

    public var cursorLine: Int { state.cursorLine }
    public var cursorColumn: Int { state.cursorColumn }
    var totalLines: Int { state.totalLines }
    public var detectedLanguage: EditorLanguageContext? { state.detectedLanguage }
    var canUndo: Bool { state.canUndo }
    var canRedo: Bool { state.canRedo }
    var multiCursorState: MultiCursorState { state.multiCursorState }
    var findMatches: [EditorFindMatch] { state.findMatches }
    var currentFindMatch: EditorFindMatch? { state.currentFindMatch }
}
