import KernelCore
import ProviderSettingView

/// 把 `SettingViewProviding` 的注册归属从「插件」改为「宿主」。
///
/// ## 为什么需要它
///
/// 设置视图管理器插件（`PluginSettingView`，来自远程 `LumiPluginSettingView`）
/// 用 `registerProvider` 替换 `ProviderFactory` 预注册的默认实现——
/// Provider 因此归该插件所有，内核 `stop()` 时会连同 Provider 一起撤回。
///
/// 结果是：停止内核后 `SettingViewProviding` **整个消失**，而不是「条目被撤回」。
/// 这既不符合「撤回插件对共享 Provider 的**贡献**」的语义，也让同一个内核
/// 无法重启——重启时插件要 `unregisterProvider` 再注册，而 Provider 已经
/// 不在注册表里，插件拿不到自己上一次的实现。
///
/// KernelCore 为此提供了 `registerHostProvider`：宿主级注册的 Provider
/// 不归属任何插件，`stop()` 时不会被撤回。
///
/// ## 做法
///
/// 本插件在设置视图管理器之后启动（order 更高），把**当前已注册的同一个
/// 实例**用 `registerHostProvider` 重新登记。不换实现、不换 UI 行为——
/// 只是把它的归属从插件改成宿主。
@MainActor
public final class SettingViewHostPlugin: SuperPlugin {
    public let id = "com.coffic.lumi.plugin.setting-view-host"
    public let order = 4
    public let metadata = PluginMetadata(
        id: "com.coffic.lumi.plugin.setting-view-host",
        name: "Settings Host",
        description: "让设置视图实现在停止内核后依然存在，以便同一个内核可以重启。",
        category: .core,
        policy: .required
    )

    public init() {}

    public func onBoot(kernel: KernelCoreContainer) throws {
        guard let current = kernel.resolveProvider((any SettingViewProviding).self) else {
            return
        }
        // 先摘掉插件归属的注册，再用宿主级重新登记同一个实例。
        kernel.unregisterProvider((any SettingViewProviding).self)
        try kernel.registerHostProvider((any SettingViewProviding).self, current)
    }

    public func onShutdown(kernel: KernelCoreContainer) throws {
        // 宿主级 Provider 由内核在停止后继续持有，无需注销：
        // 重启时设置视图管理器插件会再次替换它。
    }
}
