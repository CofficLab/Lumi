import DatabaseManagerPlugin
import FactoryLumi
import KernelCore
import PluginCodeEditorHost
import ProviderExternalFile
import SwiftUI

/// DatabaseManager 的专属 KernelCore 宿主工厂。
@MainActor
public enum FactoryDatabaseManager {
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

    @discardableResult
    public static func openExternalFile(_ url: URL, kernel: KernelCoreContainer) -> Bool {
        kernel.resolveProvider((any ExternalFileOpening).self)?.open(url) ?? false
    }
}

@MainActor
private struct DedicatedPluginFactory: PluginFactory {
    func makePlugins() -> [any SuperPlugin] {
        [
            DedicatedAlwaysOnPlugin(CodeEditorHostPlugin()),
            DedicatedAlwaysOnPlugin(DatabaseManagerPlugin()),
        ]
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
    // 包装只改启用策略，注册钩子也必须转发：插件在 onRegister/onUnregister
    // 注入/撤回 About 与 Manual 文档，漏转会让独立 App 永远缺关于页与说明书（#321）。
    func onRegister(kernel: KernelCoreContainer) throws { try wrapped.onRegister(kernel: kernel) }
    func onUnregister(kernel: KernelCoreContainer) throws { try wrapped.onUnregister(kernel: kernel) }
}
