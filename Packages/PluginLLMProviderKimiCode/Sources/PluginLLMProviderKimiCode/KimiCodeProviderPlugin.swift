import Foundation
import os
import KernelCore
import ProviderLLMManager
import KitLLM
import KitSuperLog

/// KimiCode 供应商装配插件（KernelCore 生态）。
///
/// 在 `onBoot` 中把本供应商的 KimiCodeProvider() 注册进
/// `LLMProviderManagerProviding`，聊天链路即可经管理器路由到该供应商。
/// 两个协议变体共享同一批模型与 API Key，仅保留功能最完整的 OpenAI 协议变体，
/// Anthropic 变体现注释停用。
@MainActor
public final class KimiCodeProviderPlugin: SuperPlugin, SuperLog {
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi.plugin.llm-provider.kimicode", category: "KimiCode")
    nonisolated public static let emoji = "🌙"
    nonisolated static let verbose = false

    public let id = "com.coffic.lumi.plugin.llm-provider.kimicode"
    public let order = 100
    public let metadata = PluginMetadata(
        id: "com.coffic.lumi.plugin.llm-provider.kimicode",
        name: "KimiCode 供应商",
        description: "",
        category: .llm,
        stage: .stable,
        policy: .alwaysOn
    )

    public init() {}

    public func onBoot(kernel: KernelCoreContainer) throws {
        guard let manager = kernel.resolveProvider((any LLMManaging).self) else {
            Self.logger.error("\(Self.t)Failed to resolve LLMProviderManagerProviding from kernel\(self.r("manager is nil"))")
            return
        }
        let networkProvider = kernel.resolveProvider((any LLMNetworkProviding).self)
        let apiService = VendorAPIService(networkProvider: networkProvider)
        // 两个协议变体共享同一批模型与 API Key，仅保留功能最完整的 OpenAI 协议变体。
        // Anthropic 变体现注释停用（如需切换协议，取消注释即可）。
        let providers: [any SuperLLMProvider] = [KimiCodeProvider(apiService: apiService)]
        // let providers: [any SuperLLMProvider] = [KimiCodeAnthropicProvider(apiService: apiService)]
        for provider in providers {
            if Self.verbose {
                let typeName = String(describing: type(of: provider))
                Self.logger.debug("\(Self.t)Registering provider: \(typeName, privacy: .public)")
            }
            try? manager.register(provider)
        }
    }
}
