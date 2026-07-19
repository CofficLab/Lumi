import Foundation
import LumiKernel

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

    public func registerPlugins(_ plugins: [LumiPlugin]) throws {
        for plugin in plugins {
            try registerPlugin(plugin)
        }
    }

    public func bootstrapPlugins() async throws {
        for plugin in allPlugins {
            try await plugin.boot(kernel: LumiKernel())
        }
    }

    public func plugin(id: String) -> LumiPlugin? {
        plugins[id]
    }

    public func plugin<T: LumiPlugin>(ofType type: T.Type) -> T? {
        allPlugins.first(where: { $0 is T }) as? T
    }

    private func updateSortedPlugins() {
        allPlugins = pluginOrder.compactMap { plugins[$0] }
    }
}