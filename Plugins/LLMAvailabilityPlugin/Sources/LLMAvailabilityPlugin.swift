import LumiCoreKit
import os

/// LLM 可用性检测插件：维护实际可用的供应商+模型列表。
public enum LLMAvailabilityPlugin: LumiPlugin {
    public static let policy: LumiPluginPolicy = .alwaysOn
    public static let stage: LumiPluginStage = .beta
    public static let category: LumiPluginCategory = .general
    public static let iconName = "network"
    public static let verbose: Bool = false
    public static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.llm-availability")

    public static let info = LumiPluginInfo(
        id: "com.coffic.lumi.plugin.llm-availability",
        displayName: LumiPluginLocalization.string("LLM Availability", bundle: .module),
        description: LumiPluginLocalization.string("Detect available LLM providers and models via health checks", bundle: .module),
        order: 15
    )

    @MainActor
    public static func agentTools(context: LumiPluginContext) -> [any LumiAgentTool] {
        let llmService = LLMAvailabilityRuntime.llmService
        return [
            ListAvailableModelsTool(),
            CheckModelAvailabilityTool(llmService: llmService),
        ]
    }

    // MARK: - Bootstrap

    /// 初始化可用性检测：注入适配器并异步触发全量检测。
    ///
    /// 应在供应商注册完成后调用。
    @MainActor
    public static func bootstrap(providers: [any LumiLLMProvider]) {
        guard !providers.isEmpty else { return }

        // 初始化 Store（使用 LumiCoreKit 的 LumiLLMProviderInfo）
        let providerInfos = providers.map { type(of: $0).info }
        LLMAvailabilityStore.shared.initializeFromLumiProviders(providerInfos)

        // 注入适配器
        let adapter = LumiProviderAvailabilityAdapter(providers: providers)
        LLMAvailabilityRuntime.llmService = adapter

        // 异步触发全量检测
        Task {
            let checker = LLMAvailabilityChecker(llmService: adapter)
            await checker.checkAll()
        }
    }
}
