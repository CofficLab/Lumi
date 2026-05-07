import Foundation

@MainActor
final class CSSHoverContributor: SuperEditorHoverContributor {
    let id = "builtin.css.hover"

    func provideHover(context: EditorHoverContext) async -> [EditorHoverSuggestion] {
        guard CSSKnowledgeBase.isSupported(languageId: context.languageId) else { return [] }
        guard let markdown = CSSKnowledgeBase.hoverMarkdown(for: context.symbol) else { return [] }
        return [.init(markdown: markdown, priority: 120)]
    }
}
