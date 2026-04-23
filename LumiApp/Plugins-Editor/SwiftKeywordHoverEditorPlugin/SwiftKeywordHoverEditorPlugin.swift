import Foundation

@objc(LumiSwiftKeywordHoverEditorPlugin)
@MainActor
final class SwiftKeywordHoverEditorPlugin: NSObject, EditorFeaturePlugin {
    let id: String = "builtin.swift.keyword-hover"
    let displayName: String = String(localized: "Swift Keyword Hover", table: "SwiftKeywordHoverEditor")
    override var description: String { String(localized: "Shows inline hover documentation for common Swift keywords.", table: "SwiftKeywordHoverEditor") }
    let order: Int = 20

    func register(into registry: EditorExtensionRegistry) {
        registry.registerHoverContributor(SwiftKeywordHoverContributor())
    }
}
