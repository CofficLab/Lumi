import Foundation
import SwiftUI
import CodeEditSourceEditor
import CodeEditTextView

struct SourceEditorCoordinatorSet {
    var textCoordinator: EditorCoordinator?
    var cursorCoordinator: CursorCoordinator?
    var scrollCoordinator: ScrollCoordinator?
    var contextMenuCoordinator: ContextMenuCoordinator?
    var semanticTokenProvider: SemanticTokenHighlightProvider?
    var documentHighlightProvider: DocumentHighlightHighlighter?
    var hoverCoordinator: HoverEditorCoordinator?
}

@MainActor
struct SourceEditorViewBridge {
    func initializeCoordinators(
        state: EditorState,
        current: SourceEditorCoordinatorSet
    ) -> SourceEditorCoordinatorSet {
        var next = current

        if next.textCoordinator == nil {
            next.textCoordinator = EditorCoordinator(state: state)
        }
        if next.cursorCoordinator == nil {
            next.cursorCoordinator = CursorCoordinator(state: state)
        }
        if next.scrollCoordinator == nil {
            next.scrollCoordinator = ScrollCoordinator(state: state)
        }
        if next.contextMenuCoordinator == nil {
            next.contextMenuCoordinator = ContextMenuCoordinator(state: state)
        }
        if next.semanticTokenProvider == nil {
            next.semanticTokenProvider = SemanticTokenHighlightProvider(
                lspService: state.lspServiceInstance,
                uriProvider: { [weak state] in
                    state?.currentFileURL?.absoluteString
                }
            )
            next.semanticTokenProvider?.setEnabled(state.isSyntaxHighlightingEnabledInViewport)
        }
        if next.documentHighlightProvider == nil {
            next.documentHighlightProvider = DocumentHighlightHighlighter(
                provider: state.documentHighlightProvider
            )
        }
        if next.hoverCoordinator == nil {
            next.hoverCoordinator = HoverEditorCoordinator(state: state)
        }

        return next
    }

    func wireDelegates(
        state: EditorState,
        jumpDelegate: EditorJumpToDefinitionDelegate,
        treeSitterClient: TreeSitterClient,
        textCoordinator: EditorCoordinator?,
        completionDelegate: inout LSPCompletionDelegate
    ) {
        jumpDelegate.textStorage = state.content
        jumpDelegate.treeSitterClient = treeSitterClient
        jumpDelegate.lspClient = state.lspClient
        jumpDelegate.currentFileURLProvider = { [weak state] in
            state?.currentFileURL
        }
        jumpDelegate.onOpenExternalDefinition = { [weak state] url, target in
            state?.performNavigation(.definition(url, target, highlightLine: false))
        }
        state.jumpDelegate = jumpDelegate
        textCoordinator?.jumpDelegate = jumpDelegate

        completionDelegate.lspClient = state.lspClient
        completionDelegate.editorExtensionRegistry = state.editorExtensions
        completionDelegate.editorState = state
    }

    func binding(for state: EditorState) -> Binding<SourceEditorState> {
        Binding<SourceEditorState>(
            get: {
                var result = state.editorState
                result.scrollPosition = nil
                return result
            },
            set: { newState in
                let update = EditorSourceEditorBindingController.update(
                    from: newState,
                    multiCursorSelectionCount: state.multiCursorState.all.count,
                    currentFindReplaceState: state.activeSession.findReplaceState
                )

                DispatchQueue.main.async {
                    state.applySourceEditorBindingUpdate(update)
                }
            }
        )
    }

    func lineTable(for content: NSTextStorage?) -> LineOffsetTable? {
        content.map { LineOffsetTable(content: $0.string) }
    }
}
