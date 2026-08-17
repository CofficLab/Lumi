import Foundation
import os
import KernelCore
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
        let manager = SettingViewManager()
        self.manager = manager

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
