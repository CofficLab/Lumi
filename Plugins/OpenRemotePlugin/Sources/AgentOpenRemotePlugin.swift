import LumiKernel
import LumiUI

@MainActor
public final class AgentOpenRemotePlugin: LumiPlugin {
    public let id = "com.coffic.lumi.plugin.open-remote"
    public let name = "Open Remote"
    public let order = 62

    public init() {}

    public func register(kernel: LumiKernel) throws {
        // Register services here
    }

    public func boot(kernel: LumiKernel) async throws {}
}
