import Foundation
import MagicKit
import os

/// Agent Core Tools 插件
///
/// 将核心工具集从内核硬编码迁移到插件系统，便于增删与组合。
/// 该插件不可配置且默认启用，确保基础工具始终可用。
actor AgentCoreToolsPlugin: SuperPlugin {
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.agent-core-tools")
    static let id: String = "AgentCoreTools"
    static let displayName: String = String(localized: "Agent Core Tools", table: "AgentCoreTools")
    static let description: String = String(localized: "提供 Lumi 的基础 Agent 工具（文件/命令）。", table: "AgentCoreTools")
    static let iconName: String = "wrench.and.screwdriver"
    static let isConfigurable: Bool = false
    static let enable: Bool = true
    static var order: Int { 0 }

    static let shared = AgentCoreToolsPlugin()

    @MainActor
    func agentToolFactories() -> [AnyAgentToolFactory] {
        [AnyAgentToolFactory(CoreToolsFactory())]
    }
}

@MainActor
private struct CoreToolsFactory: AgentToolFactory {
    let id: String = "core.tools.factory"
    let order: Int = 0

    func makeTools(env: AgentToolEnvironment) -> [AgentTool] {
        [
            // 文件系统工具
            ListDirectoryTool(),
            ReadFileTool(),
            WriteFileTool(),
            EditFileTool(),
            GlobTool(),
            // 命令执行
            ShellTool(),
        ]
    }
}
