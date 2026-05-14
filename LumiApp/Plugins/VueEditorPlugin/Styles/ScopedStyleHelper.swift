import Foundation

/// Scoped CSS 知识库
///
/// 提供 Vue `<style scoped>` 相关的特殊选择器和穿透语法，
/// 用于补全和悬浮提示。
enum ScopedStyleHelper {

    // MARK: - 深度选择器

    /// Vue 3 的深度选择器（替代 Vue 2 的 /deep/ 和 >>>）
    static let deepSelectors: [(name: String, summary: String)] = [
        (":deep()", "深度选择器：穿透 scoped 样式，影响子组件内部元素。编译后变为属性选择器如 [data-v-xxx] .child。"),
        (":slotted()", "插槽选择器：影响通过 <slot> 渲染的内容。用于给插槽内容提供 scoped 样式。"),
        (":global()", "全局选择器：使该选择器不受 scoped 限制，影响全局同名元素。"),
    ]

    // MARK: - 已弃用的深度选择器（Vue 2）

    static let deprecatedDeepSelectors: [(name: String, replacement: String, summary: String)] = [
        (">>>", ":deep()", "Deprecated in Vue 3. Use :deep() instead."),
        ("/deep/", ":deep()", "Deprecated in Vue 3. Use :deep() instead."),
        ("::v-deep", ":deep()", "Deprecated in Vue 3. Use :deep() instead."),
    ]

    // MARK: - v-bind 在 CSS 中

    static let cssVBindInfo: String = """
    **`v-bind()` in CSS**

    Allows dynamic CSS values from component state.

    ```vue
    <style scoped>
    .text {
      color: v-bind('textColor');
    }
    </style>
    ```

    The `textColor` variable must be defined in `<script setup>`.
    """

    // MARK: - Scoped 属性说明

    static let scopedInfo: String = """
    **`<style scoped>`**

    When a `<style>` tag has the `scoped` attribute, its CSS will apply only to elements of the current component.

    - Uses PostCSS to transform selectors with a unique attribute (e.g., `data-v-xxxxxxx`).
    - Child component root elements are NOT affected by scoped styles.
    - Use `:deep()` to style elements inside child components.
    """

    // MARK: - 补全

    static func deepSelectorSuggestions(prefix: String) -> [EditorCompletionSuggestion] {
        let normalized = prefix.lowercased()
        return deepSelectors
            .filter { normalized.isEmpty || $0.name.hasPrefix(normalized) }
            .map { selector in
                EditorCompletionSuggestion(
                    label: selector.name,
                    insertText: selector.name,
                    detail: selector.summary,
                    priority: 945
                )
            }
    }

    static func hoverMarkdown(for symbol: String) -> String? {
        let normalized = symbol.lowercased()

        // 深度选择器
        if let item = deepSelectors.first(where: { $0.name.lowercased() == normalized || $0.name.lowercased().hasPrefix(normalized) }) {
            return """
            `\(item.name)`

            \(item.summary)

            **Example:**
            ```css
            \(item.name) .child-element {
              color: red;
            }
            ```
            """
        }

        // 已弃用的选择器
        if let deprecated = deprecatedDeepSelectors.first(where: { $0.name.lowercased() == normalized }) {
            return """
            `\(deprecated.name)` ⚠️ Deprecated

            \(deprecated.summary)

            Use `\(deprecated.replacement)` instead.
            """
        }

        return nil
    }
}
