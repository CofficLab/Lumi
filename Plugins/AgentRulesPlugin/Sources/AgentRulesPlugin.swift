import SwiftUI
import LumiCoreKit
import SuperLogKit
import AgentToolKit
import os
import LumiUI

/// Agent 规则管理插件
///
/// 提供工具来管理 .agent/rules 目录中的规则文档
public actor AgentRulesPlugin: SuperPlugin, SuperLog {
    public nonisolated static let policy: PluginPolicy = .disabled
    /// 插件专用 Logger
    public nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.agent-rules")

    public nonisolated static let emoji = "📜"
    public nonisolated static let verbose: Bool = false
    // MARK: - 插件基本信息

    public static let id = "AgentRules"
    public static let displayName = String(localized: "Agent Rules", bundle: .module)
    public static let description = String(localized: "Manage rule documents in .agent/rules directory", bundle: .module)
    public static let iconName = "doc.text"
    public static var category: PluginCategory { .agent }
    public static var order: Int { 50 }

    public static let shared = AgentRulesPlugin()

    // MARK: - 插件生命周期

    public nonisolated func onRegister() {
        if Self.verbose {
            if Self.verbose {
                            Self.logger.info("AgentRulesPlugin 注册")
            }
        }
    }

    public nonisolated func onEnable() {
        if Self.verbose {
            if Self.verbose {
                            Self.logger.info("AgentRulesPlugin 启用")
            }
        }
    }

    public nonisolated func onDisable() {
        if Self.verbose {
            if Self.verbose {
                            Self.logger.info("AgentRulesPlugin 禁用")
            }
        }
    }

    // MARK: - Agent 工具

    @MainActor
    public func addPosterViews() -> [AnyView] {
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
    public func agentTools(context: ToolContext) -> [SuperAgentTool] {
        [ListAgentRulesTool(), CreateAgentRuleTool()]
    }

    // MARK: - 发送中间件

    @MainActor
    public func sendMiddlewares() -> [AnySuperSendMiddleware] {
        [AnySuperSendMiddleware(AgentRulesContextSuperSendMiddleware())]
    }
}
