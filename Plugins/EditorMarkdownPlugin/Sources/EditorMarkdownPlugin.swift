import Foundation
import EditorService
import LumiCoreKit

/// Markdown 高亮编辑器插件：提供 Markdown 语法高亮
public actor EditorMarkdownPlugin: SuperPlugin {
    public nonisolated static let policy: PluginPolicy = .disabled
    public static let shared = EditorMarkdownPlugin()
    public static let id = "MarkdownEditor"
    public static let displayName = LumiPluginLocalization.string("Markdown Highlight", bundle: .module)
    public static let description = LumiPluginLocalization.string("Provides Markdown-aware highlight ranges for headings, lists, quotes, links, and code spans.", bundle: .module)
    public static let iconName = "doc.text"
    public static let order = 120
    public static var category: PluginCategory { .editor }

    public nonisolated var providesEditorExtensions: Bool { true }

    @MainActor public func registerEditorExtensions(into registry: any EditorExtensionRegistryProtocol) {
        guard let registry = registry as? EditorExtensionRegistry else { return }
        let contributor = MarkdownHighlightContributor()
        registry.registerHighlightProviderContributor(contributor)
    }
}
