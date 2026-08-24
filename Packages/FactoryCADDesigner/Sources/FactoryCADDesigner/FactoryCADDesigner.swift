import FactoryLumi
import KernelCore
import PluginCADDesigner
import SwiftUI

/// CAD Designer 的独立 KernelCore 宿主。
///
/// 专用 App 将 CAD 插件提升为 always-on，但不改变主 Lumi 中的默认禁用策略。
@MainActor
public enum FactoryCADDesigner {
    public static let cadDesignerPluginID = "com.coffic.lumi.plugin.cad-designer"

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
    func makePlugins() -> [any SuperPlugin] {
        [DedicatedAlwaysOnPlugin(CADDesignerSuperPlugin())]
    }
}

@MainActor
private final class DedicatedAlwaysOnPlugin: SuperPlugin {
    private let wrapped: any SuperPlugin

    init(_ wrapped: any SuperPlugin) { self.wrapped = wrapped }

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
