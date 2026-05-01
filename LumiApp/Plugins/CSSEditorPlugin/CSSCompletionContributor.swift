import Foundation

@MainActor
final class CSSCompletionContributor: SuperEditorCompletionContributor {
    let id = "builtin.css.completion"

    func provideSuggestions(context: EditorCompletionContext) async -> [EditorCompletionSuggestion] {
        guard CSSKnowledgeBase.isSupported(languageId: context.languageId) else { return [] }
        return CSSKnowledgeBase.propertySuggestions(prefix: context.prefix) +
            CSSKnowledgeBase.valueSuggestions(prefix: context.prefix)
    }
}
