import Foundation
import EditorService
import SwiftUI

/// 编辑器协调器集合 —— `SourceEditorView` 在各初始化步骤之间流转的快照。
///
/// `SourceEditorView` 用 `@State` 保存每个协调器实例，并通过
/// `SourceEditorViewBridge` 在 view 生命周期里初始化和更新它们。
public struct SourceEditorCoordinatorSet {
    public var textCoordinator: EditorCoordinator?
    public var cursorCoordinator: CursorCoordinator?
    public var scrollCoordinator: ScrollCoordinator?
    public var contextMenuCoordinator: ContextMenuCoordinator?
    public var semanticTokenProvider: (any SuperEditorSemanticTokenProvider)?
    public var semanticTokenHighlightProvider: (any HighlightProviding)?
    public var documentHighlightProvider: (any HighlightProviding)?
    public var hoverCoordinator: HoverEditorCoordinator?
}

/// 维护 `SourceEditorView` 与 `EditorService` 之间的协调器实例化逻辑。
@MainActor
public struct SourceEditorViewBridge {
    public func initializeCoordinators(
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
        if next.semanticTokenProvider == nil, let semanticTokenProvider = state.editorExtensions.semanticTokenProvider {
            next.semanticTokenProvider = semanticTokenProvider
            next.semanticTokenProvider?.setEnabled(state.isSyntaxHighlightingEnabledInViewport)
            next.semanticTokenHighlightProvider = semanticTokenProvider as? any HighlightProviding
        }
        if next.hoverCoordinator == nil {
            next.hoverCoordinator = HoverEditorCoordinator(state: state)
        }

        return next
    }

    public func wireDelegates(
        state: EditorState,
        jumpDelegate: EditorJumpToDefinitionDelegate,
        treeSitterClient: TreeSitterClient,
        textCoordinator: EditorCoordinator?,
        completionDelegate: LSPCompletionDelegate
    ) {
        jumpDelegate.textStorage = state.content
        jumpDelegate.treeSitterClient = treeSitterClient
        jumpDelegate.lspClient = state.lspClient
        jumpDelegate.lspClientProvider = { [weak state] in
            state?.lspClient
        }
        jumpDelegate.semanticCapabilityProvider = { [weak state] in
            state?.semanticCapability
        }
        jumpDelegate.currentFileURLProvider = { [weak state] in
            state?.currentFileURL
        }
        jumpDelegate.allowsLocalFallbackProvider = { [weak state] in
            !(state?.projectContextSnapshot?.isStructuredProject ?? false)
        }
        jumpDelegate.onOpenExternalDefinition = { [weak state] url, target in
            state?.performNavigation(.definition(url, target, highlightLine: false))
        }
        state.jumpDelegate = jumpDelegate
        textCoordinator?.jumpDelegate = jumpDelegate

        completionDelegate.configure(
            lspClient: state.lspClient,
            editorExtensionRegistry: state.editorExtensions,
            editorState: state
        )
    }

    public func binding(for state: EditorState) -> Binding<SourceEditorState> {
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

    public func lineTable(for content: NSTextStorage?) -> LineOffsetTable? {
        content.map { LineOffsetTable(content: $0.string) }
    }
}
