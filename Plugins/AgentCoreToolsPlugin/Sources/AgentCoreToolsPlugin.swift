import Foundation
import LumiCoreKit
import AgentToolKit
import os

/// Agent Core Tools 插件
///
/// 将核心工具集从内核硬编码迁移到插件系统，便于增删与组合。
/// 该插件不可配置且默认启用，确保基础工具始终可用。
public actor AgentCoreToolsPlugin: SuperPlugin {
    public nonisolated static let policy: PluginPolicy = .disabled
    public nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.agent-core-tools")
    public static let id: String = "AgentCoreTools"
    public static let displayName: String = String(localized: "Agent Core Tools", table: "AgentCoreTools")
    public static let description: String = String(localized: "提供 Lumi 的基础 Agent 工具（文件/命令）。", table: "AgentCoreTools")
    public static let iconName: String = "wrench.and.screwdriver"
    public static var category: PluginCategory { .agent }
    public static var order: Int { 0 }

    public static let shared = AgentCoreToolsPlugin()

    @MainActor
    public func agentTools(context: ToolContext) -> [SuperAgentTool] {
        [
            ListDirectoryTool(),
            ReadFileTool(),
            WriteFileTool(),
            EditFileTool(),
            ShellTool(),
        ]
    }
}
