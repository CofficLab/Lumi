import Foundation
import os
import KernelCore
import ProviderLLMManager
import KitLLM
import LumiLoggingKit
/// CommandCode 供应商装配插件（KernelCore 生态）。
///
/// 在 `onBoot` 中把 GoatPlanProvider 注册进
/// `LLMProviderManagerProviding`，聊天链路即可经管理器路由到对应供应商。
@MainActor
public final class CommandCodeProviderPlugin: SuperPlugin, SuperLog {
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi.plugin.llm-provider.commandcode", category: "CommandCode")
    nonisolated public static let emoji = "🔌"
    nonisolated static let verbose = false

    public let id = "com.coffic.lumi.plugin.llm-provider.commandcode"
    public let order = 100
    public let metadata = PluginMetadata(
        id: "com.coffic.lumi.plugin.llm-provider.commandcode",
        name: "CommandCode 供应商",
        description: "注册 GoatPlan 供应商到 LLM 管理器。",
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
        let provider = GoatPlanProvider(apiService: apiService)
        if Self.verbose {
            Self.logger.debug("\(Self.t)Registering provider: \(String(describing: type(of: provider)), privacy: .public)")
        }
        try? manager.register(provider)
        scheduleModelRefresh(provider: provider, manager: manager)
    }

    /// 启动后后台刷新一次远程模型列表（fire-and-forget）。
    ///
    /// - 不阻塞启动：缓存/静态基线已保证「注册即可用」。
    /// - 失败静默：磁盘缓存与静态基线兜底，不影响注册与选中态。
    /// - 成功广播：`modelsRefreshed` 事件让 UI 读取最新模型池。
    private func scheduleModelRefresh(provider: GoatPlanProvider, manager: any LLMManaging) {
        Task { @MainActor [weak provider] in
            guard let provider else { return }
            do {
                try await provider.refreshModels()
                manager.notifyModelsRefreshed(providerID: provider.providerID)
                if Self.verbose {
                    Self.logger.debug("\(Self.t)remote model list refreshed, total=\(provider.availableModels.count, privacy: .public)")
                }
            } catch {
                // 失败保留旧模型池（缓存 / 静态基线），静默即可。
                Self.logger.debug("\(Self.t)model refresh failed\(self.r("falling back to cache"))")
            }
        }
    }
}
