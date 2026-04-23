import Foundation

@objc(LumiSwiftSelectionCodeActionEditorPlugin)
@MainActor
final class SwiftSelectionCodeActionEditorPlugin: NSObject, EditorFeaturePlugin {
    let id: String = "builtin.swift.selection-actions"
    let displayName: String = String(localized: "Swift Selection Code Actions", table: "SwiftSelectionCodeActionEditor")
    override var description: String { String(localized: "Provides selection-based Swift code actions.", table: "SwiftSelectionCodeActionEditor") }
    let order: Int = 30

    func register(into registry: EditorExtensionRegistry) {
        registry.registerCodeActionContributor(SwiftSelectionCodeActionContributor())
    }
}
