import FactoryLumi
import KernelCore
import SwiftUI

/// App Icon Designer 的最小 KernelCore 宿主组合。
///
/// 复用 FactoryLumi 的完整基础 Provider，而不是旧 FactoryLumi 的全量插件目录；
/// 仅启动图标设计、工具管理和设置所需插件。图标设计器在主 Lumi 中维持
/// `.disabledByDefault`，但作为独立 App 时由包装器提升为宿主必需能力。
@MainActor
public enum FactoryAppIconDesigner {
    public static let appIconDesignerPluginID = "com.coffic.lumi.plugin.app-icon-designer"

    public static func makeKernel() throws -> KernelCoreContainer {
        try KernelFactory.makeKernel(
            providerFactory: DefaultProviderFactory(),
            pluginFactory: DedicatedPluginFactory()
        )
    }

    public static func makeMainView(kernel: KernelCoreContainer) throws -> AnyView {
        try KernelFactory.makeMainView(kernel: kernel)
    }

    public static func makeSettingsView(kernel: KernelCoreContainer) throws -> AnyView {
        try KernelFactory.makeSettingsView(kernel: kernel)
    }
}

@MainActor
private struct DedicatedPluginFactory: PluginFactory {
    private static let allowedPluginIDs: Set<String> = [
        "com.coffic.lumi.plugin.storage",
        "com.coffic.lumi.plugin.command",
        "com.coffic.lumi.plugin.setting-general",
        "com.coffic.lumi.plugin.setting-view",
        "com.coffic.lumi.plugin.tool-manager",
        "com.coffic.lumi.plugin.theme-pack",
        "com.coffic.lumi.plugin.activity-bar",
        FactoryAppIconDesigner.appIconDesignerPluginID,
    ]

    func makePlugins() -> [any SuperPlugin] {
        SelectedPluginFactory(allowedPluginIDs: Self.allowedPluginIDs)
            .makePlugins()
            .map { plugin in
                plugin.id == FactoryAppIconDesigner.appIconDesignerPluginID
                    ? DedicatedAlwaysOnPlugin(plugin)
                    : plugin
            }
    }
}

/// 仅改变专用宿主中的启用策略；所有生命周期与贡献仍由原插件实现。
@MainActor
private final class DedicatedAlwaysOnPlugin: SuperPlugin {
    private let wrapped: any SuperPlugin

    init(_ wrapped: any SuperPlugin) {
        self.wrapped = wrapped
    }

    var id: String { wrapped.id }
    var order: Int { wrapped.order }
    var dependencies: [String] { wrapped.dependencies }
    var metadata: PluginMetadata {
        PluginMetadata(
            id: wrapped.metadata.id,
            name: wrapped.metadata.name,
            description: wrapped.metadata.description,
            version: wrapped.metadata.version,
            category: wrapped.metadata.category,
            stage: wrapped.metadata.stage,
            policy: .alwaysOn,
            permissions: wrapped.metadata.permissions
        )
    }

    func onBoot(kernel: KernelCoreContainer) throws { try wrapped.onBoot(kernel: kernel) }
    func onReady(kernel: KernelCoreContainer) throws { try wrapped.onReady(kernel: kernel) }
    func onShutdown(kernel: KernelCoreContainer) throws { try wrapped.onShutdown(kernel: kernel) }
    func onEnable(kernel: KernelCoreContainer) async throws { try await wrapped.onEnable(kernel: kernel) }
    func onDisable(kernel: KernelCoreContainer) async throws { try await wrapped.onDisable(kernel: kernel) }
}
