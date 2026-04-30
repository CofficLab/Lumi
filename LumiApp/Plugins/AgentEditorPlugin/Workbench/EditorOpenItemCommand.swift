import Foundation
import CodeEditSourceEditor
import LanguageServerProtocol

enum EditorOpenItemCommand: Equatable {
    case problem(Diagnostic)
    case reference(ReferenceResult)
    case workspaceSymbol(WorkspaceSymbolItem)
    case callHierarchyItem(EditorCallHierarchyItem)
    case documentSymbol(EditorDocumentSymbolItem)
}

struct ResolvedEditorOpenItemCommand: Equatable {
    let navigationRequest: EditorNavigationRequest?
    let cursorPositions: [CursorPosition]
    let selectedProblemDiagnostic: Diagnostic?
    let closeWorkspaceSymbolSearch: Bool
}
