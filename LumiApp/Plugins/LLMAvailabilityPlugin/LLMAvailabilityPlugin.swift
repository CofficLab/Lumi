import os
import AgentToolKit
import SwiftUI

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

    /// 核心基础设施插件，不允许用户禁用

    static let shared = LLMAvailabilityPlugin()

    nonisolated func onRegister() {}
    nonisolated func onEnable() {}
    nonisolated func onDisable() {}

    @MainActor
    func addPosterViews() -> [AnyView] {
        [
            PluginPosterSupport.poster(
                title: "模型可用性检测",
                subtitle: "检测供应商和模型是否可用，并把可用模型列表提供给助手。",
                icon: Self.iconName,
                accent: .cyan,
                metrics: [
                    PluginPosterSupport.metric("Ping", "检测"),
                    PluginPosterSupport.metric("List", "列表"),
                ],
                rows: ["供应商检测", "模型健康检查", "可用模型工具"],
                chips: ["LLM", "模型", "检测"]
            ),
        ]
    }

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
