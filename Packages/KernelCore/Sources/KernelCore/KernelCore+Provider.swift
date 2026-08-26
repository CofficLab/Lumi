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

    // MARK: - Resolve

    /// 解析 Provider 实现；未注册时返回 nil。
    ///
    /// 消费方应 `guard let provider = core.resolveProvider(SomeProviding.self) else { return }`
    /// 或使用可选链静默跳过，保证在未提供实现的精简宿主中 no-op。
    public func resolveProvider<T>(_ type: T.Type = T.self) -> T? {
        providers[ObjectIdentifier(type)] as? T
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
