import Foundation
import KernelCore
import KitLLM
import ProviderLLMManager
import ProviderStorage
import LumiLoggingKit
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

        // 下载限速此前存在 UserDefaults，仅在插件存储尚无该键时导入。
        // 须在下面的早退分支之前执行。
        importLegacyDownloadSpeedLimit(to: context.currentPluginDataDirectory)

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

    /// 把 `UserDefaults.standard` 中的旧下载限速导入插件专属存储。
    ///
    /// 仅在插件存储尚无该键时导入，避免覆盖用户后续的调整。
    /// `UserDefaults` 原 key 保留，便于回退。
    private func importLegacyDownloadSpeedLimit(to directory: URL) {
        guard let domain = UserDefaults.standard.persistentDomain(forName: Bundle.main.bundleIdentifier ?? ""),
              let legacyValue = domain[MLXDownloadManager.downloadSpeedLimitKey] as? Int,
              legacyValue > 0
        else {
            return
        }
        let settingsFile = directory.appendingPathComponent("settings.plist")
        guard !FileManager.default.fileExists(atPath: settingsFile.path) else { return }
        MLXProviderPluginLocalStore(settingsDirectory: directory)
            .setDownloadSpeedLimit(legacyValue)
        Self.logger.info("\(Self.t)Imported legacy download speed limit from UserDefaults: \(legacyValue)")
    }

    public func onBoot(kernel: KernelCoreContainer) throws {
        if let storage = kernel.resolveProvider((any StorageProviding).self) {
            let rootDirectory = storage.pluginDataDirectory(for: id)
            MLXProviderRuntime.configure(settingsDirectory: rootDirectory)
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
