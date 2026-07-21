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
        // Register core tools via PluginManagerProvider (AgentToolProviding)
        guard let pluginProvider = kernel.plugin as? (any AgentToolProviding) else { return }
        pluginProvider.add(ListDirectoryTool())
        pluginProvider.add(ReadFileTool())
        pluginProvider.add(WriteFileTool())
        pluginProvider.add(EditFileTool())
        pluginProvider.add(ShellTool())
    }

    public func boot(kernel: LumiKernel) async throws {}
}
