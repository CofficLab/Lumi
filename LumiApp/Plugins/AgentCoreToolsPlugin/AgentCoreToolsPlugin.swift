import Foundation
import MagicKit

/// Agent Core Tools 插件
///
/// 将核心工具集从内核硬编码迁移到插件系统，便于增删与组合。
/// 该插件不可配置且默认启用，确保基础工具始终可用。
actor AgentCoreToolsPlugin: SuperPlugin {
    static let id: String = "AgentCoreTools"
    static let displayName: String = "Agent Core Tools"
    static let description: String = "提供 Lumi 的基础 Agent 工具（文件/命令）。"
    static let iconName: String = "wrench.and.screwdriver"
    static let isConfigurable: Bool = false
    static let enable: Bool = true
    static var order: Int { 0 }

    static let shared = AgentCoreToolsPlugin()

    @MainActor
    func agentToolFactories() -> [AnyAgentToolFactory] {
        [AnyAgentToolFactory(CoreToolsFactory())]
    }

    @MainActor
    func toolPresentationDescriptors() -> [ToolPresentationDescriptor] {
        [
            .init(toolName: "ls", displayName: "列出目录", emoji: "📁", category: .listDirectory, order: 0),
            .init(toolName: "read_file", displayName: "读取文件", emoji: "📖", category: .readFile, order: 10),
            .init(toolName: "write_file", displayName: "写入文件", emoji: "✍️", category: .writeFile, order: 20),
            .init(toolName: "run_command", displayName: "Shell 命令", emoji: "⚡", category: .shell, order: 30),
        ]
    }
}

@MainActor
private struct CoreToolsFactory: AgentToolFactory {
    let id: String = "core.tools.factory"
    let order: Int = 0

    func makeTools(env: AgentToolEnvironment) -> [AgentTool] {
        [
            ListDirectoryTool(),
            ReadFileTool(),
            WriteFileTool(),
            ShellTool(),
        ]
    }
}

