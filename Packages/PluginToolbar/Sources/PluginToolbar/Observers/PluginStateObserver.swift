import Foundation
import KitSuperLog
import os
import ProviderPluginManaging

/// 订阅插件启用状态变化，把它同步给 `ToolbarProvider`。
///
/// 运行时禁用插件走的是 `SuperPlugin.onDisable`，而不是 `onShutdown`；多数插件把
/// `removeToolbarItems` 写在 `onShutdown` 里，因此禁用后其工具栏视图会残留在界面上。
/// 本观察者按「插件 id → 该项归属」把禁用状态喂给 Provider，由 Provider 过滤掉
/// 已禁用插件的贡献，并在重新启用时自动恢复，无需插件自己实现 `onDisable`。
@MainActor
final class PluginStateObserver: SuperLog {
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi.plugin.toolbar", category: "PluginStateObserver")
    nonisolated static let verbose = false

    private let pluginManager: any PluginManaging
    private let provider: ToolbarProvider
    private var observationHandle: (any PluginManagingObserverHandle)?

    init(pluginManager: any PluginManaging, provider: ToolbarProvider) {
        self.pluginManager = pluginManager
        self.provider = provider
        sync()
        observationHandle = pluginManager.addPluginObserver { [weak self] event in
            self?.handle(event)
        }
        if Self.verbose {
            Self.logger.info("\(Self.t)initialized: plugins=\(pluginManager.pluginCount, privacy: .public)")
        }
    }

    func cancel() {
        observationHandle?.cancel()
        observationHandle = nil
    }

    private func handle(_ event: PluginManagingEvent) {
        switch event {
        case .listChanged, .enabledStateChanged:
            // 两类事件都重新全量计算：listChanged 可能伴随插件卸载或重新加载。
            sync()
        }
    }

    private func sync() {
        let knownPluginIDs = Set(pluginManager.allPlugins.map(\.id))
        let disabledPluginIDs = Set(pluginManager.allPlugins
            .filter { !pluginManager.isEnabled(id: $0.id) }
            .map(\.id))
        provider.setPluginState(
            knownPluginIDs: knownPluginIDs,
            disabledPluginIDs: disabledPluginIDs
        )
        if Self.verbose {
            Self.logger.info("\(Self.t)已同步插件启用状态")
        }
    }
}
