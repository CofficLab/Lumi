import Foundation
import EditorService
import LumiCoreKit

/// Markdown 高亮编辑器插件：提供 Markdown 语法高亮
public actor MarkdownEditorPlugin: SuperPlugin {
    public static let shared = MarkdownEditorPlugin()
    public static let id = "MarkdownEditor"
    public static let displayName = "Markdown Highlight"
    public static let description = "Provides Markdown-aware highlight ranges for headings, lists, quotes, links, and code spans."
    public static let iconName = "doc.text"
    public static let order = 120
    public static var category: PluginCategory { .editor }

    public nonisolated var providesEditorExtensions: Bool { true }

    @MainActor public func registerEditorExtensions(into registry: EditorExtensionRegistry) {
        let contributor = MarkdownHighlightContributor()
        registry.registerHighlightProviderContributor(contributor)
    }
}
