import Foundation
import EditorService
import LumiCoreKit
import SwiftUI

/// Markdown 高亮编辑器插件：提供 Markdown 语法高亮
public enum EditorMarkdownPlugin: LumiPlugin {
    public static let policy: LumiPluginPolicy = .disabled
    public static let stage: LumiPluginStage = .beta
    public static let category: LumiPluginCategory = .development
    public static let iconName = "doc.text"

    public static let info = LumiPluginInfo(
        id: "MarkdownEditor",
        displayName: LumiPluginLocalization.string("Markdown Highlight", bundle: .module),
        description: LumiPluginLocalization.string("Provides Markdown-aware highlight ranges for headings, lists, quotes, links, and code spans.", bundle: .module),
        order: 120
    )

    public static func registerEditorExtensions(into registry: AnyObject) async {
        guard let registry = registry as? EditorExtensionRegistry else { return }
        registry.registerLanguage(EditorMarkdownPluginDescriptor.markdown)
        registry.registerLanguage(EditorMarkdownPluginDescriptor.markdownInline)
        registry.registerGrammarProvider(EditorMarkdownGrammarProvider())
        registry.registerGrammarProvider(EditorMarkdownInlineGrammarProvider())

        let contributor = MarkdownHighlightContributor()
        registry.registerHighlightProviderContributor(contributor)
    }
}
