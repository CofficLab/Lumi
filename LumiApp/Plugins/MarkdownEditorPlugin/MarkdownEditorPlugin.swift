import Foundation

/// Markdown 高亮编辑器插件：提供 Markdown 语法高亮
actor MarkdownEditorPlugin: SuperPlugin {
    static let shared = MarkdownEditorPlugin()
    static let id = "MarkdownEditor"
    static let displayName = "Markdown Highlight"
    static let description = "Provides Markdown-aware highlight ranges for headings, lists, quotes, links, and code spans."
    static let iconName = "doc.text"
    static let order = 120
    static var category: PluginCategory { .editor }

    nonisolated var providesEditorExtensions: Bool { true }

    @MainActor func registerEditorExtensions(into registry: EditorExtensionRegistry) {
        let contributor = MarkdownHighlightContributor()
        registry.registerHighlightProviderContributor(contributor)
    }
}
