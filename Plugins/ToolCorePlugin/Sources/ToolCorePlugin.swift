import LumiKernel
import LumiKernel
import LumiUI
import os

@MainActor
public final class ToolCorePlugin: LumiPlugin {
    public let id = "com.coffic.lumi.plugin.tool-core"
    public let name = "Tool Core"
    public let order = 35  // After AgentToolPlugin (order = 30)
    public static let policy: LumiPluginPolicy = .alwaysOn

    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.tool-core")
    nonisolated static let emoji = "🔧"

    public init() {}

    public func register(kernel: LumiKernel) throws {
        // Register tools via kernel.agentTool (AgentToolService)
        guard let agentTool = kernel.agentTool else {
            Self.logger.error("ToolCorePlugin.register: kernel.agentTool is nil")
            return
        }

        Self.logger.info("ToolCorePlugin.register: Adding 5 core tools...")
        agentTool.add(ListDirectoryTool())
        agentTool.add(ReadFileTool())
        agentTool.add(WriteFileTool())
        agentTool.add(EditFileTool())
        agentTool.add(ShellTool())

        let tools = agentTool.allAgentTools()
        Self.logger.info("ToolCorePlugin.register: Total tools now = \(tools.count)")
    }

    public func boot(kernel: LumiKernel) async throws {
        Self.logger.info("ToolCorePlugin.boot called")
    }
}
