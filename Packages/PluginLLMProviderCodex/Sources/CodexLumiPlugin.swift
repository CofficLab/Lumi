import Foundation
import KernelCore
import KitSuperLog
import os
import ProviderLLMManager

/// Codex CLI 本地供应商插件。
@MainActor
public final class CodexLumiPlugin: SuperPlugin, SuperLog {
    nonisolated public static let emoji = "🔮"
    nonisolated public static let verbose = false
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi.plugin.llm-provider.codex", category: "Codex")

    public let id = "com.coffic.lumi.plugin.llm-provider.codex"
    public let order = 100
    public let metadata = PluginMetadata(
        id: "com.coffic.lumi.plugin.llm-provider.codex",
        name: "Codex",
        description: "注册 Codex CLI 本地供应商。",
        category: .llm,
        stage: .stable,
        policy: .alwaysOn
    )

    public init() {}

    public func onBoot(kernel: KernelCoreContainer) throws {
        guard let manager = kernel.resolveProvider((any LLMManaging).self) else {
            Self.logger.error("\(Self.t)LLM manager is unavailable")
            return
        }
        try manager.register(CodexProvider())
    }
}
