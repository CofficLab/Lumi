import Foundation

/// Chat 集成编辑器插件：提供代码发送到 AI chat 的上下文菜单操作
actor ChatIntegrationEditorPlugin: SuperPlugin {
    static let id = "ChatIntegrationEditor"
    static let displayName = String(localized: "Chat Integration", table: "ChatIntegrationEditor")
    static let description = String(localized: "Adds context menu actions to send code and locations to the AI chat.", table: "ChatIntegrationEditor")
    static let iconName = "bubble.left"
    static let order = 12
    static let enable = true
    static var isConfigurable: Bool { true }

    nonisolated var providesEditorExtensions: Bool { true }

    @MainActor func registerEditorExtensions(into registry: EditorExtensionRegistry) {
        registry.registerCommandContributor(ChatIntegrationCommandContributor())
    }
}
