import Foundation
import EditorService
import LumiCoreKit

/// 编辑器 Minimap 右键菜单插件：提供隐藏/显示小地图的上下文菜单项。
public actor EditorMinimapContextMenuPlugin: SuperPlugin {
    public nonisolated static let policy: PluginPolicy = .alwaysOn
    public static let shared = EditorMinimapContextMenuPlugin()
    public static let id = "EditorMinimapContextMenu"
    public static let displayName = LumiPluginLocalization.string("Minimap Context Menu", bundle: .module)
    public static let description = LumiPluginLocalization.string(
        "Adds a context menu action to show or hide the editor minimap.",
        bundle: .module
    )
    public static let iconName = "map"
    public static let order = 14
    public static var category: PluginCategory { .editor }

    public nonisolated var providesEditorExtensions: Bool { true }

    @MainActor
    public func registerEditorExtensions(into registry: any EditorExtensionRegistryProtocol) {
        guard let registry = registry as? EditorExtensionRegistry else { return }
        registry.registerCommandContributor(MinimapContextMenuCommandContributor())
    }
}
