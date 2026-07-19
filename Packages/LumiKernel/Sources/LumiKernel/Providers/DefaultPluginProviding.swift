import Foundation

// MARK: - Default Plugin Provider

/// 默认插件服务实现
///
/// 负责管理所有插件的注册、启动、查询和排序。
@MainActor
public final class DefaultPluginProviding: PluginProviding {
    public private(set) var allPlugins: [LumiPlugin] = []

    private var plugins: [String: LumiPlugin] = [:]
    private var pluginOrder: [String] = []

    public init() {}

    public func registerPlugin(_ plugin: LumiPlugin) throws {
        if plugins[plugin.id] == nil {
            pluginOrder.append(plugin.id)
        }
        plugins[plugin.id] = plugin
        updateSortedPlugins()
    }

    public func unregisterPlugin(id: String) {
        plugins.removeValue(forKey: id)
        pluginOrder.removeAll { $0 == id }
        updateSortedPlugins()
    }

    public func plugin(id: String) -> LumiPlugin? {
        plugins[id]
    }

    private func updateSortedPlugins() {
        allPlugins = pluginOrder.compactMap { plugins[$0] }
    }
}