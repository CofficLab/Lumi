import Combine
import Foundation

/// KernelCore 轻量级内核核心
///
/// 架构原则：KernelCore 只提供「注册 Provider 与访问 Provider」的通用机制，
/// **不定义、不包含任何具体 Provider**（如 StorageProviding、ProjectProviding 等）。
/// 具体 Provider 协议由上层（如 KernelLumi）或具体 App 声明，实现由插件注入。
///
/// 对应 KernelLumi 中 Generic Service Registry 的机制，抽出为可复用的最小核心：
/// - `registerProvider`：按协议类型注册实现
/// - `resolveProvider`：按协议类型解析实现
/// - `unregisterProvider` / `isProviderRegistered`：生命周期与查询
///
/// Only holds protocol types, does not depend on concrete implementations.
/// All concrete implementations are injected via plugins.
@MainActor
public final class KernelCoreContainer: ObservableObject {

    // MARK: - Provider Registry

    /// Provider 注册表：以协议类型的 `ObjectIdentifier` 为 key。
    private var providers: [ObjectIdentifier: Any] = [:]

    /// Provider 变更订阅：仅当注册时选择转发 `objectWillChange` 时使用。
    private var providerSubscriptions: [ObjectIdentifier: AnyCancellable] = [:]

    // MARK: - Initialization

    public init() {}

    // MARK: - Register

    /// 注册 Provider 实现。
    ///
    /// 默认把 Provider 的 `objectWillChange` 转发到容器，使订阅容器的视图能感知
    /// Provider 状态变化（与 KernelLumi 的行为一致）。
    ///
    /// - Throws: `KernelCoreError.providerAlreadyRegistered` — 同类型重复注册时。
    public func registerProvider<T>(_ type: T.Type, _ provider: T) throws {
        try registerProvider(type, provider, forwardsObjectWillChange: true)
    }

    /// 注册 Provider 实现，可选择是否把其 `objectWillChange` 转发到容器。
    ///
    /// 高频变更的 Provider（如流式输出 store：每个 token 都触发 objectWillChange）
    /// 应传 `forwardsObjectWillChange: false`——否则容器会把高频更新广播给所有
    /// 订阅方，导致整个 app 跟着重渲染。此类 Provider 改由消费方直接窄播订阅。
    ///
    /// - Throws: `KernelCoreError.providerAlreadyRegistered` — 同类型重复注册时。
    public func registerProvider<T>(
        _ type: T.Type,
        _ provider: T,
        forwardsObjectWillChange: Bool
    ) throws {
        let key = ObjectIdentifier(type)
        guard providers[key] == nil else {
            throw KernelCoreError.providerAlreadyRegistered(type: type)
        }
        providers[key] = provider

        if forwardsObjectWillChange {
            subscribeToObjectWillChange(provider: provider, key: key)
        }
    }

    /// 订阅 `ObservableObject` 的 `objectWillChange` 并转发到容器。
    private func subscribeToObjectWillChange<T>(provider: T, key: ObjectIdentifier) {
        guard let observableObject = provider as? any ObservableObject else { return }

        // Force cast to ObservableObjectPublisher which is the concrete type
        let publisher = observableObject.objectWillChange as! ObservableObjectPublisher
        providerSubscriptions[key] = publisher
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                guard let self else { return }
                self.objectWillChange.send()
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

    /// 注销 Provider 实现，并释放其变更订阅。
    public func unregisterProvider<T>(_ type: T.Type) {
        let key = ObjectIdentifier(type)
        providers.removeValue(forKey: key)
        providerSubscriptions.removeValue(forKey: key)
    }
}

/// 兼容命名：用 `KernelCore` 实例化时，使用 `KernelCoreContainer`。
public typealias KernelCore = KernelCoreContainer
