import LumiCoreAgentTool
import LumiKernel
import LumiUI

@MainActor
public final class ToolCorePlugin: LumiPlugin {
    public let id = "com.coffic.lumi.plugin.tool-core"
    public let name = "Tool Core"
    public let order = 0
    public static let policy: LumiPluginPolicy = .alwaysOn

    public init() {}

    public func register(kernel: LumiKernel) throws {
        // Register core tools via AgentTool service
        guard let agentTool = kernel.agentTool else { return }
        agentTool.add(ListDirectoryTool())
        agentTool.add(ReadFileTool())
        agentTool.add(WriteFileTool())
        agentTool.add(EditFileTool())
        agentTool.add(ShellTool())
    }

    public func boot(kernel: LumiKernel) async throws {}
}
