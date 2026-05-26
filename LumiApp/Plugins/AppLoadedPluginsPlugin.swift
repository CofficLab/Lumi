import PluginAppLoadedPlugins
import LumiCoreKit
import SwiftUI

/// App 插件状态栏入口：在状态栏右侧显示已加载 App 插件数量与详情
actor AppLoadedPluginsPlugin: SuperPlugin, SuperLog {
    nonisolated static let emoji = "🧩"
    static var category: PluginCategory { .general }
    nonisolated static let enable: Bool = PluginAppLoadedPlugins.AppLoadedPluginsPlugin.enable
    nonisolated static let verbose: Bool = PluginAppLoadedPlugins.AppLoadedPluginsPlugin.verbose

    static let id: String = PluginAppLoadedPlugins.AppLoadedPluginsPlugin.id
    static let displayName: String = PluginAppLoadedPlugins.AppLoadedPluginsPlugin.displayName
    static let description: String = PluginAppLoadedPlugins.AppLoadedPluginsPlugin.description
    static let iconName: String = PluginAppLoadedPlugins.AppLoadedPluginsPlugin.iconName
    static var isConfigurable: Bool { PluginAppLoadedPlugins.AppLoadedPluginsPlugin.isConfigurable }
    static var order: Int { PluginAppLoadedPlugins.AppLoadedPluginsPlugin.order }

    nonisolated var instanceLabel: String { Self.id }
    static let shared = AppLoadedPluginsPlugin()

    nonisolated func onRegister() {
        PluginAppLoadedPlugins.AppLoadedPluginsPlugin.pluginProvider = {
            AppPluginVM.shared.plugins.map { plugin in
                let pluginType = type(of: plugin)
                return LoadedPluginInfo(
                    id: pluginType.id,
                    displayName: pluginType.displayName,
                    description: pluginType.description,
                    order: pluginType.order
                )
            }
        }
    }

    // MARK: - UI Contributions

    /// 在状态栏右侧显示已加载插件入口
    @MainActor func addStatusBarTrailingView(context: PluginContext) -> AnyView? {
        PluginAppLoadedPlugins.AppLoadedPluginsPlugin.shared.addStatusBarTrailingView(context: context)
    }
}
