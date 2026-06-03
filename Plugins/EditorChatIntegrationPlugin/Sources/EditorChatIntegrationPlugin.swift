import Foundation
import EditorService
import LumiCoreKit

/// Editor Chat 集成插件：提供代码发送到 AI chat 的上下文菜单操作
public actor EditorChatIntegrationPlugin: SuperPlugin {
    public nonisolated static let policy: PluginPolicy = .disabled
    public static let shared = EditorChatIntegrationPlugin()
    public static let id = "EditorChatIntegration"
    public static let displayName = String(localized: "Chat Integration", table: "EditorChatIntegration")
    public static let description = String(localized: "Adds context menu actions to send code and locations to the AI chat.", table: "EditorChatIntegration")
    public static let iconName = "bubble.left"
    public static var category: PluginCategory { .editor }
    public static let order = 12

    public nonisolated var providesEditorExtensions: Bool { true }

    @MainActor public func registerEditorExtensions(into registry: any EditorExtensionRegistryProtocol) {
        guard let registry = registry as? EditorExtensionRegistry else { return }
        registry.registerCommandContributor(EditorChatIntegrationCommandContributor())
    }
}
