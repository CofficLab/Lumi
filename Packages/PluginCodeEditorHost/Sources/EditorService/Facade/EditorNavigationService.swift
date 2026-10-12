import Foundation

@MainActor
public final class EditorNavigationService {
    private let state: EditorState

    init(state: EditorState) {
        self.state = state
    }

    public var currentPeekPresentation: EditorPeekPresentation? { state.currentPeekPresentation }
    public var currentInlineRenameState: EditorInlineRenameState? { state.currentInlineRenameState }

    public func performNavigation(_ request: EditorNavigationRequest) {
        state.performNavigation(request)
    }

    public func performOpenItem(_ command: EditorOpenItemCommand) {
        state.performOpenItem(command)
    }
}
