import Foundation

// MARK: - Plugin Registry

/// 插件注册 / 解析相关函数。
///
/// 插件（SuperPlugin）按 `id` 注入内核（与 Provider 按类型注入互补）：
/// - `registerPlugin`：注入插件
/// - `resolvePlugin` / `isPluginRegistered`：访问与查询
/// - `unregisterPlugin`：注销
extension KernelCoreContainer {

    // MARK: - Register

    /// 注入插件（按 `id` 注册）。
    ///
    /// - Throws: `KernelCoreError.pluginAlreadyRegistered` — 同 id 重复注入时。
    public func registerPlugin(_ plugin: any SuperPlugin) throws {
        let key = plugin.id
        guard plugins[key] == nil else {
            throw KernelCoreError.pluginAlreadyRegistered(id: key)
        }
        plugins[key] = plugin
    }

    // MARK: - Start

    /// 注入一批插件并启动（按 `order` 升序执行各插件的 `onBoot`）。
    ///
    /// 插件的 `onBoot` 会通过 kernel 注册自己的 Provider / 贡献，因此
    /// 启动顺序（order）决定插件间依赖的可用性。
    ///
    /// - Parameter plugins: 待注入并启动的插件。
    /// - Throws: `KernelCoreError.pluginAlreadyRegistered` — 同 id 重复注入时；
    ///           或插件 `onBoot` 抛出的错误。
    public func start(plugins: [any SuperPlugin]) throws {
        let sorted = plugins.sorted { $0.order < $1.order }
        for plugin in sorted {
            try registerPlugin(plugin)
            try plugin.onBoot(kernel: self)
        }
    }

    // MARK: - Resolve

    /// 按 `id` 解析插件；未注入时返回 nil。
    public func resolvePlugin(id: String) -> (any SuperPlugin)? {
        plugins[id]
    }

    /// 指定 `id` 的插件是否已注入。
    public func isPluginRegistered(id: String) -> Bool {
        plugins[id] != nil
    }

    /// 当前已注入的插件数量（诊断用）。
    public var registeredPluginCount: Int {
        plugins.count
    }

    /// 全部已注入的插件。
    public var allPlugins: [any SuperPlugin] {
        Array(plugins.values)
    }

    // MARK: - Unregister

    /// 注销插件。
    public func unregisterPlugin(id: String) {
        plugins.removeValue(forKey: id)
    }
}
