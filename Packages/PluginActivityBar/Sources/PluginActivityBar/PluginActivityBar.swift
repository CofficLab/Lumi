import Combine
import Foundation
import KernelCore
import os
import ProviderActivityBar
import SuperLogKit

/// ActivityBar 自定义插件（KernelCore 生态）。
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
/// 订阅内核 `objectWillChange` 监听插件注册表变化：当某个插件被卸载或禁用时，
/// 自动隐藏其贡献的 ActivityBar 入口；当插件重新启用时，自动恢复其入口。
@MainActor
public final class PluginActivityBar: SuperPlugin, SuperLog {
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi.plugin.activity-bar", category: "Plugin")
    public nonisolated static let emoji = "🧱"
    nonisolated static let verbose = false

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

    /// 内核 objectWillChange 订阅；deinit 时自动取消。
    private var kernelSubscription: AnyCancellable?

    /// 上一次快照：已注册且启用的插件 id 集合，用于 diff 检测变化。
    private var lastKnownEnabledPluginIDs: Set<String> = []

    public init() {}

    public func onBoot(kernel: KernelCoreContainer) throws {
        // 1. 在 `unregisterProvider` 之前先把旧实例的 items + activeItemID 抽出来，
        //    避免旧 `DefaultActivityBarProviding`（被 ProviderFactory 预注册的）随
        //    `unregisterProvider` 被释放时，连带丢失前序业务插件（如
        //    `PluginChatPanel` order=2 / `PluginAppIconDesigner` / `PluginDevice` / ...）
        //    `onBoot` 中已经写入的 `ActivityBarItem` 与激活态。
        let existingProvider = kernel.resolveProvider((any ActivityBarProviding).self)
        let preloadedItems = existingProvider?.items ?? []
        let preloadedActiveItemID = existingProvider?.activeItemID

        // 2. 注销 ProviderFactory 预注册的默认实现（避免 providerAlreadyRegistered）。
        kernel.unregisterProvider((any ActivityBarProviding).self)

        // 3. 用旧数据预填新实例，确保 `unregisterProvider` 不会"误伤"已注册入口。
        let provider = ActivityBarProvider(
            preloadedItems: preloadedItems,
            activeItemID: preloadedActiveItemID
        )
        self.provider = provider

        // 4. 注册本插件实现（默认转发 objectWillChange，UI 经内核订阅可刷新）。
        try kernel.registerProvider((any ActivityBarProviding).self, provider)

        if Self.verbose {
            Self.logger.info("\(Self.t)registered ActivityBarProvider as ActivityBarProviding (preloaded \(preloadedItems.count, privacy: .public) 项)")
        }
    }

    /// 全部插件 `onBoot` 完成后执行收尾工作，
    /// 并订阅内核变化以监听后续插件的卸载/启用。
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
        if Self.verbose {
            Self.logger.info("\(Self.t)bootstrapped built-in items: \(provider.items.count, privacy: .public) 项")
        }

        // 记录当前已启用的插件集合，作为后续 diff 的基线。
        lastKnownEnabledPluginIDs = currentEnabledPluginIDs(kernel: kernel)

        // 订阅内核 objectWillChange：每次插件注册表变化时重新 diff，
        // 对新增/消失的插件执行隐藏/恢复入口。
        kernelSubscription = kernel.objectWillChange.sink { [weak self, weak kernel] _ in
            guard let self, let kernel else { return }
            self.syncPluginVisibility(kernel: kernel)
        }
    }

    public func onShutdown(kernel: KernelCoreContainer) throws {
        kernelSubscription?.cancel()
        kernelSubscription = nil
        provider = nil
        lastKnownEnabledPluginIDs = []
        // 内核会按插件归属自动撤回 onBoot 注册的 Provider，无需手动处理。
    }

    // MARK: - Plugin Visibility Sync

    /// 对比当前已启用插件集合与上次快照，执行隐藏/恢复操作。
    private func syncPluginVisibility(kernel: KernelCoreContainer) {
        guard let provider else { return }
        let currentIDs = currentEnabledPluginIDs(kernel: kernel)

        // 被卸载或禁用的插件：从快照中消失。
        let removed = lastKnownEnabledPluginIDs.subtracting(currentIDs)
        for pluginID in removed {
            provider.hideItems(forPluginID: pluginID)
        }

        // 新启用的插件：在快照中新增。
        let added = currentIDs.subtracting(lastKnownEnabledPluginIDs)
        for pluginID in added {
            provider.restoreItems(forPluginID: pluginID)
        }

        lastKnownEnabledPluginIDs = currentIDs
    }

    /// 获取当前所有已注册且启用的插件 id 集合。
    private func currentEnabledPluginIDs(kernel: KernelCoreContainer) -> Set<String> {
        Set(kernel.allPlugins.filter { kernel.isPluginEnabled(id: $0.id) }.map(\.id))
    }
}
