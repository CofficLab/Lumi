import MagicKit
import SwiftUI

/// 编辑器插件状态栏入口：在状态栏右侧显示已加载编辑器插件数量与详情
actor EditorLoadedPluginsPlugin: SuperPlugin, SuperLog {
    nonisolated static let emoji = "🧩"
    nonisolated static let enable: Bool = true
    nonisolated static let verbose: Bool = false

    static let id: String = "EditorLoadedPlugins"
    static let displayName: String = String(
        localized: "Editor Plugins", table: "EditorLoadedPlugins")
    static let description: String = String(
        localized: "Show loaded editor plugins in status bar", table: "EditorLoadedPlugins")
    static let iconName: String = "puzzlepiece.extension"
    static var isConfigurable: Bool { false }
    static var order: Int { 79 }

    nonisolated var instanceLabel: String { Self.id }
    static let shared = EditorLoadedPluginsPlugin()

    // MARK: - UI Contributions

    /// 在状态栏右侧显示已加载插件入口
    ///
    /// 仅在 EditorPlugin 被激活时提供。
    @MainActor func addStatusBarTrailingView(activeIcon: String?) -> AnyView? {
        guard activeIcon == EditorPlugin.iconName else { return nil }
        return AnyView(EditorLoadedPluginsStatusBarView())
    }
}
