import Foundation

/// HTML 补全贡献器
///
/// 提供 HTML 标签名和属性名的补全建议。
@MainActor
final class HTMLCompletionContributor: SuperEditorCompletionContributor {
    let id = "builtin.html.completion"

    func provideSuggestions(context: EditorCompletionContext) async -> [EditorCompletionSuggestion] {
        guard HTMLKnowledgeBase.isSupported(languageId: context.languageId) else { return [] }

        let prefix = context.prefix.trimmingCharacters(in: .whitespacesAndNewlines)
        return HTMLKnowledgeBase.tagSuggestions(prefix: prefix) +
            HTMLKnowledgeBase.attributeSuggestions(prefix: prefix)
    }
}
