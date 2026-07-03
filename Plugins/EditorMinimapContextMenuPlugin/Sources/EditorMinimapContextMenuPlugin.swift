import Foundation
import EditorService
import LumiCoreKit
import SwiftUI

/// 编辑器 Minimap 右键菜单插件：提供隐藏/显示小地图的上下文菜单项。
public enum EditorMinimapContextMenuPlugin: LumiPlugin {
    public static let policy: LumiPluginPolicy = .alwaysOn
    public static let stage: LumiPluginStage = .beta
    public static let category: LumiPluginCategory = .development
    public static let iconName = "map"

    public static let info = LumiPluginInfo(
        id: "EditorMinimapContextMenu",
        displayName: LumiPluginLocalization.string("Minimap Context Menu", bundle: .module),
        description: LumiPluginLocalization.string(
            "Adds a context menu action to show or hide the editor minimap.",
            bundle: .module
        ),
        order: 14
    )

    public static func registerEditorExtensions(into registry: AnyObject) async {
        guard let registry = registry as? EditorExtensionRegistry else { return }
        registry.registerCommandContributor(MinimapContextMenuCommandContributor())
    }
}
