import Foundation
import KernelCore
import os
import ProviderLogo
import KitSuperLog

/// Logo 管理器插件（KernelCore 生态）。
///
/// 复刻旧版 `LogoPlugin`（KernelLumi → KernelCore 适配）：
/// 以自研 `LogoManager` 替换 `ProviderFactory` 预注册的 `DefaultLogoProviding`，
/// 提供带结构化日志的 `LogoProviding` 实现。
///
/// 执行顺序：order = 4
/// - 必须先于 `PluginLLMManager`（order=5）、`PluginToolManager`（order=6）、
///   `PluginAgentLoop`（order=8）以及各 Logo 贡献插件（如 `LogoCofficPlugin` order=100），
///   确保后续插件 `resolveProvider((any LogoProviding).self)` 拿到的是本插件的实现。
@MainActor
public final class PluginLogoManager: SuperPlugin, SuperLog {
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi.plugin.logo-manager", category: "Plugin")
    public nonisolated static let emoji = "🖼️"
    nonisolated static let verbose = false

    public let id = "com.coffic.lumi.plugin.logo-manager"
    public let order = 4
    public let metadata = PluginMetadata(
        id: "com.coffic.lumi.plugin.logo-manager",
        name: "Plugin Logo Manager",
        description: "",
        category: .design,
        stage: .stable,
        policy: .alwaysOn
    )


    /// 本插件装配的 LogoManager 实现。
    private var manager: LogoManager?

    public init() {}

    public func onBoot(kernel: KernelCoreContainer) throws {
        let manager = LogoManager()
        self.manager = manager

        // 0. 复制旧的默认实现（或先前已注册实现）中已有的数据，避免数据丢失。
        //    LogoProviding 协议要求 AnyObject & ObservableObject，可直接读取协议属性。
        if let old = kernel.resolveProvider((any LogoProviding).self) {
            // 逐个重新注册，保持去重与 order 降序排序逻辑一致。
            for item in old.allLogoItems {
                manager.registerLogoItem(item)
            }
            manager.setLogoHighlighted(old.isLogoHighlighted)
            if Self.verbose {
                Self.logger.info("\(Self.t)copied \(old.allLogoItems.count) existing logo items from previous LogoProviding")
            }
        }

        // 1. 注销 ProviderFactory 预注册的默认实现（避免 providerAlreadyRegistered）。
        kernel.unregisterProvider((any LogoProviding).self)

        // 2. 注册本插件实现。消费者直接观察 LogoProviding 的状态变化。
        try kernel.registerHostProvider((any LogoProviding).self, manager)

        if Self.verbose {
            Self.logger.info("\(Self.t)registered LogoManager as LogoProviding")
        }
    }

    public func onShutdown(kernel: KernelCoreContainer) throws {
        manager = nil
        // 内核会按插件归属自动撤回 onBoot 注册的 Provider，无需手动处理。
    }
}
