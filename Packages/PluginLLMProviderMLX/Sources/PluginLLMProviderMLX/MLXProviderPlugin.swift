import Foundation
import KernelCore
import KitLLM
import ProviderLLMManager
import ProviderStorage
import KitSuperLog
import os

/// MLX 本地模型供应商注册插件。
@MainActor
public final class MLXProviderPlugin: SuperPlugin, PluginDataMigrating, SuperLog {
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi.plugin.llm-provider.mlx", category: "MLXProvider")
    private static let legacyStorageKey = "LLMProviderMLX"

    public let id = "com.coffic.lumi.plugin.llm-provider.mlx"
    public let legacyDataDirectoryNames = ["LLMProviderMLX"]
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

    public func migrateData(context: PluginDataMigrationContext) throws {
        try PluginDataMigrationUtility.copyLegacyDirectories(
            legacyDirectoryNames: legacyDataDirectoryNames,
            context: context
        )

        // MLX 模型最初位于未版本化的 Application Support 目录；保留旧目录，
        // 将其中尚未存在于新目录的模型文件合并过去。
        guard let appSupport = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first else { return }
        let legacyDirectory = appSupport
            .appendingPathComponent("com.coffic.lumi", isDirectory: true)
            .appendingPathComponent(Self.legacyStorageKey, isDirectory: true)
        guard FileManager.default.fileExists(atPath: legacyDirectory.path) else { return }

        try FileManager.default.createDirectory(
            at: context.currentPluginDataDirectory,
            withIntermediateDirectories: true
        )
        try PluginDataMigrationUtility.mergeDirectoryContents(
            from: legacyDirectory,
            to: context.currentPluginDataDirectory
        )
    }

    public func onBoot(kernel: KernelCoreContainer) throws {
        if let storage = kernel.resolveProvider((any StorageProviding).self) {
            let rootDirectory = storage.pluginDataDirectory(for: id)
            MLXModelPaths.configure(rootDirectory: rootDirectory)
            MLXDownloadManager.shared.configure(rootDirectory: rootDirectory)
            MLXRuntime.shared.configure(rootDirectory: rootDirectory)
        } else {
            Self.logger.error("\(Self.t) StorageProviding not found")
        }

        guard let manager = kernel.resolveProvider((any LLMManaging).self) else {
            Self.logger.error("\(Self.t) LLMManaging not found")
            return
        }

        let providers: [any SuperLLMProvider] = [
            QwenMLXProvider(),
            LlamaMLXProvider(),
            MistralMLXProvider(),
            GemmaMLXProvider(),
            DeepSeekMLXProvider(),
            CoderMLXProvider(),
            MicrosoftMLXProvider(),
        ]
        for provider in providers {
            try manager.register(provider)
        }
    }

    public func onShutdown(kernel: KernelCoreContainer) throws {
        guard let manager = kernel.resolveProvider((any LLMManaging).self) else { return }
        for registration in MLXProviderCatalog.registrations {
            manager.unregister(id: registration.providerID)
        }
        MLXDownloadManager.shared.shutdown()
        MLXRuntime.shared.unload()
    }
}
