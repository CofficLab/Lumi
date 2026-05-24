import os
import AgentToolKit

/// LLM 可用性检测插件
/// 通过向每个供应商的每个模型发送 ping 请求，维护实际可用的供应商+模型列表
///
/// 该插件只负责 Store、Checker 和 Agent Tools；视图和初始化入口由 ModelSelectorPlugin 提供。
actor LLMAvailabilityPlugin: SuperPlugin {
    /// 插件专用 Logger
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.llm-availability")

    nonisolated static let emoji = "🔍"
    nonisolated static let verbose: Bool = true
    static let id = "LLMAvailability"
    static let displayName = String(localized: "LLM Availability", table: "LLMAvailability")
    static let description = String(localized: "Detect available LLM providers and models via health checks", table: "LLMAvailability")
    static let iconName = "network"
    static var category: PluginCategory { .general }
    static var order: Int { 15 }
    static let enable: Bool = true

    /// 核心基础设施插件，不允许用户禁用
    static var isConfigurable: Bool { false }

    static let shared = LLMAvailabilityPlugin()

    nonisolated func onRegister() {}
    nonisolated func onEnable() {}
    nonisolated func onDisable() {}

    @MainActor
    func agentTools(context: ToolContext) -> [SuperAgentTool] {
        [
            ListAvailableModelsTool(),
            CheckModelAvailabilityTool(),
        ]
    }

    @MainActor
    func sendMiddlewares() -> [AnySuperSendMiddleware] {
        []
    }
}
