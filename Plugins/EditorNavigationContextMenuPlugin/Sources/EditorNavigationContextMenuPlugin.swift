import Foundation
import EditorService
import LumiCoreKit
import SwiftUI
import os

/// 编辑器导航右键菜单插件：为编辑器右键菜单提供跳转到定义等导航命令。
///
/// 通过实现 `SuperEditorCommandContributor` 协议，
/// 将「跳转到定义」「跳转到声明」「跳转到类型定义」「查找所有引用」「Peek Definition」
/// 等导航命令注册到 `EditorExtensionRegistry`，
/// 由 `ContextMenuCoordinator` 自动注入到编辑器的右键菜单中。
public enum EditorNavigationContextMenuPlugin: LumiPlugin {
    public static let policy: LumiPluginPolicy = .alwaysOn
    public static let stage: LumiPluginStage = .beta
    public static let category: LumiPluginCategory = .development
    public static let iconName = "arrow.turn.down.left"

    public static let logger = Logger(
        subsystem: "com.coffic.lumi",
        category: "plugin.editor-navigation-context-menu"
    )

    public static let info = LumiPluginInfo(
        id: "EditorNavigationContextMenu",
        displayName: LumiPluginLocalization.string("Editor Navigation Context Menu", bundle: .module),
        description: LumiPluginLocalization.string(
            "Adds navigation commands (Go to Definition, Go to Declaration, Go to Type Definition, Find All References, Peek Definition) to the editor right-click menu.",
            bundle: .module
        ),
        order: 15
    )

    public static func registerEditorExtensions(into registry: AnyObject) async {
        guard let registry = registry as? EditorExtensionRegistry else { return }
        registry.registerCommandContributor(NavigationContextMenuCommandContributor())
    }
}