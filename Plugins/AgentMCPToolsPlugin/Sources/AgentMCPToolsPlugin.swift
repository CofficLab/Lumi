import LumiCoreKit
import AgentToolKit
import SwiftUI
import os

/// MCP 工具插件：将 MCP 封装成内核可见的 AgentTools（用户无需关心安装/管理）。
public actor AgentMCPToolsPlugin: SuperPlugin {
    public nonisolated static let policy: PluginPolicy = .disabled
    /// 插件专用 Logger
    public nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.mcp-tools")

    public nonisolated static let emoji = "🐘"
    public nonisolated static let verbose: Bool = false
    public static let id = "AgentMCPTools"
    public static let displayName = String(localized: "MCP Tools", bundle: .module)
    public static let description = String(localized: "MCP-backed tools (hidden)", bundle: .module)
    public static let iconName = "server.rack"
    public static var category: PluginCategory { .agent }
    public static var order: Int { 60 }

    public static let shared = AgentMCPToolsPlugin()

    public nonisolated let mcpService = MCPService(
        configs: AgentMCPPluginLocalStore().mcpServerConfigs(forKey: "MCPService_Configs")
    )

    public nonisolated func onRegister() {
        // no-op
    }

    public nonisolated func onEnable() {
        // 暂时禁用自动连接 MCP 服务器，以避免运行时崩溃
    }

    public nonisolated func onDisable() {
        Task {
            await mcpService.disconnectAll()
        }
    }

    @MainActor
    public func agentTools(context: ToolContext) -> [SuperAgentTool] {
        // 当前版本暂不启用 MCP 工具，返回空列表以避免访问未初始化状态导致崩溃
        return []
    }
}

extension Notification.Name {
    public static let toolSourcesDidChange = Notification.Name("toolSourcesDidChange")
}
