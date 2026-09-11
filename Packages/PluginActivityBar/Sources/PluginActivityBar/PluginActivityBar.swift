import Foundation
import KernelCore
import os
import ProviderActivityBar
import KitSuperLog
import ProviderPluginManaging
import ProviderRootView
import ProviderStorage

/// ActivityBar 自定义插件。
///
/// 替换 `DefaultProviderFactory.registerProviders` 预注册的 `DefaultActivityBarProviding`，
/// 为后续解析 `ActivityBarProviding` 的视图工厂（`DefaultViewFactory.makeMainView`）以
/// 及其他业务插件贡献者提供本插件实现的 `ActivityBarProvider`。
///
/// 执行顺序：order = 10
/// - 应先于 `DefaultViewFactory` 装配（ViewFactory 在 `kernel.start(plugins:)` 之后
///   才解析 provider），因此只要 `start(plugins:)` 之前完成即可；
/// - 必须先于"想接入 ActivityBar 入口"的业务插件（如 `PluginResumeDesigner` order=81），
///   业务插件在 `onBoot` 中调用 `addItems` 时期望拿到的是本插件的实现。
///
/// 订阅 `PluginManaging` 的精准事件：当某个插件被卸载或禁用时，自动隐藏其
/// 贡献的 ActivityBar 入口；当插件重新启用时，自动恢复其入口。
@MainActor
public final class PluginActivityBar: SuperPlugin, SuperLog {
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi.plugin.activity-bar", category: "Plugin")
    public nonisolated static let emoji = "🧱"
    nonisolated static let verbose = true

    public let id = "com.coffic.lumi.plugin.activity-bar"
    public let order = 10
    public let metadata = PluginMetadata(
        id: "com.coffic.lumi.plugin.activity-bar",
        name: "Plugin Activity Bar",
        description: "",
        category: .core,
        stage: .stable,
        policy: .alwaysOn
    )


    /// 本插件注册的自定义 Provider（保存引用便于 onShutdown / 调试诊断）。
    private var provider: ActivityBarProvider?
    /// ActivityBar 视图唯一使用的数据源，由 Observer 更新。
    private var viewModel: ActivityBarViewModel?

    /// 插件管理 Observer；内部负责处理插件启停事件与入口可见性同步。
    private var pluginManagerObserver: PluginManagerObserver?
    private weak var rootView: (any RootViewProviding)?

    private static let storageDirectoryKey = "ActivityBar"
    private var stateStore: ActivityBarStateStore?
    private var pendingActiveItemID: String?

    public init() {}

    public func onBoot(kernel: KernelCoreContainer) throws {
        if Self.verbose {
            Self.logger.info("\(Self.t)onBoot begin")
        }
        // 1. 在 `unregisterProvider` 之前先把旧实例的 items + activeItemID 抽出来，
        //    避免旧 `DefaultActivityBarProviding`（被 ProviderFactory 预注册的）随
        //    `unregisterProvider` 被释放时，连带丢失前序业务插件（如
        //    `PluginChatPanel` order=2 / `PluginAppIconDesigner` / `PluginDevice` / ...）
        //    `onBoot` 中已经写入的 `ActivityBarItem` 与激活态。
        let existingProvider = kernel.resolveProvider((any ActivityBarProviding).self)
        let preloadedItems = existingProvider?.items ?? []
        let preloadedActiveItemID = existingProvider?.activeItemID
        if Self.verbose {
            Self.logger.info("\(Self.t)preloaded items=\(preloadedItems.count, privacy: .public), active=\(preloadedActiveItemID ?? "nil", privacy: .public)")
        }

        if let storage = kernel.resolveProvider((any StorageProviding).self) {
            let stateStore = ActivityBarStateStore(
                directory: storage.pluginDataDirectory(for: Self.storageDirectoryKey)
            )
            self.stateStore = stateStore
            self.pendingActiveItemID = stateStore.loadActiveItemID()
        } else {
            self.stateStore = nil
            self.pendingActiveItemID = nil
        }

        // 2. 注销 ProviderFactory 预注册的默认实现（避免 providerAlreadyRegistered）。
        kernel.unregisterProvider((any ActivityBarProviding).self)

        // 3. 用旧数据预填新实例，确保 `unregisterProvider` 不会"误伤"已注册入口。
        let provider = ActivityBarProvider(
            preloadedItems: preloadedItems,
            activeItemID: pendingActiveItemID ?? preloadedActiveItemID
        )
        self.provider = provider
        self.viewModel = provider.viewModel

        // 4. 注册本插件实现。消费者直接观察 ActivityBarProvider，Kernel 不转发
        // 其高频状态变化。
        try kernel.registerHostProvider((any ActivityBarProviding).self, provider)

        if Self.verbose {
            Self.logger.info("\(Self.t)registered ActivityBarProvider as ActivityBarProviding (preloaded \(preloadedItems.count, privacy: .public) 项)")
        }
    }

