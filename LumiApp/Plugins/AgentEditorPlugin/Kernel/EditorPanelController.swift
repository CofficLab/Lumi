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

    func setSelectedProblemDiagnostic(_ diagnostic: Diagnostic?) {
        panelState.selectedProblemDiagnostic = diagnostic
    }

    func setReferenceResults(_ results: [ReferenceResult]) {
        panelState.referenceResults = results.map(Self.editorReferenceResult(from:))
    }

    func setMouseHover(content: String, symbolRect: CGRect) {
        panelState.setMouseHover(content: content, symbolRect: symbolRect)
    }

    func clearMouseHover() {
        panelState.clearMouseHover()
    }

    func clearData(
        clearDiagnostics: Bool = false,
        closeProblems: Bool? = nil,
        closeReferences: Bool? = nil,
        closeWorkspaceSymbols: Bool? = nil,
        closeCallHierarchy: Bool? = nil
    ) {
        panelState.clearMouseHover()
        setReferenceResults([])
        if clearDiagnostics {
            setProblemDiagnostics([])
        }
        setSelectedProblemDiagnostic(nil)
        apply(
            snapshot: updatedSnapshot(
                problems: closeProblems,
                references: closeReferences,
                workspaceSymbols: closeWorkspaceSymbols,
                callHierarchy: closeCallHierarchy
            )
        )
    }

    func updateVisibility(
        openEditors: Bool? = nil,
        problems: Bool? = nil,
        references: Bool? = nil,
        workspaceSymbols: Bool? = nil,
        callHierarchy: Bool? = nil
    ) {
        apply(
            snapshot: updatedSnapshot(
                openEditors: openEditors,
                problems: problems,
                references: references,
                workspaceSymbols: workspaceSymbols,
                callHierarchy: callHierarchy
            )
        )
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
        problems: Bool? = nil,
        references: Bool? = nil,
        workspaceSymbols: Bool? = nil,
        callHierarchy: Bool? = nil
    ) -> EditorPanelSnapshot {
        let snapshot = panelState.snapshot
        return EditorPanelSnapshot(
            isOpenEditorsPanelPresented: openEditors ?? snapshot.isOpenEditorsPanelPresented,
            isProblemsPanelPresented: problems ?? snapshot.isProblemsPanelPresented,
            isReferencePanelPresented: references ?? snapshot.isReferencePanelPresented,
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
