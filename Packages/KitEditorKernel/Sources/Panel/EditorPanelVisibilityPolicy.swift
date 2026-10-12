import Foundation
import LanguageServerProtocol

public enum EditorPanelVisibilityPolicy {
    public static func updating(
        _ snapshot: EditorPanelSnapshot,
        openEditors: Bool? = nil,
        outline: Bool? = nil,
        problems: Bool? = nil,
        references: Bool? = nil,
        workspaceSearch: Bool? = nil,
        workspaceSymbols: Bool? = nil,
        callHierarchy: Bool? = nil
    ) -> EditorPanelSnapshot {
        EditorPanelSnapshot(
            isOpenEditorsPanelPresented: openEditors ?? snapshot.isOpenEditorsPanelPresented,
            isOutlinePanelPresented: outline ?? snapshot.isOutlinePanelPresented,
            isProblemsPanelPresented: problems ?? snapshot.isProblemsPanelPresented,
            isReferencePanelPresented: references ?? snapshot.isReferencePanelPresented,
            isWorkspaceSearchPresented: workspaceSearch ?? snapshot.isWorkspaceSearchPresented,
            isWorkspaceSymbolSearchPresented: workspaceSymbols ?? snapshot.isWorkspaceSymbolSearchPresented,
            isCallHierarchyPresented: callHierarchy ?? snapshot.isCallHierarchyPresented
        )
    }

    public static func presentingBottomPanel(
        _ panel: EditorBottomPanelKind?,
        in snapshot: EditorPanelSnapshot
    ) -> EditorPanelSnapshot {
        switch panel {
        case .problems:
            updating(snapshot, problems: true, references: false, workspaceSearch: false, workspaceSymbols: false, callHierarchy: false)
        case .references:
            updating(snapshot, problems: false, references: true, workspaceSearch: false, workspaceSymbols: false, callHierarchy: false)
        case .searchResults:
            updating(snapshot, problems: false, references: false, workspaceSearch: true, workspaceSymbols: false, callHierarchy: false)
        case .workspaceSymbols:
            updating(snapshot, problems: false, references: false, workspaceSearch: false, workspaceSymbols: true, callHierarchy: false)
        case .callHierarchy:
            updating(snapshot, problems: false, references: false, workspaceSearch: false, workspaceSymbols: false, callHierarchy: true)
        case nil:
            updating(snapshot, problems: false, references: false, workspaceSearch: false, workspaceSymbols: false, callHierarchy: false)
        }
    }

    public static func selectedDiagnostic(
        in diagnostics: [Diagnostic],
        line: Int,
        column: Int
    ) -> Diagnostic? {
        diagnostics.first { diagnostic in
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
    }
}
