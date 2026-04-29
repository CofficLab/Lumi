import Foundation

@objc(LumiCSSEditorPlugin)
@MainActor
final class CSSEditorPlugin: NSObject, EditorFeaturePlugin {
    let id = "builtin.css.language-tools"
    let displayName = "CSS Language Tools"
    override var description: String {
        "Provides CSS-family completions and hover help for common properties and values."
    }
    let order = 32

    func register(into registry: EditorExtensionRegistry) {
        registry.registerCompletionContributor(CSSCompletionContributor())
        registry.registerHoverContributor(CSSHoverContributor())
    }
}
