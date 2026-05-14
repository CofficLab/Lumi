import Foundation
import LanguageServerProtocol

public struct EditorWorkspaceSymbolTarget: Equatable {
    public let uri: String
    public let line: Int
    public let character: Int

    public init(uri: String, line: Int, character: Int) {
        self.uri = uri
        self.line = line
        self.character = character
    }
}

public enum EditorOpenItemCommand: Equatable {
    case problem(Diagnostic)
    case reference(ReferenceResult)
    case workspaceSymbol(EditorWorkspaceSymbolTarget)
    case callHierarchyItem(URL, EditorCursorPosition)
    case documentSymbol(EditorDocumentSymbolItem)
}

public struct ResolvedEditorOpenItemCommand: Equatable {
    public let navigationRequest: EditorNavigationRequest?
    public let cursorPositions: [EditorCursorPosition]
    public let selectedProblemDiagnostic: Diagnostic?
    public let selectedReferenceResult: ReferenceResult?
    public let presentBottomPanel: EditorBottomPanelKind?
    public let closeWorkspaceSymbolSearch: Bool

    public init(
        navigationRequest: EditorNavigationRequest?,
        cursorPositions: [EditorCursorPosition],
        selectedProblemDiagnostic: Diagnostic?,
        selectedReferenceResult: ReferenceResult?,
        presentBottomPanel: EditorBottomPanelKind?,
        closeWorkspaceSymbolSearch: Bool
    ) {
        self.navigationRequest = navigationRequest
        self.cursorPositions = cursorPositions
        self.selectedProblemDiagnostic = selectedProblemDiagnostic
        self.selectedReferenceResult = selectedReferenceResult
        self.presentBottomPanel = presentBottomPanel
        self.closeWorkspaceSymbolSearch = closeWorkspaceSymbolSearch
    }
}
