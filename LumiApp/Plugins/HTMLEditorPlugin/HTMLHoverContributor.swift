import Foundation

/// HTML 悬浮提示贡献器
///
/// 提供 HTML 标签和属性的悬浮文档。
@MainActor
final class HTMLHoverContributor: EditorHoverContributor {
    let id = "builtin.html.hover"

    func provideHover(context: EditorHoverContext) async -> [EditorHoverSuggestion] {
        guard HTMLKnowledgeBase.isSupported(languageId: context.languageId) else { return [] }
        guard let markdown = HTMLKnowledgeBase.hoverMarkdown(for: context.symbol) else { return [] }
        return [.init(markdown: markdown, priority: 120)]
    }
}
