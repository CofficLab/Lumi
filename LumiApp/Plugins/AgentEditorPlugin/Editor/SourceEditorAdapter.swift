import Foundation
import SwiftUI
import AppKit
import CodeEditSourceEditor
import CodeEditTextView
import CodeEditLanguages

@MainActor
struct SourceEditorAdapter {
    func resolvedLanguage(for state: EditorState) -> CodeLanguage {
        state.detectedLanguage
            ?? CodeLanguage.allLanguages.first { $0.tsName == "swift" }
            ?? CodeLanguage.allLanguages[0]
    }

    func activeHighlightProviders(
        for state: EditorState,
        treeSitterClient: TreeSitterClient,
        semanticTokenProvider: SemanticTokenHighlightProvider?,
        documentHighlightProvider: DocumentHighlightHighlighter?
    ) -> [any HighlightProviding] {
        var providers: [any HighlightProviding] = []
        let languageID = state.detectedLanguage?.tsName ?? "swift"

        if state.shouldUseTreeSitterHighlightProvider {
            providers.append(treeSitterClient)
        }
        if state.shouldUseSemanticTokenHighlightProvider, let semanticTokenProvider {
            providers.insert(semanticTokenProvider, at: 0)
        }
        if state.shouldUseDocumentHighlightProvider, let documentHighlightProvider {
            providers.append(documentHighlightProvider)
        }
        if state.shouldUsePluginHighlightProviders {
            providers.append(contentsOf: state.editorExtensions.highlightProviders(for: languageID))
        }
        return providers
    }

    func activeCoordinators(
        textCoordinator: EditorCoordinator?,
        cursorCoordinator: CursorCoordinator?,
        scrollCoordinator: ScrollCoordinator?,
        contextMenuCoordinator: ContextMenuCoordinator?,
        hoverCoordinator: HoverEditorCoordinator?
    ) -> [TextViewCoordinator] {
        var result: [TextViewCoordinator] = []
        if let textCoordinator { result.append(textCoordinator) }
        if let cursorCoordinator { result.append(cursorCoordinator) }
        if let scrollCoordinator { result.append(scrollCoordinator) }
        if let contextMenuCoordinator { result.append(contextMenuCoordinator) }
        if let hoverCoordinator { result.append(hoverCoordinator) }
        return result
    }

    @MainActor
    func configuration(
        for state: EditorState,
        completionDelegate: LSPCompletionDelegate
    ) -> SourceEditorConfiguration {
        let fontSize = CGFloat(state.fontSize)

        return SourceEditorConfiguration(
            appearance: .init(
                theme: state.currentTheme ?? EditorThemeAdapter.fallbackTheme(),
                useThemeBackground: true,
                font: NSFont.monospacedSystemFont(ofSize: fontSize, weight: .regular),
                lineHeightMultiple: 1.2,
                letterSpacing: 1.0,
                wrapLines: state.wrapLines,
                useSystemCursor: true,
                tabWidth: state.tabWidth,
                bracketPairEmphasis: .flash
            ),
            behavior: .init(
                isEditable: state.isEditable,
                indentOption: state.useSpaces
                    ? .spaces(count: state.tabWidth)
                    : .tab
            ),
            layout: .init(
                editorOverscroll: 0.1,
                contentInsets: nil,
                additionalTextInsets: nil
            ),
            peripherals: .init(
                showGutter: state.showGutter,
                showMinimap: state.showMinimap && !state.largeFileMode.isMinimapDisabled,
                showFoldingRibbon: state.showFoldingRibbon && !state.largeFileMode.isFoldingDisabled,
                codeSuggestionTriggerCharacters: completionDelegate.completionTriggerCharacters()
            )
        )
    }

    func visibleFindMatchHighlights(
        for state: EditorState,
        textView: TextView?,
        lineTable: LineOffsetTable?
    ) -> [SourceEditorFindMatchHighlight] {
        guard let textView,
              let lineTable else {
            return []
        }

        return state.renderedFindMatchHighlights(textView: textView, lineTable: lineTable).map { highlight in
            SourceEditorFindMatchHighlight(
                range: highlight.range,
                rect: highlight.rect,
                isSelected: highlight.isSelected
            )
        }
    }
}

struct SourceEditorFindMatchHighlight: Identifiable {
    let range: EditorRange
    let rect: CGRect
    let isSelected: Bool

    var id: String {
        "\(range.location):\(range.length):\(rect.minX):\(rect.minY):\(isSelected)"
    }

    var color: Color {
        if isSelected {
            return AppUI.Color.semantic.primary.opacity(0.28)
        }
        return AppUI.Color.semantic.warning.opacity(0.18)
    }

    var borderColor: Color {
        if isSelected {
            return AppUI.Color.semantic.primary.opacity(0.72)
        }
        return AppUI.Color.semantic.warning.opacity(0.42)
    }
}
