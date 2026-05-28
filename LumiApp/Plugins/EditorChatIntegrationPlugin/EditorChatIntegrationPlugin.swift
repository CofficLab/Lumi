import Foundation

/// Editor Chat 集成插件：提供代码发送到 AI chat 的上下文菜单操作
actor EditorChatIntegrationPlugin: SuperPlugin {
    static let shared = EditorChatIntegrationPlugin()
    static let id = "EditorChatIntegration"
    static let displayName = String(localized: "Chat Integration", table: "EditorChatIntegration")
    static let description = String(localized: "Adds context menu actions to send code and locations to the AI chat.", table: "EditorChatIntegration")
    static let iconName = "bubble.left"
    static var category: PluginCategory { .editor }
    static let order = 12

    nonisolated var providesEditorExtensions: Bool { true }

    @MainActor func registerEditorExtensions(into registry: EditorExtensionRegistry) {
         registry.registerCommandContributor(EditorChatIntegrationCommandContributor())
    }
}
