import LumiKernel
import LumiUI

@MainActor
public final class AgentTempStoragePlugin: LumiPlugin {
    public let id = "com.coffic.lumi.plugin.agent-temp-storage"
    public let name = "Agent Temp Storage"
    public let order = 80

    public init() {}

    public func register(kernel: LumiKernel) throws {
        // Register services here
    }

    public func boot(kernel: LumiKernel) async throws {}
}
