import KernelCore
import ProviderSettingView
import ProviderLLMManager
import ProviderStorage
import SwiftUI

/// MLX 本地模型供应商注册插件。
@MainActor
public final class MLXProviderPlugin: SuperPlugin {
    private static let legacyStorageKey = "LLMProviderMLX"

    public let id = "com.coffic.lumi.plugin.llm-provider.mlx"
    public let order = 100
    public let metadata = PluginMetadata(
        id: "com.coffic.lumi.plugin.llm-provider.mlx",
        name: "MLX 本地供应商",
        description: "在 Apple Silicon 上下载并运行 MLX 本地模型。",
        category: .llm,
        stage: .stable,
        policy: .alwaysOn
    )

    public init() {}

    public func onBoot(kernel: KernelCoreContainer) throws {
        if let storage = kernel.resolveProvider((any StorageProviding).self) {
            let rootDirectory = storage.pluginDataDirectory(for: Self.legacyStorageKey)
            MLXModelPaths.configure(rootDirectory: rootDirectory)
            MLXDownloadManager.shared.configure(rootDirectory: rootDirectory)
            MLXRuntime.shared.configure(rootDirectory: rootDirectory)
        }

        kernel.resolveProvider((any SettingViewProviding).self)?.addEntries([
            SettingEntryItem(
                id: "\(id).settings",
                title: "MLX 本地模型",
                systemImage: "cpu",
                order: 102
            ) {
                MLXSettingsView()
            }
        ])

        guard let manager = kernel.resolveProvider((any LLMManaging).self) else {
            return
        }

        for provider in MLXProviderCatalog.makeProviders() {
            try manager.register(provider)
        }
    }

    public func onShutdown(kernel: KernelCoreContainer) throws {
        guard let manager = kernel.resolveProvider((any LLMManaging).self) else { return }
        for registration in MLXProviderCatalog.registrations {
            manager.unregister(id: registration.providerID)
        }
        kernel.resolveProvider((any SettingViewProviding).self)?
            .removeEntries(ids: ["\(id).settings"])
        MLXDownloadManager.shared.shutdown()
        MLXRuntime.shared.unload()
    }
}
