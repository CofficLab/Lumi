import Foundation
import KernelCore
import ProviderPluginControl

// MARK: - Plugin Managing Events

/// 插件管理事件类型：描述插件系统中发生的变化。
@MainActor
public enum PluginManagingEvent {
    /// 插件列表变化（插件注册、卸载或重载后）。
    case listChanged
    /// 插件启用状态变化。
    case enabledStateChanged(pluginID: String, enabled: Bool)
}

/// 插件管理观察者的注册令牌。
///
/// 调用 `PluginManaging.addPluginObserver(_:)` 后持有返回值
/// 即可持续接收插件管理事件；令牌释放（deinit）或显式调用 `cancel()` 时
/// 自动停止接收，无需手动反注册。
@MainActor
public protocol PluginManagingObserverHandle: AnyObject {
    /// 停止接收插件管理事件。重复调用无副作用。
    func cancel()
}

// MARK: - PluginManaging

/// 插件管理协议：在 `PluginControlling`（启停控制）之上，提供对内核中
/// `SuperPlugin` 的枚举、查询、卸载与重新加载等管理能力。
///
/// 数据源是 `KernelCoreContainer` 的插件注册表，因此任何插件 / 宿主注册的
/// `SuperPlugin` 都会纳入管理范围；UI 层（如插件管理设置页）可基于该协议
/// 实现插件列表、详情、启停与卸载入口，而不直接依赖内核容器。
@MainActor
public protocol PluginManaging: PluginControlling {
    /// 已注册的全部插件（按启动顺序；未启动的按 id 排序）。
    var allPlugins: [any SuperPlugin] { get }

    /// 用户可配置的插件（排除 `required` / `alwaysOn` 策略的插件）。
    var configurablePlugins: [any SuperPlugin] { get }

    /// 已注册插件总数。
    var pluginCount: Int { get }

    /// 当前处于有效启用状态的插件数。
    var enabledCount: Int { get }

    /// 按 id 查询插件实例；不存在时返回 nil。
    func plugin(id: String) -> (any SuperPlugin)?

    /// 指定插件是否已注册。
    func isRegistered(id: String) -> Bool

    /// 卸载单个插件：执行 `onShutdown` 并撤回其登记的贡献与 Provider。
    ///
    /// 仍被其他插件依赖时抛出 `KernelCoreError.invalidLifecycleOperation`。
    func unloadPlugin(id: String) throws

    /// 重新加载单个插件：先卸载，再按内核依赖图重新启动（重放 `onBoot` / `onReady`）。
    ///
    /// 用于热更新插件实现或从异常状态恢复；插件不存在时抛出
    /// `PluginManagingError.pluginNotFound`。
    func reloadPlugin(id: String) throws

    /// 从候选插件列表中过滤出应当启动的插件。
    ///
    /// 不可配置的插件（`required` / `alwaysOn`）始终保留；可配置插件
    /// 根据用户持久化的启用状态决定是否保留。`KernelFactory` 在调用
    /// `kernel.start(plugins:)` 前通过此方法过滤，避免启动用户已禁用的插件。
    ///
    /// - Parameter candidates: 插件工厂产出的全部候选插件。
    /// - Returns: 应当启动的插件子集（保持原始顺序）。
    func enabledPlugins(from candidates: [any SuperPlugin]) -> [any SuperPlugin]

    // MARK: - Plugin Observation

    /// 注册一个观察者：当插件系统发生变更（列表变化、启用状态变化等）时，
    /// 通过 callback 收到对应的事件。
    ///
    /// 回调在主线程（`@MainActor`）同步执行。
    ///
    /// - Parameter callback: 插件管理事件变化时的通知回调。
    /// - Returns: 注销令牌；持有返回值即可持续接收，令牌释放（deinit）或调用
    ///   `cancel()` 后自动停止接收。
    @discardableResult
    func addPluginObserver(_ callback: @escaping (PluginManagingEvent) -> Void) -> any PluginManagingObserverHandle
}
