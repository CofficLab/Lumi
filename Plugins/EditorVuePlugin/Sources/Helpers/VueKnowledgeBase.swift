import Foundation
import EditorService

/// Vue 知识库
///
/// 提供 Vue SFC 模板指令、内置组件、特殊属性的定义，
/// 用于补全和悬浮提示。
enum VueKnowledgeBase {
    // MARK: - 支持的语言 ID

    static let supportedLanguageIDs: Set<String> = ["vue"]

    static func isSupported(languageId: String) -> Bool {
        supportedLanguageIDs.contains(languageId.lowercased())
    }

    // MARK: - SFC 区块

    struct SFCBlock: Sendable {
        let tag: String
        let summary: String
        let attributes: [String]
    }

    static let sfcBlocks: [SFCBlock] = [
        .init(tag: "template", summary: "Defines the component's HTML template. Only one root `<template>` is allowed per SFC.", attributes: ["lang"]),
        .init(tag: "script", summary: "Defines the component's logic and data. Use `<script setup>` for Composition API sugar.", attributes: ["setup", "lang", "name"]),
        .init(tag: "style", summary: "Defines the component's CSS styles. Use `scoped` to limit styles to this component only.", attributes: ["scoped", "module", "lang"]),
    ]

    // MARK: - 模板指令

    struct Directive: Sendable {
        let name: String
        let shorthand: String?
        let summary: String
        let example: String
    }

    static let directives: [Directive] = [
        .init(name: "v-if", shorthand: nil, summary: "Conditionally renders the element. Removed from DOM when false.", example: "v-if=\"isVisible\""),
        .init(name: "v-else-if", shorthand: nil, summary: "Denotes the else-if block for v-if. Must be immediately after a v-if or v-else-if element.", example: "v-else-if=\"type === 'B'\""),
        .init(name: "v-else", shorthand: nil, summary: "Denotes the else block for v-if. No expression needed.", example: "v-else"),
        .init(name: "v-show", shorthand: nil, summary: "Toggles CSS display property. Element stays in DOM.", example: "v-show=\"isVisible\""),
        .init(name: "v-for", shorthand: nil, summary: "Renders the element multiple times based on source data.", example: "v-for=\"item in items\" :key=\"item.id\""),
        .init(name: "v-on", shorthand: "@", summary: "Attaches an event listener to the element.", example: "@click=\"handleClick\""),
        .init(name: "v-bind", shorthand: ":", summary: "Dynamically binds one or more attributes to an expression.", example: ":class=\"{ active: isActive }\""),
        .init(name: "v-model", shorthand: nil, summary: "Creates two-way data binding on form inputs, components.", example: "v-model=\"message\""),
        .init(name: "v-slot", shorthand: "#", summary: "Denotes a named slot or scoped slot.", example: "#header=\"{ item }\""),
        .init(name: "v-html", shorthand: nil, summary: "Renders raw HTML inside the element. ⚠️ Be cautious of XSS.", example: "v-html=\"rawHtml\""),
        .init(name: "v-text", shorthand: nil, summary: "Updates the element's textContent.", example: "v-text=\"message\""),
        .init(name: "v-once", shorthand: nil, summary: "Renders the element once. Subsequent re-renders skip it.", example: "v-once"),
        .init(name: "v-pre", shorthand: nil, summary: "Skips compilation for this element and its children.", example: "v-pre"),
        .init(name: "v-cloak", shorthand: nil, summary: "Remains on element until Vue compilation finishes. Use with [v-cloak] { display: none } CSS.", example: "v-cloak"),
        .init(name: "v-memo", shorthand: nil, summary: "Caches a template sub-tree. Re-renders only when values change. (Vue 3.2+)", example: "v-memo=\"[value]\""),
    ]

    static let directiveMap: [String: Directive] = Dictionary(
        uniqueKeysWithValues: directives.map { ($0.name, $0) }
    )

    // MARK: - 事件修饰符

    static let eventModifiers: [(name: String, summary: String)] = [
        (".prevent", "Calls event.preventDefault(). Equivalent to @click.prevent"),
        (".stop", "Calls event.stopPropagation()."),
        (".capture", "Use capture mode when adding event listener."),
        (".self", "Only trigger handler if event was dispatched from this element."),
        (".once", "Trigger handler at most once."),
        (".passive", "Attaches a DOM event with { passive: true }. Good for touch/wheel."),
        (".exact", "Exact modifier key combination required."),
    ]

    // MARK: - 内置组件

    struct BuiltInComponent: Sendable {
        let name: String
        let summary: String
        let props: [String]
    }

    static let builtInComponents: [BuiltInComponent] = [
        .init(name: "Transition", summary: "Applies transition animations to a single element or component.", props: ["name", "mode", "appear", "duration"]),
        .init(name: "TransitionGroup", summary: "Applies transition animations to multiple elements (e.g., list items).", props: ["name", "tag", "move-class"]),
        .init(name: "KeepAlive", summary: "Caches component instances to avoid re-rendering when toggled.", props: ["include", "exclude", "max"]),
        .init(name: "Teleport", summary: "Renders content at a different location in the DOM.", props: ["to", "disabled"]),
        .init(name: "Suspense", summary: "Coordinates async dependencies within a component tree.", props: []),
        .init(name: "component", summary: "Dynamic component rendering via the :is prop.", props: ["is"]),
        .init(name: "slot", summary: "Defines a slot outlet for content distribution.", props: ["name"]),
    ]

