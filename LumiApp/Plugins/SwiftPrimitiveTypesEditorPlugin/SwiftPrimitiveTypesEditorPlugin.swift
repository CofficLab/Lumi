import Foundation

/// Swift 原始类型编辑器插件：提供 Swift 原始类型补全建议
actor SwiftPrimitiveTypesEditorPlugin: SuperPlugin {
    static let id = "SwiftPrimitiveTypesEditor"
    static let displayName = String(localized: "Swift Primitive Types", table: "SwiftPrimitiveTypesEditor")
    static let description = String(localized: "Provides Swift primitive type completion suggestions.", table: "SwiftPrimitiveTypesEditor")
    static let iconName = "square.and.pencil"
    static let order = 10
    static let enable = true
    static var isConfigurable: Bool { false }

    nonisolated var providesEditorExtensions: Bool { true }

    @MainActor func registerEditorExtensions(into registry: EditorExtensionRegistry) {
        registry.registerCompletionContributor(SwiftPrimitiveTypeCompletionContributor())
    }
}
