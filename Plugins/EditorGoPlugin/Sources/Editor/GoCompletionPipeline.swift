import Foundation
import EditorService


/// Go 轻量补全管线。
///
/// gopls 仍是主要补全来源；这里提供无需等待 LSP 的 Go 语法片段和常用关键字。
@MainActor
public final class GoCompletionContributor: SuperEditorCompletionContributor {
    public let id = "builtin.go.completion-pipeline"

    public func provideSuggestions(context: EditorCompletionContext) async -> [EditorCompletionSuggestion] {
        guard context.languageId == "go" else { return [] }
        return GoCompletionPipeline
            .suggestions(prefix: context.prefix, isTypeContext: context.isTypeContext)
            .map {
                EditorCompletionSuggestion(
                    label: $0.label,
                    insertText: $0.insertText,
                    detail: $0.detail,
                    priority: priority(for: $0.detail)
                )
            }
    }

    private func priority(for detail: String) -> Int {
        switch detail {
        case "Go predeclared type":
            45
        case "Go keyword":
            40
        default:
            62
        }
    }
}
