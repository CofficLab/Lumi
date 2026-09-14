import KernelCore
import KitSuperLog
import os
import ProviderPluginManaging
import ProviderToolbar

/// 工具栏自定义插件。
///
/// 替换 `DefaultProviderFactory.registerProviders` 预注册的
/// `DefaultToolbarProviding`，为后续解析 `ToolbarProviding` 的视图工厂
/// （`DefaultViewFactory.makeMainView`）以及各贡献工具栏项的插件提供本插件
/// 实现的 `ToolbarProvider`。
///
/// 执行顺序：order = 0
/// - 必须早于**所有**解析 `ToolbarProviding` 的插件。多个插件（如
///   `PluginChatPanel` order=1、`PluginDeveloperMode` order=1）会把解析到的
///   toolbar 引用捕获进延迟闭包，在工作区切换等时机再次调用；若本插件晚于
///   它们启动，这些调用将打在被替换掉的旧实例上而静默失效。
/// - 与 `CommandPlugin` 同为 order=0，按插件目录顺序在其后启动，无依赖冲突。
///
/// `onReady` 订阅 `PluginManaging` 的启用状态变化：运行时禁用插件走的是
/// `onDisable`，而多数插件把 `removeToolbarItems` 写在 `onShutdown` 里，直接
/// 禁用会残留工具栏视图。由本插件统一按归属过滤，无需插件各自实现 `onDisable`。
@MainActor
public final class PluginToolbar: SuperPlugin, SuperLog {
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi.plugin.toolbar", category: "Plugin")
    public nonisolated static let emoji = "🧰"
    nonisolated static let verbose = false

    public let id = "com.coffic.lumi.plugin.toolbar"
    public let order = 0
    public let metadata = PluginMetadata(
        id: "com.coffic.lumi.plugin.toolbar",
        name: "Plugin Toolbar",
        description: "",
        category: .core,
        stage: .stable,
        policy: .alwaysOn
    )

    /// 本插件注册的工具栏实现（保存引用便于 onShutdown / 调试诊断）。
    private var provider: ToolbarProvider?

    /// 插件启用状态观察者：把禁用状态同步给 Provider 以隐藏对应贡献。
    private var pluginStateObserver: PluginStateObserver?

    public init() {}

    public func onBoot(kernel: KernelCoreContainer) throws {
        // 1. 在 `unregisterProvider` 之前把旧实现的数据抽出来，避免被
        //    ProviderFactory 预注册的默认实现随注销被释放时，连带丢失前序
        //    插件 `onBoot` 中已经写入的 `ToolbarItem` 与可见分类。
        let existingProvider = kernel.resolveProvider((any ToolbarProviding).self)
        let preloadedItems = existingProvider?.toolbarItems ?? []
        let preloadedCategories = existingProvider?.visibleCategories ?? Set(ToolbarItemCategory.allCases)

        // 2. 注销 ProviderFactory 预注册的默认实现（避免 providerAlreadyRegistered）。
        kernel.unregisterProvider((any ToolbarProviding).self)

        // 3. 用旧数据预填新实例，确保替换不会丢失已注册贡献。
        let provider = ToolbarProvider(
            preloadedItems: preloadedItems,
            visibleCategories: preloadedCategories
        )
        self.provider = provider

        // 4. 注册本插件实现。消费者通过 `ToolbarProviding` 的类型化观察接口获取变化。
        try kernel.registerHostProvider((any ToolbarProviding).self, provider)

        if Self.verbose {
            Self.logger.info("\(Self.t)registered ToolbarProvider as ToolbarProviding (preloaded \(preloadedItems.count, privacy: .public) 项)")
        }
    }

    /// 全部插件 `onBoot` 完成后订阅插件启用状态变化。
    ///
    /// 不能放进 `onBoot`：`PluginManaging` 由 `PluginPluginManager` 装配，
    /// 且各业务插件（order 5+）在 `onBoot` 中才注册自己的工具栏项，
    /// 必须等它们注册完毕后才能正确建立「插件 → 工具栏项」的归属判断。
    public func onReady(kernel: KernelCoreContainer) throws {
        guard let provider else {
            Self.logger.error("\(Self.emoji)ToolbarProvider 未初始化，跳过插件启用状态监听")
            return
        }
        guard let pluginManager = kernel.resolveProvider((any PluginManaging).self) else {
            Self.logger.error("\(Self.emoji)PluginManaging 未注册，无法监听插件启用状态")
            return
        }

        pluginStateObserver = PluginStateObserver(pluginManager: pluginManager, provider: provider)
    }

    public func onShutdown(kernel: KernelCoreContainer) throws {
        pluginStateObserver?.cancel()
        pluginStateObserver = nil
        // Toolbar Provider 由宿主持有，停止插件时不会随插件自动释放；
        // 清空本插件目录中所有业务贡献，保证 stop/start 生命周期之间不残留旧项。
        provider?.registerToolbarItems([])
        provider = nil
        // 内核会按插件归属自动撤回 onBoot 注册的 Provider，无需手动处理。
    }
}