    static let builtInComponentMap: [String: BuiltInComponent] = Dictionary(
        uniqueKeysWithValues: builtInComponents.map { ($0.name, $0) }
    )

    // MARK: - 特殊属性

    static let specialAttributes: [(name: String, summary: String)] = [
        ("key", "Hint for Vue's virtual DOM diffing algorithm. Use with v-for."),
        ("ref", "Registers a reference to the element or component instance."),
        ("is", "Used on <component> for dynamic component binding."),
        ("slot", "Deprecated in Vue 3 — use v-slot instead."),
    ]

    // MARK: - Script Setup 常用宏

    static let scriptSetupMacros: [(name: String, summary: String)] = [
        ("defineProps", "Declare props for the component. Compiler macro, no import needed."),
        ("defineEmits", "Declare events the component can emit. Compiler macro."),
        ("defineExpose", "Explicitly expose component properties to template refs."),
        ("defineModel", "Create a two-way binding v-model component (Vue 3.4+)."),
        ("withDefaults", "Provide default values for props when using TypeScript defineProps."),
    ]

    // MARK: - 补全

    static func directiveSuggestions(prefix: String) -> [EditorCompletionSuggestion] {
        let normalized = prefix.lowercased()
        return directives
            .filter { normalized.isEmpty || $0.name.hasPrefix(normalized) || ($0.shorthand?.hasPrefix(normalized) ?? false) }
            .map { directive in
                let label = directive.shorthand.map { "\(directive.name) (\($0))" } ?? directive.name
                return EditorCompletionSuggestion(
                    label: label,
                    insertText: directive.name,
                    detail: directive.summary,
                    priority: 950
                )
            }
    }

    static func eventModifierSuggestions(prefix: String) -> [EditorCompletionSuggestion] {
        let normalized = prefix.lowercased()
        return eventModifiers
            .filter { normalized.isEmpty || $0.name.hasPrefix(normalized) }
            .map { mod in
                EditorCompletionSuggestion(
                    label: mod.name,
                    insertText: mod.name,
                    detail: mod.summary,
                    priority: 940
                )
            }
    }

    static func builtInComponentSuggestions(prefix: String) -> [EditorCompletionSuggestion] {
        let normalized = prefix.lowercased()
        return builtInComponents
            .filter { normalized.isEmpty || $0.name.lowercased().hasPrefix(normalized) }
            .map { comp in
                EditorCompletionSuggestion(
                    label: comp.name,
                    insertText: comp.name,
                    detail: comp.summary,
                    priority: 930
                )
            }
    }

    static func scriptSetupMacroSuggestions(prefix: String) -> [EditorCompletionSuggestion] {
        let normalized = prefix.lowercased()
        return scriptSetupMacros
            .filter { normalized.isEmpty || $0.name.lowercased().hasPrefix(normalized) }
            .map { macro in
                EditorCompletionSuggestion(
                    label: macro.name,
                    insertText: macro.name,
                    detail: macro.summary,
                    priority: 935
                )
            }
    }

    static func sfcBlockSuggestions(prefix: String) -> [EditorCompletionSuggestion] {
        let normalized = prefix.lowercased()
        return sfcBlocks
            .filter { normalized.isEmpty || $0.tag.hasPrefix(normalized) }
            .map { block in
                EditorCompletionSuggestion(
                    label: block.tag,
                    insertText: block.tag,
                    detail: block.summary,
                    priority: 945
                )
            }
    }

    // MARK: - 悬浮提示

    static func hoverMarkdown(for symbol: String) -> String? {
        let normalized = symbol.lowercased()

        // 指令
        if let directive = directiveMap[normalized] {
            let shorthandInfo = directive.shorthand.map { "\n\nShorthand: `\( $0)`" } ?? ""
            return """
            `\(directive.name)`\(shorthandInfo)

            \(directive.summary)

            ```
            \(directive.example)
            ```
            """
        }

        // 内置组件
        if let comp = builtInComponentMap[symbol] {
            let propsInfo = comp.props.isEmpty ? "" : "\n\nProps: `\(comp.props.joined(separator: "`, `"))`"
            return """
            `<\(comp.name)>`

            \(comp.summary)\(propsInfo)
            """
        }

        // Script Setup 宏
        if let macro = scriptSetupMacros.first(where: { $0.name == symbol }) {
            return """
            `\(macro.name)`

            \(macro.summary)
            """
        }

        // SFC 区块
        if let block = sfcBlocks.first(where: { $0.tag == normalized }) {
            let attrs = block.attributes.isEmpty ? "" : "\n\nAttributes: `\(block.attributes.joined(separator: "`, `"))`"
            return """
            `<\(block.tag)>`

            \(block.summary)\(attrs)
            """
        }

        // 事件修饰符
        if let mod = eventModifiers.first(where: { $0.name == normalized || $0.name == symbol }) {
            return """
            `\(mod.name)`

            \(mod.summary)
            """
        }

        return nil
    }
}
