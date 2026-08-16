import Foundation
import KernelCore
import ProviderPluginControl

/// 插件管理错误。
public enum PluginManagingError: Error, LocalizedError, Equatable {
    /// 内核尚未附加（宿主未调用 `attach(kernel:)` 或 init 未传 kernel）。
    case kernelNotAttached
    /// 指定 id 的插件不存在。
    case pluginNotFound(id: String)
    /// 生命周期操作失败（如卸载/重载时内核拒绝）。
    case lifecycle(String)

    public var errorDescription: String? {
        switch self {
        case .kernelNotAttached:
            return "Kernel is not attached"
        case let .pluginNotFound(id):
            return "Plugin '\(id)' not found"
        case let .lifecycle(message):
            return message
        }
    }
}

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
}

/// 默认 `PluginManaging` 实现：直接驱动 `KernelCoreContainer` 插件注册表。
///
/// 启停控制委托给 `PluginControlling`（默认 `DefaultPluginControlling`），
/// 枚举 / 查询 / 卸载 / 重载直接读写内核注册表，保证与真实生命周期一致。
@MainActor
public final class DefaultPluginManaging: PluginManaging {
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
        await controlling.enablePlugin(id: id)
    }

    public func disablePlugin(id: String) async -> Bool {
        await controlling.disablePlugin(id: id)
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
    }
}
