import Foundation
import KernelCore
import ProviderPluginControl

/// 默认 `PluginManaging` 实现：直接驱动 `KernelCoreContainer` 插件注册表。
///
/// 启停控制委托给 `PluginControlling`（默认 `DefaultPluginControlling`），
/// 枚举 / 查询 / 卸载 / 重载直接读写内核注册表，保证与真实生命周期一致。
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
