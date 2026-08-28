import Combine
import Foundation
import KernelCore
import ProviderPluginControl

/// 默认 `PluginManaging` 实现：直接驱动 `KernelCoreContainer` 插件注册表。
///
/// 启停控制委托给 `PluginControlling`（默认 `DefaultPluginControlling`），
/// 枚举 / 查询 / 卸载 / 重载直接读写内核注册表，保证与真实生命周期一致。
///
/// 观察者机制：通过 `addPluginObserver` 注册的回调会在插件列表或启用状态
/// 发生变化时被调用；令牌释放（deinit）或调用 `cancel()` 后自动停止接收。
@MainActor
public final class DefaultPluginManager: PluginManaging {
    private weak var kernel: KernelCoreContainer?
    private let controlling: any PluginControlling

    public init(
        kernel: KernelCoreContainer? = nil,
        controlling: (any PluginControlling)? = nil
    ) {
        self.kernel = kernel
        self.controlling = controlling ?? DefaultPluginControlling(kernel: kernel)
    }

    public func attach(kernel: KernelCoreContainer) {
        self.kernel = kernel
    }

    // MARK: - PluginControlling（委托）

    public var lastErrorDescription: String? { controlling.lastErrorDescription }

    public func enablePlugin(id: String) async -> Bool {
        let result = await controlling.enablePlugin(id: id)
        if result {
            notifyObservers(.enabledStateChanged(pluginID: id, enabled: true))
        }
        return result
    }

    public func disablePlugin(id: String) async -> Bool {
        let result = await controlling.disablePlugin(id: id)
        if result {
            notifyObservers(.enabledStateChanged(pluginID: id, enabled: false))
        }
        return result
    }

    public func isEnabled(id: String) -> Bool {
        controlling.isEnabled(id: id)
    }

    // MARK: - PluginManaging（内核注册表直读）

    public var allPlugins: [any SuperPlugin] { kernel?.allPlugins ?? [] }

    public var configurablePlugins: [any SuperPlugin] {
        allPlugins.filter { $0.metadata.policy.isConfigurable }
    }

    public var pluginCount: Int { kernel?.registeredPluginCount ?? 0 }

    public var enabledCount: Int {
        allPlugins.reduce(0) { $0 + (kernel?.isPluginEnabled(id: $1.id) == true ? 1 : 0) }
    }

    public func plugin(id: String) -> (any SuperPlugin)? {
        kernel?.resolvePlugin(id: id)
    }

    public func isRegistered(id: String) -> Bool {
        kernel?.isPluginRegistered(id: id) ?? false
    }

    public func unloadPlugin(id: String) throws {
        guard let kernel else { throw PluginManagingError.kernelNotAttached }
        try kernel.unloadPlugin(id: id)
        notifyObservers(.listChanged)
    }

    public func reloadPlugin(id: String) throws {
        guard let kernel else { throw PluginManagingError.kernelNotAttached }
        guard let plugin = kernel.resolvePlugin(id: id) else {
            throw PluginManagingError.pluginNotFound(id: id)
        }
        try kernel.unloadPlugin(id: id)
        do {
            try kernel.start(plugins: [plugin])
        } catch {
            throw PluginManagingError.lifecycle(error.localizedDescription)
        }
        notifyObservers(.listChanged)
    }

    // MARK: - Plugin Filtering

    public func enabledPlugins(from candidates: [any SuperPlugin]) -> [any SuperPlugin] {
        candidates.filter { plugin in
            // 不可配置的插件（required / alwaysOn）始终保留。
            guard plugin.metadata.policy.isConfigurable else { return true }
            // 可配置插件：查询用户持久化的启用状态。
            return isEnabled(id: plugin.id)
        }
    }

    // MARK: - Plugin Observation

    @discardableResult
    public func addPluginObserver(_ callback: @escaping (PluginManagingEvent) -> Void) -> any PluginManagingObserverHandle {
        let handle = PluginManagingObserverHandleImpl(owner: self, callback: callback)
        observers.append(WeakPluginManagingObserver(handle))
        return handle
    }

    /// 当前注册的观察者集合。
    ///
    /// 弱引用持有令牌：外部释放令牌后，其 deinit 即视为自动注销，
    /// 下次广播时清理已失效的弱引用。
    private var observers: [WeakPluginManagingObserver] = []

    /// 从集合中移除指定观察者（供令牌的 cancel 调用）。
    fileprivate func removeObserver(_ handle: any PluginManagingObserverHandle) {
        observers.removeAll { $0.handle === handle }
    }

    /// 向所有已注册观察者广播事件。
    ///
    /// 先清理已释放令牌并复制再遍历，避免回调中注销自身导致数组在遍历期间变化。
    private func notifyObservers(_ event: PluginManagingEvent) {
        observers.removeAll { $0.handle == nil }
        let current = observers
        for observer in current {
            observer.handle?.invoke(event)
        }
    }
}

// MARK: - 兼容命名

/// 兼容别名：旧代码中使用 `DefaultPluginManaging` 命名。
public typealias DefaultPluginManaging = DefaultPluginManager

// MARK: - Observer Handle Implementation

/// `DefaultPluginManager` 的观察者令牌实现。
///
/// 弱引用 owner，避免与管理器形成引用环；令牌被外部释放后，管理器侧
/// 持有的弱引用自动失效，并在下次广播时清理，因此调用方无需手动反注册。
@MainActor
private final class PluginManagingObserverHandleImpl: PluginManagingObserverHandle {
    private weak var owner: DefaultPluginManager?
    private let callback: (PluginManagingEvent) -> Void
    private var isCancelled = false

    init(owner: DefaultPluginManager, callback: @escaping (PluginManagingEvent) -> Void) {
        self.owner = owner
        self.callback = callback
    }

    func cancel() {
        guard !isCancelled else { return }
        isCancelled = true
        owner?.removeObserver(self)
    }

    /// 通知回调（已注销的令牌不再触发）。
    fileprivate func invoke(_ event: PluginManagingEvent) {
        guard !isCancelled else { return }
        callback(event)
    }
}

/// 观察者集合的元素：弱引用持有令牌，令牌被外部释放后自动失效。
@MainActor
private final class WeakPluginManagingObserver {
    fileprivate weak var handle: PluginManagingObserverHandleImpl?

    init(_ handle: PluginManagingObserverHandleImpl) {
        self.handle = handle
    }
}
