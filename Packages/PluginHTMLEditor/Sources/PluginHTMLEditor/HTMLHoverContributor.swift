import Foundation
import EditorService

/// HTML 悬浮提示贡献器
///
/// 提供 HTML 标签和属性的悬浮文档。
@MainActor
public final class HTMLHoverContributor: SuperEditorHoverContributor {
    public let id = "builtin.html.hover"

    public func provideHover(context: EditorHoverContext) async -> [EditorHoverSuggestion] {
        guard HTMLKnowledgeBase.isSupported(languageId: context.languageId) else { return [] }
        guard let markdown = HTMLKnowledgeBase.hoverMarkdown(for: context.symbol) ??
            ARIAAttributeDatabase.hoverMarkdown(for: context.symbol) else { return [] }
        return [.init(markdown: markdown, priority: 120)]
    }
}
