import Foundation
import os
import KernelCore
import ProviderLLMManager
import KitLLM
import SuperLogKit

/// OpenCode 供应商装配插件（KernelCore 生态）。
///
/// 在 `onBoot` 中把 GoProvider 和 ZenProvider 注册进
/// `LLMProviderManagerProviding`，聊天链路即可经管理器路由到对应供应商。
@MainActor
public final class OpenCodeProviderPlugin: SuperPlugin, SuperLog {
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi.plugin.llm-provider.opencode", category: "OpenCodeProvider")
    nonisolated public static let emoji = "🔌"
    nonisolated static let verbose = false

    public let id = "com.coffic.lumi.plugin.llm-provider.opencode"
    public let order = 100
    public let metadata = PluginMetadata(
        id: "com.coffic.lumi.plugin.llm-provider.opencode",
        name: "OpenCode 供应商",
        description: "注册 GoProvider 和 ZenProvider 到 LLM 管理器。",
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
        let apiService = VendorAPIService()
        let providers: [any SuperLLMProvider] = [
            GoProvider(apiService: apiService),
            ZenProvider(apiService: apiService)
        ]
        for provider in providers {
            if Self.verbose {
                let typeName = String(describing: type(of: provider))
                Self.logger.debug("\(Self.t)Registering provider: \(typeName, privacy: .public)")
            }
            try? manager.register(provider)
        }
    }
}
