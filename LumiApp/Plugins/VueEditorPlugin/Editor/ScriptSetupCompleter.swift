import Foundation
import os

/// Script Setup 上下文感知补全
///
/// 在 `<script setup>` 和 `<script>` 区块中提供：
/// - defineProps / defineEmits / defineExpose / defineModel 宏的参数补全
/// - ref / computed / watch 等 Composition API 补全
/// - 生命周期钩子补全
/// - 常用 Vue 导入补全
@MainActor
final class ScriptSetupCompleter: SuperEditorCompletionContributor {
    let id = "builtin.vue.script-setup"

    func provideSuggestions(context: EditorCompletionContext) async -> [EditorCompletionSuggestion] {
        guard VueKnowledgeBase.isSupported(languageId: context.languageId) else { return [] }

        let prefix = context.prefix.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !prefix.isEmpty else { return [] }

        var suggestions: [EditorCompletionSuggestion] = []

        // 1. Script Setup 宏
        suggestions.append(contentsOf: macroCompletions(prefix: prefix))

        // 2. Composition API
        suggestions.append(contentsOf: compositionAPICompletions(prefix: prefix))

        // 3. 生命周期钩子
        suggestions.append(contentsOf: lifecycleCompletions(prefix: prefix))

        // 4. 常用工具函数
        suggestions.append(contentsOf: utilityCompletions(prefix: prefix))

        return suggestions
    }

    // MARK: - 宏补全

    private func macroCompletions(prefix: String) -> [EditorCompletionSuggestion] {
        let macros: [(name: String, insert: String, detail: String)] = [
            ("defineProps",
             "defineProps<{$0}>()",
             "Declare component props with TypeScript interface. Compiler macro — no import needed."),
            ("defineEmits",
             "defineEmits<{$0}>()",
             "Declare component events. Compiler macro — no import needed."),
            ("defineExpose",
             "defineExpose({$0})",
             "Explicitly expose component properties to template refs."),
            ("defineModel",
             "defineModel<$0>()",
             "Create a two-way binding v-model prop (Vue 3.4+). Compiler macro."),
            ("defineOptions",
             "defineOptions({$0})",
             "Define component options like name, inheritAttrs (Vue 3.3+). Compiler macro."),
            ("defineSlots",
             "defineSlots<$0>()",
             "Declare typed slots (Vue 3.3+). Compiler macro."),
        ]

        let normalized = prefix.lowercased()
        return macros
            .filter { normalized.isEmpty || $0.name.lowercased().hasPrefix(normalized) }
            .map { macro in
                EditorCompletionSuggestion(
                    label: macro.name,
                    insertText: macro.insert,
                    detail: macro.detail,
                    priority: 955
                )
            }
    }

    // MARK: - Composition API 补全

    private func compositionAPICompletions(prefix: String) -> [EditorCompletionSuggestion] {
        let apis: [(name: String, insert: String, detail: String)] = [
            ("ref",
             "ref($0)",
             "Create a reactive reference. Access value with .value."),
            ("computed",
             "computed(() => $0)",
             "Create a computed property that auto-updates."),
            ("reactive",
             "reactive($0)",
             "Create a deep reactive object. No .value needed."),
            ("watch",
             "watch($1, ($2) => {\n    $0\n})",
             "Watch a reactive source and run side effects."),
            ("watchEffect",
             "watchEffect(() => {\n    $0\n})",
             "Run side effect and auto-track dependencies."),
            ("watchSyncEffect",
             "watchSyncEffect(() => {\n    $0\n})",
             "Synchronous version of watchEffect (Vue 3.4+)."),
            ("toRef",
             "toRef($0, '')",
             "Create a ref for a property on a reactive object."),
            ("toRefs",
             "toRefs($0)",
             "Convert reactive object to refs."),
            ("toValue",
             "toValue($0)",
             "Normalize value/ref/getter to a value (Vue 3.3+)."),
            ("shallowRef",
             "shallowRef($0)",
             "Shallow ref — only .value changes trigger updates."),
            ("shallowReactive",
             "shallowReactive($0)",
             "Shallow reactive — only root-level changes trigger updates."),
            ("triggerRef",
             "triggerRef($0)",
             "Force trigger a shallow ref's effects."),
            ("customRef",
             "customRef((track, trigger) => ({\n    get() { $0 },\n    set(val) { trigger() }\n}))",
             "Create a custom ref with explicit track/trigger control."),
            ("unref",
             "unref($0)",
             "Get value from ref or return value as-is."),
            ("isRef",
             "isRef($0)",
             "Check if value is a ref."),
            ("provide",
             "provide($0, $1)",
             "Provide a value to descendant components."),
            ("inject",
             "inject($0, $1)",
             "Inject a value from ancestor components."),
            ("useTemplateRef",
             "useTemplateRef<$0>('')",
             "Type-safe template ref (Vue 3.5+)."),
            ("useId",
             "useId()",
             "Generate unique ID for SSR-friendly form elements (Vue 3.5+)."),
        ]

        let normalized = prefix.lowercased()
        return apis
            .filter { normalized.isEmpty || $0.name.lowercased().hasPrefix(normalized) }
            .map { api in
                EditorCompletionSuggestion(
                    label: api.name,
                    insertText: api.insert,
                    detail: api.detail,
                    priority: 935
                )
            }
    }

