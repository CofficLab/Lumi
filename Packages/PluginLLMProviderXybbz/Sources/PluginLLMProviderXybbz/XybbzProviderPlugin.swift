import Foundation
import os
import KernelCore
import ProviderLLMManager
import KitLLM
import SuperLogKit

/// Xybbz 供应商装配插件（KernelCore 生态）。
///
/// 在 `onBoot` 中把本供应商的 XybbzProvider 注册进
/// `LLMProviderManagerProviding`，聊天链路即可经管理器路由到该供应商。
@MainActor
public final class XybbzProviderPlugin: SuperPlugin, SuperLog {
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi.plugin.llm-provider.xybbz", category: "Xybbz")
    nonisolated public static let emoji = "🔮"
    nonisolated static let verbose = false

    public let id = "com.coffic.lumi.plugin.llm-provider.xybbz"
    public let order = 100
    public let metadata = PluginMetadata(
        id: "com.coffic.lumi.plugin.llm-provider.xybbz",
        name: "Xybbz 供应商",
        description: "注册 XybbzProvider 到 LLM 管理器。",
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
        let providers: [any SuperLLMProvider] = [XybbzProvider()]
        for provider in providers {
            if Self.verbose {
                let typeName = String(describing: type(of: provider))
                Self.logger.debug("\(Self.t)Registering provider: \(typeName, privacy: .public)")
            }
            try? manager.register(provider)
        }
    }
}
