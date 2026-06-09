import Foundation
import EditorService

/// HTML Emmet 补全贡献器
///
/// 将 Emmet 缩写作为补全项提供，用户按回车即可展开。
/// 这种方式避免了与 Tab 键缩进的冲突，同时保持 Emmet 的可见性。
@MainActor
public final class HTMLEmmetContributor: SuperEditorCompletionContributor {
    public let id = "builtin.html.emmet"

    public func provideSuggestions(context: EditorCompletionContext) async -> [EditorCompletionSuggestion] {
        guard HTMLKnowledgeBase.isSupported(languageId: context.languageId) else { return [] }

        let prefix = context.prefix.trimmingCharacters(in: .whitespacesAndNewlines)
        guard EmmetEngine.isValidAbbreviation(prefix) else { return [] }

        // 检查是否包含 Emmet 操作符，如果是则更有信心
        let hasOperator = prefix.unicodeScalars.contains { char in
            ".#>+*^[]{}()$@".unicodeScalars.contains(char)
        }

        // 简单标签名不展开 Emmet
        let isSimpleTag = HTMLKnowledgeBase.tags.contains { $0.name.lowercased() == prefix.lowercased() }
        if isSimpleTag, !hasOperator {
            return []
        }

        // 尝试展开
        let syntax = EmmetConfig.syntaxMode(for: context.languageId)
        guard let expansion = EmmetEngine.expand(prefix, syntax: syntax) else { return [] }

        // 返回 Emmet 补全项
        let detailText: String
        if hasOperator {
            detailText = "Emmet: \(prefix)"
        } else {
            detailText = "Emmet → \(expansion.text.prefix(50))..."
        }

        return [
            EditorCompletionSuggestion(
                label: prefix,
                insertText: expansion.text,
                detail: detailText,
                priority: 950 // 高于标签补全
            )
        ]
    }
}
