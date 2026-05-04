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
        if let selected = panelState.selectedReferenceResult,
           editorResults.contains(selected) == false {
            panelState.selectedReferenceResult = nil
        }
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
        let visiblePaths = Set(results.map(\.path))
        panelState.workspaceSearchCollapsedFilePaths = panelState.workspaceSearchCollapsedFilePaths
            .intersection(visiblePaths)
        panelState.workspaceSearchResults = results
        panelState.workspaceSearchSummary = summary
        panelState.workspaceSearchErrorMessage = errorMessage
        let visibleMatchIDs = Set(results.flatMap { $0.matches.map(\.id) })
        if let selectedWorkspaceSearchMatchID = panelState.selectedWorkspaceSearchMatchID,
           !visibleMatchIDs.contains(selectedWorkspaceSearchMatchID) {
            panelState.selectedWorkspaceSearchMatchID = nil
        }
    }

    func toggleWorkspaceSearchFileCollapse(path: String) {
        if panelState.workspaceSearchCollapsedFilePaths.contains(path) {
            panelState.workspaceSearchCollapsedFilePaths.remove(path)
        } else {
            panelState.workspaceSearchCollapsedFilePaths.insert(path)
        }
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
            snapshot: updatedSnapshot(
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
            snapshot: updatedSnapshot(
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
        switch panel {
        case .problems:
            updateVisibility(problems: true, references: false, workspaceSearch: false, workspaceSymbols: false, callHierarchy: false)
        case .references:
            updateVisibility(problems: false, references: true, workspaceSearch: false, workspaceSymbols: false, callHierarchy: false)
        case .searchResults:
            updateVisibility(problems: false, references: false, workspaceSearch: true, workspaceSymbols: false, callHierarchy: false)
        case .workspaceSymbols:
            updateVisibility(problems: false, references: false, workspaceSearch: false, workspaceSymbols: true, callHierarchy: false)
        case .callHierarchy:
            updateVisibility(problems: false, references: false, workspaceSearch: false, workspaceSymbols: false, callHierarchy: true)
        case nil:
            updateVisibility(problems: false, references: false, workspaceSearch: false, workspaceSymbols: false, callHierarchy: false)
        }
    }

    func updateSelectedProblemDiagnostic(line: Int?, column: Int?) {
        guard let line, let column else {
            setSelectedProblemDiagnostic(nil)
            return
        }

        let matchingDiagnostic = panelState.problemDiagnostics.first { diagnostic in
            let startLine = Int(diagnostic.range.start.line) + 1
            let endLine = Int(diagnostic.range.end.line) + 1
            let startColumn = Int(diagnostic.range.start.character) + 1
            let endColumn = Int(diagnostic.range.end.character) + 1

            if line < startLine || line > endLine {
                return false
            }
            if startLine == endLine {
                let upperBound = max(endColumn, startColumn)
                return column >= startColumn && column <= upperBound
            }
            if line == startLine {
                return column >= startColumn
            }
            if line == endLine {
                return column <= max(endColumn, 1)
            }
            return true
        }

        setSelectedProblemDiagnostic(matchingDiagnostic)
    }

    private func updatedSnapshot(
        openEditors: Bool? = nil,
        outline: Bool? = nil,
        problems: Bool? = nil,
        references: Bool? = nil,
        workspaceSearch: Bool? = nil,
        workspaceSymbols: Bool? = nil,
        callHierarchy: Bool? = nil
    ) -> EditorPanelSnapshot {
        let snapshot = panelState.snapshot
        return EditorPanelSnapshot(
            isOpenEditorsPanelPresented: openEditors ?? snapshot.isOpenEditorsPanelPresented,
            isOutlinePanelPresented: outline ?? snapshot.isOutlinePanelPresented,
            isProblemsPanelPresented: problems ?? snapshot.isProblemsPanelPresented,
            isReferencePanelPresented: references ?? snapshot.isReferencePanelPresented,
            isWorkspaceSearchPresented: workspaceSearch ?? snapshot.isWorkspaceSearchPresented,
            isWorkspaceSymbolSearchPresented: workspaceSymbols ?? snapshot.isWorkspaceSymbolSearchPresented,
            isCallHierarchyPresented: callHierarchy ?? snapshot.isCallHierarchyPresented
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
