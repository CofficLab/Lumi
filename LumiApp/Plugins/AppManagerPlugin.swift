import AgentToolKit
import PluginAppManager
import SwiftUI
import os

/// 应用管理插件 App 侧注册适配器。
actor AppManagerPlugin: SuperPlugin, SuperLog {
    /// 插件专用 Logger
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.app-manager")

    // MARK: - Plugin Properties

    nonisolated static let emoji = "📱"
    nonisolated static let verbose: Bool = PluginAppManager.AppManagerPlugin.verbose

    static let id = PluginAppManager.AppManagerPlugin.id
    static let navigationId = PluginAppManager.AppManagerPlugin.navigationId
    static let displayName = PluginAppManager.AppManagerPlugin.displayName
    static let description = PluginAppManager.AppManagerPlugin.description

    static func description(for language: LanguagePreference) -> String {
        PluginAppManager.AppManagerPlugin.description(for: language)
    }
    static let iconName = PluginAppManager.AppManagerPlugin.iconName
    static var category: PluginCategory { .system }
    static var order: Int { PluginAppManager.AppManagerPlugin.order }
    nonisolated static let policy: PluginPolicy = .optIn

    nonisolated var instanceLabel: String { Self.id }
    static let shared = AppManagerPlugin()

    @MainActor
    func addPosterViews() -> [AnyView] {
        [
            PluginPosterSupport.poster(
                title: "应用与残留文件",
                subtitle: "扫描已安装应用，查看缓存、偏好设置和相关文件。",
                icon: Self.iconName,
                accent: .indigo,
                metrics: [
                    PluginPosterSupport.metric("Apps", "应用列表"),
                    PluginPosterSupport.metric("Clean", "残留清理"),
                ],
                rows: ["应用详情", "缓存统计", "关联文件"],
                chips: ["系统", "应用管理", "清理"]
            ),
            PluginPosterSupport.poster(
                title: "卸载前先看清",
                subtitle: "把应用相关文件集中呈现，减少手动翻找。",
                icon: "trash.slash",
                accent: .purple,
                rows: ["Application Support", "Caches", "Preferences"],
                chips: ["扫描", "分组", "预览"]
            ),
        ]
    }

    nonisolated func onRegister() {
        PluginAppManager.AppManagerPlugin.databaseRootURLProvider = {
            AppConfig.getDBFolderURL()
        }
    }

    // MARK: - UI Contributions

    @MainActor
    func addViewContainer() -> ViewContainerItem? {
        guard let item = PluginAppManager.AppManagerPlugin.shared.addViewContainer() else {
            return nil
        }
        return ViewContainerItem(id: item.id, title: item.title, icon: item.icon, makeView: item.makeView)
    }
}
