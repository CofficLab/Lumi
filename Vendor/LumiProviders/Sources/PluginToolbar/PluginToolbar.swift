import KernelCore
import LumiLoggingKit
import os
import ProviderPluginManaging
import ProviderToolbar

/// Shared toolbar lifecycle plugin for macOS and iOS contributions.
///
/// The app host registers the platform providers before plugin boot. Once every
/// plugin has registered its items, this plugin keeps both providers in sync
/// with plugin enablement so disabled contributions disappear on either platform.
@MainActor
public final class PluginToolbar: SuperPlugin, SuperLog {
    nonisolated static let logger = Logger(subsystem: "com.coffic.shared.plugin.toolbar", category: "Plugin")
    public nonisolated static let emoji = "🧰"
    nonisolated static let verbose = false

    /// 默认插件标识。宿主可在装配时传入自己的 id。
    public static let defaultPluginID = "com.coffic.shared.plugin.toolbar"

    public let id: String
    public let order = 0
    public let metadata: PluginMetadata

    private var stateObserver: PluginToolbarStateObserver?

    /// 创建共享工具栏插件。
    ///
    /// - Parameter id: 插件唯一标识，决定 `PluginMetadata.id`。
    public init(id: String = PluginToolbar.defaultPluginID) {
        self.id = id
        self.metadata = PluginMetadata(
            id: id,
            name: "Toolbar",
            description: "Manages shared macOS and iOS toolbar contributions.",
            category: .core,
            stage: .stable,
            policy: .alwaysOn
        )
    }

    public func onBoot(kernel: KernelCoreContainer) throws {}

    public func onReady(kernel: KernelCoreContainer) throws {
        guard let pluginManager = kernel.resolveProvider((any PluginManaging).self) else {
            Self.logger.error("\(Self.emoji)PluginManaging is not registered; toolbar enablement tracking is unavailable")
            return
        }

        var providers: [any ToolbarPluginStateProviding] = []
        if let provider = kernel.resolveProvider((any ToolbarProviding).self) {
            providers.append(provider)
        }
        if let provider = kernel.resolveProvider((any IOSNavigationBarProviding).self) {
            providers.append(provider)
        }
        guard !providers.isEmpty else {
            Self.logger.error("\(Self.emoji)No toolbar providers are registered; skipping enablement tracking")
            return
        }

        stateObserver = PluginToolbarStateObserver(pluginManager: pluginManager, providers: providers)
    }

    public func onShutdown(kernel: KernelCoreContainer) throws {
        stateObserver?.cancel()
        stateObserver = nil
    }
}
