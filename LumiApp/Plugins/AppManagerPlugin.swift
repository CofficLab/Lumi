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
    static let iconName = PluginAppManager.AppManagerPlugin.iconName
    static var category: PluginCategory { .system }
    static var order: Int { PluginAppManager.AppManagerPlugin.order }

    nonisolated var instanceLabel: String { Self.id }
    static let shared = AppManagerPlugin()

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
