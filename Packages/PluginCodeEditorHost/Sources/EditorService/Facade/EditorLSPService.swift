import Foundation
import LanguageServerProtocol
import AppKit

@MainActor
public final class EditorLSPService {
    private let state: EditorState

    init(state: EditorState) {
        self.state = state
    }

    public var problemDiagnostics: [Diagnostic] { state.problemDiagnostics }
    public var semanticProblems: [EditorSemanticProblem] { state.semanticProblems }
    public var lspClient: any SuperEditorLSPClient { state.lspClient }
    var projectContextStatus: EditorProjectContextStatus { state.currentProjectContextStatus }
    var projectContextStatusDescription: String { state.currentProjectContextStatusDescription }
    var hoverText: String? { state.hoverText }
    var mouseHoverContent: String? { state.mouseHoverContent }
    public var documentSymbolProvider: any SuperEditorDocumentSymbolProvider { state.documentSymbolProvider }
    public var codeActionProvider: any SuperEditorCodeActionProvider { state.codeActionProvider }
    public var callHierarchyProvider: any SuperEditorCallHierarchyProvider { state.callHierarchyProvider }
    public var workspaceSymbolProvider: any SuperEditorWorkspaceSymbolProvider { state.workspaceSymbolProvider }
    public var signatureHelpProvider: any SuperEditorSignatureHelpProvider { state.signatureHelpProvider }
    public var inlayHintProvider: any SuperEditorInlayHintProvider { state.inlayHintProvider }
    public var documentHighlightProvider: any SuperEditorDocumentHighlightProvider { state.documentHighlightProvider }
    public var foldingRangeProvider: any SuperEditorFoldingRangeProvider { state.foldingRangeProvider }

    public func refreshDocumentOutline() {
        state.refreshDocumentOutline()
    }

    public func refreshFoldingRanges() {
        state.refreshFoldingRanges()
    }

    public func formatDocumentWithLSP() async {
        await state.formatDocumentWithLSP()
    }

    func setMouseHover(content: String, symbolRect: CGRect, hoverRange: LSPRange? = nil) {
        state.setMouseHover(content: content, symbolRect: symbolRect, hoverRange: hoverRange)
    }

    func clearMouseHover() {
        state.clearMouseHover()
    }
}
