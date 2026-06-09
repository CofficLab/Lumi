import Foundation
import EditorService

/// Vue 悬浮提示贡献器
///
/// 提供 Vue 指令、内置组件、Script Setup 宏、SFC 区块和
/// Scoped CSS 深度选择器的悬浮文档。
@MainActor
final class VueHoverContributor: SuperEditorHoverContributor {
    let id = "builtin.vue.hover"

    func provideHover(context: EditorHoverContext) async -> [EditorHoverSuggestion] {
        guard VueKnowledgeBase.isSupported(languageId: context.languageId) else { return [] }

        // 先检查 Scoped CSS 选择器
        if let markdown = ScopedStyleHelper.hoverMarkdown(for: context.symbol) {
            return [.init(markdown: markdown, priority: 125)]
        }

        // 再检查 Vue 指令、组件等
        if let markdown = VueKnowledgeBase.hoverMarkdown(for: context.symbol) {
            return [.init(markdown: markdown, priority: 120)]
        }

        return []
    }
}
