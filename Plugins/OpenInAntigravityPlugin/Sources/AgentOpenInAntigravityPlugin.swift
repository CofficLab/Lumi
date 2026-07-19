import LumiKernel
import LumiUI

@MainActor
public final class AgentOpenInAntigravityPlugin: LumiPlugin {
    public let id = "com.coffic.lumi.plugin.open-in-antigravity"
    public let name = "Open in Antigravity"
    public let order = 83

    public init() {}

    public func register(kernel: LumiKernel) throws {
        // Register services here
    }

    public func boot(kernel: LumiKernel) async throws {}
}
