import Foundation

/// LSP 上下文命令编辑器插件：添加跳转到定义和重命名等命令
actor LSPContextCommandsEditorPlugin: SuperPlugin {
    static let id = "LSPContextCommandsEditor"
    static let displayName = String(localized: "LSP Context Commands", table: "LSPContextCommandsEditor")
    static let description = String(localized: "Adds LSP context commands like go to definition and rename.", table: "LSPContextCommandsEditor")
    static let iconName = "command"
    static let order = 15
    static let enable = true
    static var isConfigurable: Bool { true }

    nonisolated var providesEditorExtensions: Bool { true }

    @MainActor func registerEditorExtensions(into registry: EditorExtensionRegistry) {
        registry.registerCommandContributor(LSPContextCommandContributor())
    }
}
