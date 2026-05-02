import MagicKit
import SwiftUI

/// App 插件状态栏入口：在状态栏右侧显示已加载 App 插件数量与详情
actor AppLoadedPluginsPlugin: SuperPlugin, SuperLog {
    nonisolated static let emoji = "🧩"
    nonisolated static let enable: Bool = true
    nonisolated static let verbose: Bool = false

    static let id: String = "AppLoadedPlugins"
    static let displayName: String = String(
        localized: "App Plugins", table: "AppLoadedPlugins")
    static let description: String = String(
        localized: "Show loaded app plugins in status bar", table: "AppLoadedPlugins")
    static let iconName: String = "puzzlepiece.extension"
    static var isConfigurable: Bool { false }
    static var order: Int { 79 }

    nonisolated var instanceLabel: String { Self.id }
    static let shared = AppLoadedPluginsPlugin()

    // MARK: - UI Contributions

    /// 在状态栏右侧显示已加载插件入口
    @MainActor func addStatusBarTrailingView(activeIcon: String?) -> AnyView? {
        return AnyView(AppLoadedPluginsStatusBarView())
    }
}