    /// 全部插件 `onBoot` 完成后执行收尾工作，并订阅插件管理 Provider 的精准
    /// 事件以监听后续插件的卸载/启用。
    ///
    /// 这里不能放进 `onBoot`：业务插件（order=81+）在 `onBoot` 中也会
    /// 注册自己的入口，必须让它们先注册完毕。
    public func onReady(kernel: KernelCoreContainer) throws {
        guard let provider = kernel.resolveProvider((any ActivityBarProviding).self) as? ActivityBarProvider else {
            if Self.verbose {
                Self.logger.warning("\(Self.t)ActivityBarProviding not resolved as ActivityBarProvider, skip bootstrap")
            }
            return
        }
        // 预留：业务插件可在此处追加默认入口
        provider.bootstrapBuiltInItems()
        rootView = kernel.resolveProvider((any RootViewProviding).self)
        provider.onActiveItemChanged = { [weak self, weak provider] id in
            self?.stateStore?.saveActiveItemID(id)
            self?.syncContentFooterVisibility(provider: provider)
        }
        restorePendingActiveItemIfAvailable(provider)
        syncContentFooterVisibility(provider: provider)
        if Self.verbose {
            Self.logger.info("\(Self.t)bootstrapped built-in items: \(provider.items.count, privacy: .public) 项")
        }

        // Observer 自己读取当前已启用插件集合，并在内部处理后续 diff。
        guard let pluginManager = kernel.resolveProvider((any PluginManaging).self) else {
            Self.logger.error("\(Self.emoji)PluginManaging 未注册，无法监听 ActivityBar 插件可见性")
            return
        }
        guard let viewModel else {
            Self.logger.error("\(Self.emoji)ActivityBarViewModel 未初始化，无法监听 ActivityBar 状态")
            return
        }
        if Self.verbose {
            Self.logger.info("\(Self.t)create PluginManagerObserver; items=\(provider.items.count, privacy: .public), pendingActive=\(self.pendingActiveItemID ?? "nil", privacy: .public)")
        }
        pluginManagerObserver = PluginManagerObserver(
            pluginManager: pluginManager,
            provider: provider,
            rootView: rootView,
            pendingActiveItemID: pendingActiveItemID,
            viewModel: viewModel
        )
        pendingActiveItemID = nil
    }

    public func onShutdown(kernel: KernelCoreContainer) throws {
        pluginManagerObserver?.cancel()
        pluginManagerObserver = nil
        provider?.onActiveItemChanged = nil
        // ActivityBar Provider 由宿主持有，停止插件时不会随插件自动释放；
        // 清空本插件目录中所有业务入口，保证 stop/start 生命周期之间不残留旧贡献。
        provider?.registerItems([])
        provider = nil
        viewModel = nil
        rootView?.setContentFooterViewHidden(false)
        rootView = nil
        stateStore = nil
        pendingActiveItemID = nil
        // 内核会按插件归属自动撤回 onBoot 注册的 Provider，无需手动处理。
    }

    private func restorePendingActiveItemIfAvailable(_ provider: ActivityBarProvider) {
        guard let pendingActiveItemID,
              provider.items.contains(where: { $0.id == pendingActiveItemID }) else {
            return
        }

        provider.activateItem(id: pendingActiveItemID)
        self.pendingActiveItemID = nil
    }

    private func syncContentFooterVisibility(provider: ActivityBarProvider?) {
        let shouldPreserve = provider?.items.first(where: { $0.id == provider?.activeItemID })?.preservesContentFooter ?? false
        rootView?.setContentFooterViewHidden(!shouldPreserve)
    }
}
