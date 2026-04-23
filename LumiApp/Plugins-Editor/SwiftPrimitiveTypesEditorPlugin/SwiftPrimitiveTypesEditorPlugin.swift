import Foundation

@objc(LumiSwiftPrimitiveTypesEditorPlugin)
@MainActor
final class SwiftPrimitiveTypesEditorPlugin: NSObject, EditorFeaturePlugin {
    let id: String = "builtin.swift.primitive-types"
    let displayName: String = String(localized: "Swift Primitive Types", table: "SwiftPrimitiveTypesEditor")
    override var description: String { String(localized: "Provides Swift primitive type completion suggestions.", table: "SwiftPrimitiveTypesEditor") }
    let order: Int = 10

    func register(into registry: EditorExtensionRegistry) {
        registry.registerCompletionContributor(SwiftPrimitiveTypeCompletionContributor())
    }
}
