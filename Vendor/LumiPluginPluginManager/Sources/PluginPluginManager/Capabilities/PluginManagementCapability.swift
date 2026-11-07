import KernelCore
import ProviderPluginManaging

/// 插件管理设置页所需的最小插件管理能力。
@MainActor
protocol PluginManagementCapability: AnyObject {
    var allPlugins: [any SuperPlugin] { get }

    /// 最近一次启停失败的原因；成功或未操作为 `nil`。
    ///
    /// 底层 `PluginControlling` 已提供该语义，插件管理页据此在启停失败时
    /// 展示错误横幅，而不是让开关静默停留在与实际不一致的位置。
    var lastErrorDescription: String? { get }

    func isEnabled(id: String) -> Bool
    func enablePlugin(id: String) async -> Bool
    func disablePlugin(id: String) async -> Bool

    @discardableResult
    func addObserver(
        _ callback: @escaping (PluginManagingEvent) -> Void
    ) -> any PluginManagingObserverHandle
}

/// 将 Kernel 的 PluginManaging Provider 适配为插件管理页能力。
@MainActor
final class PluginManagementCapabilityAdapter: PluginManagementCapability {
    private let manager: any PluginManaging

    init(manager: any PluginManaging) {
        self.manager = manager
    }

    var allPlugins: [any SuperPlugin] { manager.allPlugins }

    var lastErrorDescription: String? { manager.lastErrorDescription }

    func isEnabled(id: String) -> Bool {
        manager.isEnabled(id: id)
    }

    func enablePlugin(id: String) async -> Bool {
        await manager.enablePlugin(id: id)
    }

    func disablePlugin(id: String) async -> Bool {
        await manager.disablePlugin(id: id)
    }

    @discardableResult
    func addObserver(
        _ callback: @escaping (PluginManagingEvent) -> Void
    ) -> any PluginManagingObserverHandle {
        manager.addPluginObserver(callback)
    }
}
