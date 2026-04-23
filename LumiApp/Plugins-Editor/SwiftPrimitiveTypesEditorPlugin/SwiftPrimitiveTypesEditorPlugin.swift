import Foundation

@objc(LumiSwiftPrimitiveTypesEditorPlugin)
@MainActor
final class SwiftPrimitiveTypesEditorPlugin: NSObject, EditorFeaturePlugin {
    let id: String = "builtin.swift.primitive-types"
    let displayName: String = "Swift Primitive Types"
    let order: Int = 10

    func register(into registry: EditorExtensionRegistry) {
        registry.registerCompletionContributor(SwiftPrimitiveTypeCompletionContributor())
    }
}
