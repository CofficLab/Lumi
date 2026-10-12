import Foundation

@MainActor
public final class EditorPanelService {
    private let state: EditorState

    init(state: EditorState) {
        self.state = state
    }

    var isProblemsPanelPresented: Bool { state.isProblemsPanelPresented }
    var referenceResults: [ReferenceResult] { state.referenceResults }
    var isReferencePanelPresented: Bool { state.isReferencePanelPresented }
    public var isCodeActionPanelPresented: Bool { state.isCodeActionPanelPresented }
    public var isWorkspaceSymbolSearchPresented: Bool { state.isWorkspaceSymbolSearchPresented }
    public var isCallHierarchyPresented: Bool { state.isCallHierarchyPresented }
    public var panelState: EditorPanelState { state.panelState }
    public var panelController: EditorPanelController { state.panelController }

    func toggleOpenEditorsPanel() {
        state.performPanelCommand(.toggleOpenEditors)
    }

    func toggleOutlinePanel() {
        state.performPanelCommand(.toggleOutline)
    }

    func toggleProblemsPanel() {
        state.performPanelCommand(.toggleProblems)
    }

    public func performPanelCommand(_ command: EditorPanelCommand) {
        state.performPanelCommand(command)
    }

    public func presentBottomPanel(_ panel: EditorBottomPanelKind?) {
        state.presentBottomPanel(panel)
    }

    public func toggleCodeActionPanel() {
        state.toggleCodeActionPanel()
    }

    public func performWorkspaceSearch() async {
        await state.performWorkspaceSearch()
    }

    public func openWorkspaceSearchResultsInEditor() {
        state.openWorkspaceSearchResultsInEditor()
    }

    public func openWorkspaceSearchMatch(_ match: EditorWorkspaceSearchMatch) {
        state.openWorkspaceSearchMatch(match)
    }
}
