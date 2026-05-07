import Foundation
import LanguageServerProtocol

@MainActor
final class EditorPanelController {
    private let panelState: EditorPanelState

    init(panelState: EditorPanelState) {
        self.panelState = panelState
    }

    var snapshot: EditorPanelSnapshot {
        panelState.snapshot
    }

    var sessionState: EditorPanelSessionState {
        panelState.sessionState
    }

    func apply(command: EditorPanelCommand) {
        panelState.apply(command)
    }

    func apply(snapshot: EditorPanelSnapshot) {
        panelState.apply(snapshot)
    }

    func restore(from sessionState: EditorPanelSessionState) {
        panelState.restore(from: sessionState)
    }

    func setProblemDiagnostics(_ diagnostics: [Diagnostic]) {
        panelState.problemDiagnostics = diagnostics
    }

    func setSemanticProblems(_ problems: [EditorSemanticProblem]) {
        panelState.semanticProblems = problems
    }

    func setSelectedProblemDiagnostic(_ diagnostic: Diagnostic?) {
        panelState.selectedProblemDiagnostic = diagnostic
    }

    func setReferenceResults(_ results: [ReferenceResult]) {
        let editorResults = results.map(Self.editorReferenceResult(from:))
        panelState.referenceResults = editorResults
        panelState.selectedReferenceResult = EditorPanelDataPolicy.normalizedReferenceSelection(
            selected: panelState.selectedReferenceResult,
            availableResults: editorResults
        )
    }

    func setSelectedReferenceResult(_ result: ReferenceResult?) {
        panelState.selectedReferenceResult = result.map(Self.editorReferenceResult(from:))
    }

    func setWorkspaceSearchQuery(_ query: String) {
        panelState.workspaceSearchQuery = query
    }

    func setWorkspaceSearchLoading(_ isLoading: Bool) {
        panelState.isWorkspaceSearchLoading = isLoading
    }

    func setWorkspaceSearchResults(
        _ results: [EditorWorkspaceSearchFileResult],
        summary: EditorWorkspaceSearchSummary?,
        errorMessage: String?
    ) {
        let normalizedState = EditorPanelDataPolicy.normalizedWorkspaceSearchState(
            collapsedFilePaths: panelState.workspaceSearchCollapsedFilePaths,
            selectedMatchID: panelState.selectedWorkspaceSearchMatchID,
            results: results
        )
        panelState.workspaceSearchCollapsedFilePaths = normalizedState.collapsedFilePaths
        panelState.workspaceSearchResults = results
        panelState.workspaceSearchSummary = summary
        panelState.workspaceSearchErrorMessage = errorMessage
        panelState.selectedWorkspaceSearchMatchID = normalizedState.selectedMatchID
    }

    func toggleWorkspaceSearchFileCollapse(path: String) {
        panelState.workspaceSearchCollapsedFilePaths = EditorPanelDataPolicy.toggledCollapsedFilePath(
            path,
            in: panelState.workspaceSearchCollapsedFilePaths
        )
    }

    func setSelectedWorkspaceSearchMatchID(_ id: String?) {
        panelState.selectedWorkspaceSearchMatchID = id
    }

    func setMouseHover(content: String, symbolRect: CGRect, hoverRange: LSPRange? = nil) {
        panelState.setMouseHover(content: content, symbolRect: symbolRect, hoverRange: hoverRange)
    }

    func clearMouseHover() {
        panelState.clearMouseHover()
    }

    func clearData(
        clearDiagnostics: Bool = false,
        closeProblems: Bool? = nil,
        closeReferences: Bool? = nil,
        closeWorkspaceSearch: Bool? = nil,
        closeWorkspaceSymbols: Bool? = nil,
        closeCallHierarchy: Bool? = nil
    ) {
        panelState.clearMouseHover()
        setReferenceResults([])
        if closeWorkspaceSearch != nil {
            setWorkspaceSearchLoading(false)
        }
        if clearDiagnostics {
            setProblemDiagnostics([])
            setSemanticProblems([])
        }
        setSelectedProblemDiagnostic(nil)
        setSelectedReferenceResult(nil)
        apply(
            snapshot: EditorPanelVisibilityPolicy.updating(
                snapshot,
                problems: closeProblems,
                references: closeReferences,
                workspaceSearch: closeWorkspaceSearch,
                workspaceSymbols: closeWorkspaceSymbols,
                callHierarchy: closeCallHierarchy
            )
        )
    }

    func updateVisibility(
        openEditors: Bool? = nil,
        outline: Bool? = nil,
        problems: Bool? = nil,
        references: Bool? = nil,
        workspaceSearch: Bool? = nil,
        workspaceSymbols: Bool? = nil,
        callHierarchy: Bool? = nil
    ) {
        apply(
            snapshot: EditorPanelVisibilityPolicy.updating(
                snapshot,
                openEditors: openEditors,
                outline: outline,
                problems: problems,
                references: references,
                workspaceSearch: workspaceSearch,
                workspaceSymbols: workspaceSymbols,
                callHierarchy: callHierarchy
            )
        )
    }

    func presentBottomPanel(_ panel: EditorBottomPanelKind?) {
        apply(snapshot: EditorPanelVisibilityPolicy.presentingBottomPanel(panel, in: snapshot))
    }

    func updateSelectedProblemDiagnostic(line: Int?, column: Int?) {
        guard let line, let column else {
            setSelectedProblemDiagnostic(nil)
            return
        }

        setSelectedProblemDiagnostic(
            EditorPanelVisibilityPolicy.selectedDiagnostic(
                in: panelState.problemDiagnostics,
                line: line,
                column: column
            )
        )
    }

    private static func editorReferenceResult(from result: ReferenceResult) -> EditorReferenceResult {
        EditorReferenceResult(
            url: result.url,
            line: result.line,
            column: result.column,
            path: result.path,
            preview: result.preview
        )
    }
}
