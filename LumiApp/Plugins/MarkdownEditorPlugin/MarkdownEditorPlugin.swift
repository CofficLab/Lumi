import Foundation

/// Markdown 高亮编辑器插件：提供 Markdown 语法高亮
actor MarkdownEditorPlugin: SuperPlugin {
    static let id = "MarkdownEditor"
    static let displayName = "Markdown Highlight"
    static let description = "Provides Markdown-aware highlight ranges for headings, lists, quotes, links, and code spans."
    static let iconName = "doc.text"
    static let order = 120
    static let enable = true
    static var isConfigurable: Bool { true }

    nonisolated var providesEditorExtensions: Bool { true }

    private let contributor = MarkdownHighlightContributor()

    @MainActor func registerEditorExtensions(into registry: EditorExtensionRegistry) {
        registry.registerHighlightProviderContributor(contributor)
    }
}
