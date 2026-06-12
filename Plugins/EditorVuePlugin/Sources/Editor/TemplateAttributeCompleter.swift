import Foundation
import EditorService
import os

/// Vue 模板指令属性上下文感知补全
///
/// 根据当前光标在模板中的位置，提供精确的指令和属性补全：
/// - `v-` 前缀 → 所有 Vue 指令
/// - `:` 前缀 → v-bind 相关属性
/// - `@` 前缀 → 事件相关属性和修饰符
/// - `#` 前缀 → 插槽相关
/// - `v-for` → 自动补全迭代语法
/// - 事件修饰符 `.xxx` → 修饰符补全
/// - 按键修饰符 → 常用按键名
@MainActor
final class TemplateAttributeCompleter: SuperEditorCompletionContributor {
    let id = "builtin.vue.template-attr"

    func provideSuggestions(context: EditorCompletionContext) async -> [EditorCompletionSuggestion] {
        guard VueKnowledgeBase.isSupported(languageId: context.languageId) else { return [] }

        let prefix = context.prefix.trimmingCharacters(in: .whitespacesAndNewlines)

        var suggestions: [EditorCompletionSuggestion] = []

        // 1. v- 前缀指令
        if prefix.hasPrefix("v-") {
            suggestions.append(contentsOf: directiveCompletions(prefix: prefix))
        }

        // 2. : 缩写 → v-bind 属性
        if prefix == ":" || prefix.hasPrefix(":") && prefix.count <= 3 {
            suggestions.append(contentsOf: vBindCompletions(prefix: prefix))
        }

        // 3. @ 缩写 → 事件
        if prefix == "@" || (prefix.hasPrefix("@") && !prefix.contains(".")) {
            suggestions.append(contentsOf: eventCompletions(prefix: prefix))
        }

        // 4. 事件修饰符 .xxx
        if prefix.hasPrefix("@") && prefix.contains(".") {
            suggestions.append(contentsOf: eventModifierCompletions(prefix: prefix))
        }

        // 5. # 缩写 → 插槽
        if prefix == "#" || prefix.hasPrefix("#") {
            suggestions.append(contentsOf: slotCompletions(prefix: prefix))
        }

        // 6. v-for 特殊补全
        if prefix.hasPrefix("v-for") || prefix == "v-for" {
            suggestions.append(contentsOf: vForSnippetCompletions())
        }

        // 7. v-model 修饰符
        if prefix.hasPrefix("v-model") && prefix.contains(".") {
            suggestions.append(contentsOf: vModelModifierCompletions(prefix: prefix))
        }

        return suggestions
    }

    // MARK: - 指令补全

    private func directiveCompletions(prefix: String) -> [EditorCompletionSuggestion] {
        VueKnowledgeBase.directiveSuggestions(prefix: prefix)
    }

    // MARK: - v-bind 属性补全

    private func vBindCompletions(prefix: String) -> [EditorCompletionSuggestion] {
        let commonBindings: [(name: String, detail: String, insert: String)] = [
            ("class", "Dynamic class binding", ":class=\"\""),
            ("style", "Dynamic style binding", ":style=\"\""),
            ("key", "Unique key for v-for or component", ":key=\"\""),
            ("ref", "Template reference", ":ref=\"\""),
            ("is", "Dynamic component binding", ":is=\"\""),
            ("disabled", "Disabled binding", ":disabled=\"\""),
            ("value", "Value binding", ":value=\"\""),
            ("modelValue", "v-model value (Vue 3)", ":modelValue=\"\""),
        ]

        return commonBindings.map { binding in
            EditorCompletionSuggestion(
                label: binding.name,
                insertText: binding.insert,
                detail: binding.detail,
                priority: 945
            )
        }
    }

    // MARK: - 事件补全

