import Foundation

/// Vue 补全贡献器
///
/// 提供 Vue 模板指令、内置组件、事件修饰符和 Script Setup 宏的补全建议。
@MainActor
final class VueCompletionContributor: SuperEditorCompletionContributor {
    let id = "builtin.vue.completion"

    func provideSuggestions(context: EditorCompletionContext) async -> [EditorCompletionSuggestion] {
        guard VueKnowledgeBase.isSupported(languageId: context.languageId) else { return [] }

        let prefix = context.prefix.trimmingCharacters(in: .whitespacesAndNewlines)

        var suggestions: [EditorCompletionSuggestion] = []

        // 模板指令 (v-xxx)
        if prefix.hasPrefix("v-") || prefix.hasPrefix(":") || prefix.hasPrefix("@") || prefix.hasPrefix("#") {
            suggestions.append(contentsOf: VueKnowledgeBase.directiveSuggestions(prefix: prefix))
        }

        // 事件修饰符 (.prevent, .stop 等) — 前缀以 . 开头时
        if prefix.hasPrefix(".") {
            suggestions.append(contentsOf: VueKnowledgeBase.eventModifierSuggestions(prefix: prefix))
        }

        // 内置组件 (Transition, KeepAlive, Teleport 等)
        suggestions.append(contentsOf: VueKnowledgeBase.builtInComponentSuggestions(prefix: prefix))

        // Script Setup 宏 (defineProps, defineEmits 等)
        suggestions.append(contentsOf: VueKnowledgeBase.scriptSetupMacroSuggestions(prefix: prefix))

        // SFC 区块标签 (template, script, style)
        suggestions.append(contentsOf: VueKnowledgeBase.sfcBlockSuggestions(prefix: prefix))

        // Scoped CSS 深度选择器 (:deep, :slotted, :global)
        if prefix.hasPrefix(":deep") || prefix.hasPrefix(":slotted") || prefix.hasPrefix(":global") {
            suggestions.append(contentsOf: ScopedStyleHelper.deepSelectorSuggestions(prefix: prefix))
        }

        return suggestions
    }
}
