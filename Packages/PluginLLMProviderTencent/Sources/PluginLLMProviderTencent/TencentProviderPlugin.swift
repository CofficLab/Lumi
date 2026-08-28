import Foundation
import os
import KernelCore
import ProviderLLMManager
import KitLLM

/// 腾讯云供应商装配插件。
@MainActor
public final class TencentProviderPlugin: SuperPlugin {
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi.plugin.llm-provider.tencent", category: "Tencent")
    nonisolated public static let emoji = "☁️"
    nonisolated static let verbose = false

    public let id = "com.coffic.lumi.plugin.llm-provider.tencent"
    public let order = 100
    public let metadata = PluginMetadata(
        id: "com.coffic.lumi.plugin.llm-provider.tencent",
        name: "腾讯云供应商",
        description: "注册 TokenHubProvider 到 LLM 管理器。",
        category: .llm,
        stage: .stable,
        policy: .alwaysOn
    )

    public init() {}

    public func onBoot(kernel: KernelCoreContainer) throws {
        guard let manager = kernel.resolveProvider((any LLMManaging).self) else {
            Self.logger.error("Failed to resolve LLMProviderManagerProviding from kernel (manager is nil)")
            return
        }

        let networkProvider = kernel.resolveProvider((any LLMNetworkProviding).self)
        let apiService = VendorAPIService(networkProvider: networkProvider)
        let provider = TokenHubProvider(apiService: apiService)

        if Self.verbose {
            Self.logger.debug("Registering provider: TokenHubProvider")
        }
        try? manager.register(provider)
    }
}
