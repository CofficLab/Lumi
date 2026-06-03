import Foundation
import EditorService
import LumiCoreKit

/// Swift 选区代码动作编辑器插件：提供基于选区的 Swift 代码动作
public actor SwiftSelectionCodeActionEditorPlugin: SuperPlugin {
    public nonisolated static let policy: PluginPolicy = .disabled
    public static let shared = SwiftSelectionCodeActionEditorPlugin()
    public static let id = "SwiftSelectionCodeActionEditor"
    public static let displayName = String(localized: "Swift Selection Code Actions", table: "SwiftSelectionCodeActionEditor")
    public static let description = String(localized: "Provides selection-based Swift code actions.", table: "SwiftSelectionCodeActionEditor")
    public static let iconName = "cursorarrow.click.badge.clock"
    public static let order = 30
    public static var category: PluginCategory { .editor }

    public nonisolated var providesEditorExtensions: Bool { true }

    @MainActor public func registerEditorExtensions(into registry: any EditorExtensionRegistryProtocol) {
        guard let registry = registry as? EditorExtensionRegistry else { return }
        registry.registerCodeActionContributor(SwiftSelectionCodeActionContributor())
    }
}
