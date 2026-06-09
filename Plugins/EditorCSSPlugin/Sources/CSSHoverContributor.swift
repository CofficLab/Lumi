import Foundation
import EditorService

@MainActor
public final class CSSHoverContributor: SuperEditorHoverContributor {
    public let id = "builtin.css.hover"

    public func provideHover(context: EditorHoverContext) async -> [EditorHoverSuggestion] {
        guard CSSKnowledgeBase.isSupported(languageId: context.languageId) else { return [] }
        guard let markdown = CSSKnowledgeBase.hoverMarkdown(for: context.symbol) else { return [] }
        return [.init(markdown: markdown, priority: 120)]
    }
}
