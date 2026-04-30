import SwiftUI
import MagicKit
import os

/// Agent 规则管理插件
///
/// 提供工具来管理 .agent/rules 目录中的规则文档
actor AgentRulesPlugin: SuperPlugin, SuperLog {
    /// 插件专用 Logger
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.agent-rules")

    nonisolated static let emoji = "📜"
    nonisolated static let verbose: Bool = false
    // MARK: - 插件基本信息

    static let id = "AgentRules"
    static let displayName = String(localized: "Agent Rules", table: "AgentRules")
    static let description = String(localized: "Manage rule documents in .agent/rules directory", table: "AgentRules")
    static let iconName = "doc.text"
    static var order: Int { 50 }
    static let enable: Bool = true
    static let isConfigurable: Bool = false

    static let shared = AgentRulesPlugin()

    // MARK: - 插件生命周期

    nonisolated func onRegister() {
        if Self.verbose {
            Self.logger.info("AgentRulesPlugin 注册")
        }
    }

    nonisolated func onEnable() {
        if Self.verbose {
            Self.logger.info("AgentRulesPlugin 启用")
        }
    }

    nonisolated func onDisable() {
        if Self.verbose {
            Self.logger.info("AgentRulesPlugin 禁用")
        }
    }

    // MARK: - Agent 工具

    @MainActor
    func agentToolFactories() -> [AnySuperAgentToolFactory] {
        [AnySuperAgentToolFactory(AgentRulesToolFactory())]
    }

    // MARK: - 发送中间件

    @MainActor
    func sendMiddlewares() -> [AnySuperSendMiddleware] {
        [AnySuperSendMiddleware(AgentRulesContextSuperSendMiddleware())]
    }
}

// MARK: - 工具工厂

@MainActor
private struct AgentRulesToolFactory: SuperAgentToolFactory {
    let id: String = "agent-rules.factory"
    let order: Int = 0

    func makeTools(env: SuperAgentToolEnvironment) -> [AgentTool] {
        [
            ListAgentRulesTool(),
            CreateAgentRuleTool()
        ]
    }
}
