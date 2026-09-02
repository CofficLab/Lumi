import Foundation

// MARK: - Provider Registry

/// Provider 注册 / 解析相关函数。
///
/// 对应 KernelLumi 中 Generic Service Registry 的机制：
/// - `registerProvider`：按协议类型注册实现
/// - `resolveProvider`：按协议类型解析实现
/// - `unregisterProvider` / `isProviderRegistered`：生命周期与查询
extension KernelCoreContainer {

    // MARK: - Register

    /// 注册 Provider 实现。
    ///
    /// Kernel 只维护注册表，不发布 Provider 状态变化。需要响应变化的消费者
    /// 必须直接观察具体 Provider 的精准观察接口或 `objectWillChange`。
    public func registerProvider<T>(_ type: T.Type, _ provider: T) throws {
        let key = ObjectIdentifier(type)
        guard providers[key] == nil else {
            throw KernelCoreError.providerAlreadyRegistered(type: type)
        }
        providers[key] = provider
        if let activePluginID {
            providerOwners[key] = activePluginID
        }
    }

    /// 注册由宿主生命周期持有的 Provider。
    ///
    /// 适用于插件替换默认基础设施 Provider 的场景：插件负责组装实现，
    /// 但 Provider 本身应在 `kernel.stop()` 后继续存在，以便同一个 Kernel
    /// 可以再次启动插件并重新接收贡献。插件级贡献仍由 Kernel 按插件归属撤回。
    public func registerHostProvider<T>(_ type: T.Type, _ provider: T) throws {
        let key = ObjectIdentifier(type)
        guard providers[key] == nil else {
            throw KernelCoreError.providerAlreadyRegistered(type: type)
        }
        providers[key] = provider
        providerOwners.removeValue(forKey: key)
    }

    // MARK: - Resolve

    /// 解析 Provider 实现；未注册时返回 nil。
    ///
    /// 在插件 `onBoot` 阶段解析不到 Provider 时，Kernel 会输出包含插件 ID
    /// 和 Provider 类型的 error 日志；返回值仍为 nil，由消费方决定是否降级。
    public func resolveProvider<T>(_ type: T.Type = T.self) -> T? {
        guard let provider = providers[ObjectIdentifier(type)] as? T else {
            if let pluginID = activePluginID, activePluginLifecyclePhase == .boot {
                Self.logger.error(
                    "Plugin '\(pluginID, privacy: .public)' could not resolve provider '\(String(reflecting: type), privacy: .public)' during onBoot"
                )
            }
            return nil
        }
        return provider
    }

    /// 指定 Provider 类型是否已注册（装配前的依赖校验用）。
    public func isProviderRegistered<T>(_ type: T.Type) -> Bool {
        providers[ObjectIdentifier(type)] != nil
    }

    /// 当前已注册的 Provider 数量（诊断用）。
    public var registeredProviderCount: Int {
        providers.count
    }

    // MARK: - Unregister

    /// 注销 Provider 实现。
    public func unregisterProvider<T>(_ type: T.Type) {
        let key = ObjectIdentifier(type)
        providers.removeValue(forKey: key)
        providerOwners.removeValue(forKey: key)
    }

    /// 当前 Provider 是否由指定插件注册（诊断与生命周期测试用）。
    public func isProvider<T>(_ type: T.Type, ownedByPlugin id: String) -> Bool {
        providerOwners[ObjectIdentifier(type)] == id
    }
}
