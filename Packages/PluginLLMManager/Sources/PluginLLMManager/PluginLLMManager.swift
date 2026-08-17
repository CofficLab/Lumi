import Foundation
import os
import KernelCore
import ProviderLLMManager
import SuperLogKit

/// LLM 供应商管理器插件（KernelCore 生态）。
///
/// 替换 `DefaultProviderFactory` 预注册的 `DefaultLLMManager`：在 `onBoot`
/// 中把自研的 `CustomLLMManager` 注册为 `LLMManaging`，让所有后续解析
/// `LLMManaging` 的插件（供应商注册 order=100、AgentLoop order=8、模型选择
/// UI）统一使用本插件提供的实现。
///
/// 执行顺序：order = 5
/// - 必须先于 `PluginAgentLoop`（order=8）：后者 onBoot 时
///   `resolveProvider((any LLMManaging).self)` 注入 AgentLoop，需拿到本实现；
/// - 必须先于各供应商插件（order=100）：供应商需注册进本插件的管理器。
@MainActor
public final class PluginLLMManager: SuperPlugin, SuperLog {
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi.plugin.llm-manager", category: "Plugin")
    nonisolated public static let emoji = "🧭"
    nonisolated static let verbose = false

    public let id = "com.coffic.lumi.plugin.llm-manager"
    public let order = 5

    public var metadata: PluginMetadata {
        PluginMetadata(
            id: id,
            name: "LLM Provider Manager",
            description: "自研 LLMManaging 实现：供应商注册表 + 选中持久化 + 请求路由",
            category: .chat,
            stage: .preview,
            policy: .enabledByDefault
        )
    }

    public init() {}

    public func onBoot(kernel: KernelCoreContainer) throws {
        let manager = CustomLLMManager()

        // 1. 注销 ProviderFactory 预注册的默认实现（避免 providerAlreadyRegistered）。
        kernel.unregisterProvider((any LLMManaging).self)

        // 2. 注册本插件实现（默认转发 objectWillChange，UI 经内核订阅可刷新）。
        try kernel.registerProvider((any LLMManaging).self, manager)

        if Self.verbose {
            Self.logger.info("\(Self.t)registered CustomLLMManager as LLMManaging")
        }
    }

    public func onShutdown(kernel: KernelCoreContainer) throws {
        // 内核会按插件归属自动撤回 onBoot 注册的 Provider，无需手动处理。
    }
}
