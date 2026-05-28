import SwiftUI
import AgentToolKit
import os

/// Agent 规则管理插件
///
/// 提供工具来管理 .agent/rules 目录中的规则文档
actor AgentRulesPlugin: SuperPlugin, SuperLog {
    /// 插件专用 Logger
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.agent-rules")

    nonisolated static let emoji = "📜"
    nonisolated static let verbose: Bool = true
    // MARK: - 插件基本信息

    static let id = "AgentRules"
    static let displayName = String(localized: "Agent Rules", table: "AgentRules")
    static let description = String(localized: "Manage rule documents in .agent/rules directory", table: "AgentRules")
    static let iconName = "doc.text"
    static var category: PluginCategory { .agent }
    static var order: Int { 50 }

    static let shared = AgentRulesPlugin()

    // MARK: - 插件生命周期

    nonisolated func onRegister() {
        if Self.verbose {
            if Self.verbose {
                            Self.logger.info("AgentRulesPlugin 注册")
            }
        }
    }

    nonisolated func onEnable() {
        if Self.verbose {
            if Self.verbose {
                            Self.logger.info("AgentRulesPlugin 启用")
            }
        }
    }

    nonisolated func onDisable() {
        if Self.verbose {
            if Self.verbose {
                            Self.logger.info("AgentRulesPlugin 禁用")
            }
        }
    }

    // MARK: - Agent 工具

    @MainActor
    func addPosterViews() -> [AnyView] {
        [
            PluginPosterSupport.poster(
                title: "Agent Rules",
                subtitle: "管理 .agent/rules 规则文档，并在发送消息时注入规则上下文。",
                icon: Self.iconName,
                accent: .blue,
                metrics: [
                    PluginPosterSupport.metric("Rules", "规则"),
                    PluginPosterSupport.metric("Prompt", "注入"),
                ],
                rows: ["列出规则", "创建规则", "上下文中间件"],
                chips: ["Agent", "规则", "项目"]
            ),
        ]
    }

    @MainActor
    func agentTools(context: ToolContext) -> [SuperAgentTool] {
        [ListAgentRulesTool(), CreateAgentRuleTool()]
    }

    // MARK: - 发送中间件

    @MainActor
    func sendMiddlewares() -> [AnySuperSendMiddleware] {
        [AnySuperSendMiddleware(AgentRulesContextSuperSendMiddleware())]
    }
}