    // MARK: - 生命周期钩子

    private func lifecycleCompletions(prefix: String) -> [EditorCompletionSuggestion] {
        let hooks: [(name: String, insert: String, detail: String)] = [
            ("onMounted",
             "onMounted(() => {\n    $0\n})",
             "Called after the component is mounted to the DOM."),
            ("onUnmounted",
             "onUnmounted(() => {\n    $0\n})",
             "Called before the component is unmounted."),
            ("onBeforeMount",
             "onBeforeMount(() => {\n    $0\n})",
             "Called right before mounting."),
            ("onBeforeUnmount",
             "onBeforeUnmount(() => {\n    $0\n})",
             "Called right before unmounting."),
            ("onUpdated",
             "onUpdated(() => {\n    $0\n})",
             "Called after a reactive state change causes DOM update."),
            ("onBeforeUpdate",
             "onBeforeUpdate(() => {\n    $0\n})",
             "Called before a DOM update."),
            ("onActivated",
             "onActivated(() => {\n    $0\n})",
             "Called when a kept-alive component is activated."),
            ("onDeactivated",
             "onDeactivated(() => {\n    $0\n})",
             "Called when a kept-alive component is deactivated."),
            ("onErrorCaptured",
             "onErrorCaptured((err, instance, info) => {\n    $0\n})",
             "Capture errors from descendant components."),
            ("onRenderTracked",
             "onRenderTracked((e) => {\n    $0\n})",
             "Debug hook: track reactive dependencies."),
            ("onRenderTriggered",
             "onRenderTriggered((e) => {\n    $0\n})",
             "Debug hook: triggered by reactive changes."),
            ("onServerPrefetch",
             "onServerPrefetch(async () => {\n    $0\n})",
             "Server-side only: prefetch data during SSR."),
        ]

        let normalized = prefix.lowercased()
        return hooks
            .filter { normalized.isEmpty || $0.name.lowercased().hasPrefix(normalized) }
            .map { hook in
                EditorCompletionSuggestion(
                    label: hook.name,
                    insertText: hook.insert,
                    detail: hook.detail,
                    priority: 930
                )
            }
    }

    // MARK: - 工具函数

    private func utilityCompletions(prefix: String) -> [EditorCompletionSuggestion] {
        let utils: [(name: String, insert: String, detail: String)] = [
            ("nextTick",
             "await nextTick()",
             "Wait for the next DOM update cycle."),
            ("useSlots",
             "useSlots()",
             "Get typed slot access in script setup."),
            ("useAttrs",
             "useAttrs()",
             "Get fallthrough attributes in script setup."),
            ("mergeModels",
             "mergeModels($0, $1)",
             "Merge multiple v-model definitions (Vue 3.4+)."),
            ("useCssModule",
             "useCssModule('$0')",
             "Access CSS module classes in script setup."),
        ]

        let normalized = prefix.lowercased()
        return utils
            .filter { normalized.isEmpty || $0.name.lowercased().hasPrefix(normalized) }
            .map { util in
                EditorCompletionSuggestion(
                    label: util.name,
                    insertText: util.insert,
                    detail: util.detail,
                    priority: 925
                )
            }
    }
}
