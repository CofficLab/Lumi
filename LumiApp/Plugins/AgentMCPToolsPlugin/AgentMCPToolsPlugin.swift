import MagicKit
import SwiftUI
import os

/// MCP 工具插件：将 MCP 封装成内核可见的 AgentTools（用户无需关心安装/管理）。
actor AgentMCPToolsPlugin: SuperPlugin {
    /// 插件专用 Logger
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.mcp-tools")

    nonisolated static let emoji = "🐘"
    nonisolated static let verbose: Bool = false
    static let id = "AgentMCPTools"
    static let displayName = String(localized: "MCP Tools", table: "AgentMCPTools")
    static let description = String(localized: "MCP-backed tools (hidden)", table: "AgentMCPTools")
    static let iconName = "server.rack"
    static var order: Int { 60 }
    static let enable: Bool = true

    static let shared = AgentMCPToolsPlugin()

    nonisolated let mcpService = MCPService()

    nonisolated func onRegister() {
        // no-op
    }

    nonisolated func onEnable() {
        // 暂时禁用自动连接 MCP 服务器，以避免运行时崩溃
    }

    nonisolated func onDisable() {}

    @MainActor
    func agentTools() -> [AgentTool] {
        // 当前版本暂不启用 MCP 工具，返回空列表以避免访问未初始化状态导致崩溃
        return []
    }
}

extension Notification.Name {
    static let toolSourcesDidChange = Notification.Name("toolSourcesDidChange")
}