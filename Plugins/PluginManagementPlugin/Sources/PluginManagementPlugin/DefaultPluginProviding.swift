import Foundation
import SwiftUI

// MARK: - Default Plugin Provider

/// 默认插件管理服务实现
///
/// 负责管理所有插件的注册、启动、查询和排序。
@MainActor
public final class DefaultPluginProviding: PluginProviding {
    private var plugins: [LumiPlugin] = []
    private var pluginOrder: [String] = []
    private var pluginMap: [String: LumiPlugin] = [:]

    public init() {}

    public var allPlugins: [LumiPlugin] {
        pluginOrder.compactMap { pluginMap[$0] }
    }

    public func plugin(id: String) -> LumiPlugin? {
        pluginMap[id]
    }

    public func plugin<T: LumiPlugin>(ofType type: T.Type) -> LumiPlugin? {
        allPlugins.first { $0 is T }
    }

    public func registerPlugin(_ plugin: LumiPlugin) throws {
        if pluginMap[plugin.id] != nil {
            throw LumiKernelError.pluginAlreadyRegistered(id: plugin.id)
        }
        pluginOrder.append(plugin.id)
        pluginMap[plugin.id] = plugin
    }

    public func registerPlugins(_ plugins: [LumiPlugin]) throws {
        for plugin in plugins {
            try registerPlugin(plugin)
        }
    }

    public func bootstrapPlugins(with kernel: LumiKernel) async throws {
        let sortedPlugins = allPlugins.sorted { $0.order < $1.order }
        for plugin in sortedPlugins {
            try await plugin.boot(kernel: kernel)
        }
    }
}
