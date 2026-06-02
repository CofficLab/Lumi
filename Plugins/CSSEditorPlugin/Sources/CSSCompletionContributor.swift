import Foundation
import EditorService

@MainActor
public final class CSSCompletionContributor: SuperEditorCompletionContributor {
    public let id = "builtin.css.completion"

    public func provideSuggestions(context: EditorCompletionContext) async -> [EditorCompletionSuggestion] {
        guard CSSKnowledgeBase.isSupported(languageId: context.languageId) else { return [] }
        return CSSKnowledgeBase.propertySuggestions(prefix: context.prefix) +
            CSSKnowledgeBase.valueSuggestions(prefix: context.prefix)
    }
}
