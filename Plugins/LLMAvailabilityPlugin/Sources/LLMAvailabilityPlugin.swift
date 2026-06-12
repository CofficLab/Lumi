import AgentToolKit
import LumiCoreKit
import os

/// LLM 可用性检测插件：维护实际可用的供应商+模型列表。
public enum LLMAvailabilityPlugin: LumiPlugin {
    public static let policy: LumiPluginPolicy = .alwaysOn
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
            ListAvailableModelsTool().asLumiAgentTool(),
            CheckModelAvailabilityTool(llmService: llmService).asLumiAgentTool(),
        ]
    }
}
