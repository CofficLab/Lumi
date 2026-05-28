import Foundation

/// 多光标命令编辑器插件：添加多光标编辑的上下文菜单操作
actor MultiCursorCommandsEditorPlugin: SuperPlugin {
    static let shared = MultiCursorCommandsEditorPlugin()
    static let id = "MultiCursorCommandsEditor"
    static let displayName = String(localized: "Multi-Cursor Commands", table: "MultiCursorCommandsEditor")
    static let description = String(localized: "Adds context menu actions for multi-cursor editing (add next occurrence, select all, clear).", table: "MultiCursorCommandsEditor")
    static let iconName = "cursorarrow.and.square.on.square.dashed"
    static let order = 13
    static var category: PluginCategory { .editor }

    nonisolated var providesEditorExtensions: Bool { true }

    @MainActor func registerEditorExtensions(into registry: EditorExtensionRegistry) {
        // TODO: 暂时停用 Editor 右键菜单命令
        // registry.registerCommandContributor(MultiCursorCommandContributor())
    }
}
