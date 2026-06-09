import Foundation
import EditorService
import LumiCoreKit

/// Swift 原始类型编辑器插件：提供 Swift 原始类型补全建议
public actor EditorSwiftPrimitiveTypesPlugin: SuperPlugin {
    public nonisolated static let policy: PluginPolicy = .disabled
    public static let shared = EditorSwiftPrimitiveTypesPlugin()
    public static let id = "SwiftPrimitiveTypesEditor"
    public static let displayName = String(localized: "Swift Primitive Types", bundle: .module)
    public static let description = String(localized: "Provides Swift primitive type completion suggestions.", bundle: .module)
    public static let iconName = "square.and.pencil"
    public static let order = 10
    public static var category: PluginCategory { .editor }

    public nonisolated var providesEditorExtensions: Bool { true }

    @MainActor public func registerEditorExtensions(into registry: any EditorExtensionRegistryProtocol) {
        guard let registry = registry as? EditorExtensionRegistry else { return }
        registry.registerCompletionContributor(SwiftPrimitiveTypeCompletionContributor())
    }
}
