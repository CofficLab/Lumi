import Foundation

@objc(LumiMarkdownEditorPlugin)
@MainActor
final class MarkdownEditorPlugin: NSObject, EditorFeaturePlugin {
    let id = "builtin.markdown.highlight"
    let displayName = "Markdown Highlight"
    override var description: String {
        "Provides Markdown-aware highlight ranges for headings, lists, quotes, links, and code spans."
    }
    let order = 120

    private let contributor = MarkdownHighlightContributor()

    func register(into registry: EditorExtensionRegistry) {
        registry.registerHighlightProviderContributor(contributor)
    }
}
