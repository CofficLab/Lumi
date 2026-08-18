import Foundation
import os
import KernelCore
import ProviderLogo
import ProviderSettingView
import SuperLogKit

/// 设置视图管理器插件（KernelCore 生态）。
///
/// 以自研 `SettingViewManager` 替换 `ProviderFactory` 预注册的
/// `DefaultSettingViewProviding`，提供带结构化日志的 `SettingViewProviding` 实现。
///
/// 执行顺序：order = 3
/// - 必须先于所有通过 `SettingViewProviding.addEntries(_:)` 贡献设置入口的插件
///   （如 `PluginSettingGeneral` order=200、`PluginToolManager` order=6 等），
///   确保后续插件 `resolveProvider((any SettingViewProviding).self)` 拿到的是本插件的实现。
@MainActor
public final class PluginSettingView: SuperPlugin, SuperLog {
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi.plugin.setting-view", category: "Plugin")
    nonisolated public static let emoji = "⚙️"
    nonisolated static let verbose = false

    public let id = "com.coffic.lumi.plugin.setting-view"
    public let order = 3

    public var metadata: PluginMetadata {
        PluginMetadata(
            id: id,
            name: "Setting View Manager",
            description: "自研 SettingViewProviding 实现，替换默认 SettingViewProvider（带结构化日志）",
            category: .system,
            stage: .preview,
            policy: .enabledByDefault
        )
    }

    /// 本插件装配的 SettingViewManager 实现。
    private var manager: SettingViewManager?

    public init() {}

    public func onBoot(kernel: KernelCoreContainer) throws {
        // 侧边栏 Logo 是插件内部行为：从内核解析 LogoProviding，自行构建 Header。
        // 注意：这里不能固定持有解析到的实例。LogoProviding 会先后被
        // PluginLogoManager(order=4) 替换、再由 LogoCofficPlugin(order=100) 注册，
        // 若在 order=3 时固定拿到 DefaultLogoProviding，将永远读不到 Coffic Logo。
        // 因此改为惰性闭包：在真正渲染设置视图时（启动完成）再动态解析，拿到
        // 已装配好 Logo 贡献的最新实现。
        weak var weakKernel = kernel
        let manager = SettingViewManager(logoProvider: { [weak weakKernel] in
            weakKernel?.resolveProvider((any LogoProviding).self)
        })
        self.manager = manager

        // 0. 复制旧的默认实现（或先前已注册实现）中已有的数据，避免数据丢失。
        //    在注销前解析旧的 SettingViewProviding，把已注入的入口和选中状态迁移到本实现。
        if let old = kernel.resolveProvider((any SettingViewProviding).self) {
            if !old.entries.isEmpty {
                manager.registerEntries(old.entries)
            }
            // 读取旧的选中 id（仅当旧实现是 ObservableObject 时可由协议扩展读取）。
            if let oldSelection = (old as? any SettingViewProviding & ObservableObject)?.selectedEntryID {
                manager.selectEntry(id: oldSelection)
            }
            if Self.verbose {
                Self.logger.info("\(Self.t)copied \(old.entries.count) existing entries from previous SettingViewProviding")
            }
        }

        // 1. 注销 ProviderFactory 预注册的默认实现（避免 providerAlreadyRegistered）。
        kernel.unregisterProvider((any SettingViewProviding).self)

        // 2. 注册本插件实现（默认转发 objectWillChange，UI 经内核订阅可刷新）。
        try kernel.registerProvider((any SettingViewProviding).self, manager)

        if Self.verbose {
            Self.logger.info("\(Self.t)registered SettingViewManager as SettingViewProviding")
        }
    }

    public func onShutdown(kernel: KernelCoreContainer) throws {
        manager = nil
        // 内核会按插件归属自动撤回 onBoot 注册的 Provider，无需手动处理。
    }
}
