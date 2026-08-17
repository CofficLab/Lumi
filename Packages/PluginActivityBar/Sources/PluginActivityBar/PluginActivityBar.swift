import Foundation
import os
import KernelCore
import ProviderActivityBar
import SuperLogKit

/// ActivityBar 自定义插件（KernelCore 生态）。
///
/// 替换 `DefaultProviderFactory.registerProviders` 预注册的 `DefaultActivityBarProviding`，
/// 为后续解析 `ActivityBarProviding` 的视图工厂（`DefaultViewFactory.makeMainView`）以
/// 及其他业务插件贡献者提供本插件实现的 `CustomActivityBarProviding`。
///
/// 执行顺序：order = 10
/// - 应先于 `DefaultViewFactory` 装配（ViewFactory 在 `kernel.start(plugins:)` 之后
///   才解析 provider），因此只要 `start(plugins:)` 之前完成即可；
/// - 必须先于"想接入 ActivityBar 入口"的业务插件（如 `PluginResumeDesigner` order=81），
///   业务插件在 `onBoot` 中调用 `addItems` 时期望拿到的是本插件的实现。
@MainActor
public final class PluginActivityBar: SuperPlugin, SuperLog {
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi.plugin.activity-bar", category: "Plugin")
    nonisolated public static let emoji = "🧱"
    nonisolated static let verbose = false

    public let id = "com.coffic.lumi.plugin.activity-bar"
    public let order = 10

    public var metadata: PluginMetadata {
        PluginMetadata(
            id: id,
            name: "ActivityBar",
            description: "自定义 ActivityBarProviding 实现，替换 ProviderFactory 预注册的默认实现",
            category: .system,
            stage: .preview,
            policy: .enabledByDefault
        )
    }

    /// 本插件注册的自定义 Provider（保存引用便于 onShutdown / 调试诊断）。
    private var provider: CustomActivityBarProviding?

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
        let provider = CustomActivityBarProviding(
            preloadedItems: preloadedItems,
            activeItemID: preloadedActiveItemID
        )
        self.provider = provider

        // 4. 注册本插件实现（默认转发 objectWillChange，UI 经内核订阅可刷新）。
        try kernel.registerProvider((any ActivityBarProviding).self, provider)

        if Self.verbose {
            Self.logger.info("\(Self.t)registered CustomActivityBarProviding as ActivityBarProviding (preloaded \(preloadedItems.count, privacy: .public) 项)")
        }
    }

    /// 全部插件 `onBoot` 完成后再补充本插件内置的"欢迎"入口。
    ///
    /// 这里不能放进 `onBoot`：业务插件（order=81+）在 `onBoot` 中也会
    /// 注册自己的入口，必须让它们先注册，最后本插件再以"内置入口"兜底。
    public func onReady(kernel: KernelCoreContainer) throws {
        guard let provider = kernel.resolveProvider((any ActivityBarProviding).self) as? CustomActivityBarProviding else {
            if Self.verbose {
                Self.logger.warning("\(Self.t)ActivityBarProviding not resolved as CustomActivityBarProviding, skip bootstrap")
            }
            return
        }
        provider.bootstrapBuiltInItems()
        if Self.verbose {
            Self.logger.info("\(Self.t)bootstrapped built-in items: \(provider.items.count, privacy: .public) 项")
        }
    }

    public func onShutdown(kernel: KernelCoreContainer) throws {
        provider = nil
        // 内核会按插件归属自动撤回 onBoot 注册的 Provider，无需手动处理。
    }
}
