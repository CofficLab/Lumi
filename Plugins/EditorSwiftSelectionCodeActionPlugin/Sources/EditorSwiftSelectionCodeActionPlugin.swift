import Foundation
import EditorService
import LumiCoreKit

/// Swift 选区代码动作编辑器插件：提供基于选区的 Swift 代码动作
public actor EditorSwiftSelectionCodeActionPlugin: SuperPlugin {
    public nonisolated static let policy: PluginPolicy = .disabled
    public static let shared = EditorSwiftSelectionCodeActionPlugin()
    public static let id = "SwiftSelectionCodeActionEditor"
    public static let displayName = LumiPluginLocalization.string("Swift Selection Code Actions", bundle: .module)
    public static let description = LumiPluginLocalization.string("Provides selection-based Swift code actions.", bundle: .module)
    public static let iconName = "cursorarrow.click.badge.clock"
    public static let order = 30
    public static var category: PluginCategory { .editor }

    public nonisolated var providesEditorExtensions: Bool { true }

    @MainActor public func registerEditorExtensions(into registry: any EditorExtensionRegistryProtocol) {
        guard let registry = registry as? EditorExtensionRegistry else { return }
        registry.registerCodeActionContributor(SwiftSelectionCodeActionContributor())
    }
}