    private func eventCompletions(prefix: String) -> [EditorCompletionSuggestion] {
        let events: [(name: String, detail: String, insert: String)] = [
            ("click", "Click event", "@click=\"\""),
            ("input", "Input event", "@input=\"\""),
            ("change", "Change event", "@change=\"\""),
            ("submit", "Form submit event", "@submit=\"\""),
            ("keyup", "Key up event", "@keyup=\"\""),
            ("keydown", "Key down event", "@keydown=\"\""),
            ("keypress", "Key press event", "@keypress=\"\""),
            ("mouseenter", "Mouse enter event", "@mouseenter=\"\""),
            ("mouseleave", "Mouse leave event", "@mouseleave=\"\""),
            ("focus", "Focus event", "@focus=\"\""),
            ("blur", "Blur event", "@blur=\"\""),
            ("scroll", "Scroll event", "@scroll=\"\""),
            ("resize", "Resize event", "@resize=\"\""),
            ("load", "Load event", "@load=\"\""),
            ("error", "Error event", "@error=\"\""),
            ("dblclick", "Double click event", "@dblclick=\"\""),
            ("contextmenu", "Context menu event", "@contextmenu=\"\""),
            ("mouseover", "Mouse over event", "@mouseover=\"\""),
            ("mouseout", "Mouse out event", "@mouseout=\"\""),
            ("touchstart", "Touch start event", "@touchstart=\"\""),
            ("touchmove", "Touch move event", "@touchmove=\"\""),
            ("touchend", "Touch end event", "@touchend=\"\""),
        ]

        // 过滤匹配的
        let eventPrefix = String(prefix.dropFirst()) // 去掉 @
        let normalized = eventPrefix.lowercased()

        return events
            .filter { normalized.isEmpty || $0.name.hasPrefix(normalized) }
            .map { event in
                EditorCompletionSuggestion(
                    label: event.name,
                    insertText: event.insert,
                    detail: event.detail,
                    priority: 945
                )
            }
    }

    // MARK: - 事件修饰符补全

    private func eventModifierCompletions(prefix: String) -> [EditorCompletionSuggestion] {
        // 解析 @click. → 提供 .prevent, .stop 等
        let parts = prefix.split(separator: ".", omittingEmptySubsequences: false)
        guard parts.count >= 2 else { return [] }

        // 基础修饰符
        return VueKnowledgeBase.eventModifierSuggestions(prefix: "." + String(parts.last ?? ""))
    }

    // MARK: - 插槽补全

    private func slotCompletions(prefix: String) -> [EditorCompletionSuggestion] {
        let slotSuggestions: [(name: String, detail: String, insert: String)] = [
            ("default", "Default slot", "#default"),
            ("header", "Named slot: header", "#header"),
            ("footer", "Named slot: footer", "#footer"),
            ("content", "Named slot: content", "#content"),
        ]

        let slotPrefix = String(prefix.dropFirst()) // 去掉 #
        let normalized = slotPrefix.lowercased()

        return slotSuggestions
            .filter { normalized.isEmpty || $0.name.hasPrefix(normalized) }
            .map { slot in
                EditorCompletionSuggestion(
                    label: slot.name,
                    insertText: slot.insert,
                    detail: slot.detail,
                    priority: 945
                )
            }
    }

    // MARK: - v-for 语法片段

    private func vForSnippetCompletions() -> [EditorCompletionSuggestion] {
        [
            EditorCompletionSuggestion(
                label: "v-for item",
                insertText: "v-for=\"item in items\" :key=\"item.id\"",
                detail: "Iterate over an array",
                priority: 955
            ),
            EditorCompletionSuggestion(
                label: "v-for with index",
                insertText: "v-for=\"(item, index) in items\" :key=\"index\"",
                detail: "Iterate with index",
                priority: 954
            ),
            EditorCompletionSuggestion(
                label: "v-for object",
                insertText: "v-for=\"(value, key) in object\" :key=\"key\"",
                detail: "Iterate over object properties",
                priority: 953
            ),
            EditorCompletionSuggestion(
                label: "v-for range",
                insertText: "v-for=\"n in 10\" :key=\"n\"",
                detail: "Iterate over a range",
                priority: 952
            ),
        ]
    }

    // MARK: - v-model 修饰符

    private func vModelModifierCompletions(prefix: String) -> [EditorCompletionSuggestion] {
        let modifiers: [(name: String, detail: String)] = [
            (".lazy", "Sync on change event instead of input"),
            (".number", "Cast input value to number"),
            (".trim", "Trim whitespace from input"),
        ]

        // 提取当前修饰符前缀
        let parts = prefix.split(separator: ".")
        let lastPart = parts.last.map { "." + $0 } ?? "."

        return modifiers
            .filter { $0.name.hasPrefix(lastPart.lowercased()) || lastPart == "." }
            .map { mod in
                EditorCompletionSuggestion(
                    label: mod.name,
                    insertText: mod.name,
                    detail: mod.detail,
                    priority: 946
                )
            }
    }
}
