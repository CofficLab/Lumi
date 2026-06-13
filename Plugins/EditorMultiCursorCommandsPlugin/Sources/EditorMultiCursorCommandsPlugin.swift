import Foundation
import EditorService
import LumiCoreKit

/// 多光标命令编辑器插件：添加多光标编辑的上下文菜单操作
public actor EditorMultiCursorCommandsPlugin: SuperPlugin {
    public nonisolated static let policy: PluginPolicy = .disabled
    public static let shared = EditorMultiCursorCommandsPlugin()
    public static let id = "EditorMultiCursorCommands"
    public static let displayName = LumiPluginLocalization.string("Multi-Cursor Commands", bundle: .module)
    public static let description = LumiPluginLocalization.string("Adds context menu actions for multi-cursor editing (add next occurrence, select all, clear).", bundle: .module)
    public static let iconName = "cursorarrow.and.square.on.square.dashed"
    public static let order = 13
    public static var category: PluginCategory { .editor }

    public nonisolated var providesEditorExtensions: Bool { true }

    @MainActor public func registerEditorExtensions(into registry: any EditorExtensionRegistryProtocol) {
        guard let registry = registry as? EditorExtensionRegistry else { return }
        // TODO: 暂时停用 Editor 右键菜单命令
        // registry.registerCommandContributor(MultiCursorCommandContributor())
    }
}
