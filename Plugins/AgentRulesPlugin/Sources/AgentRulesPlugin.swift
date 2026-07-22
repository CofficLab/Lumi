import LumiKernel
import LumiUI

@MainActor
public final class AgentRulesPlugin: LumiPlugin {
    public let id = "com.coffic.lumi.plugin.agent-rules"
    public let name = "Agent Rules"
    public let order = 50
public static let policy: LumiPluginPolicy = .disabled

    public init() {}

    public func onReady(kernel: LumiKernel) throws {
        // Register services here
    }

    public func boot(kernel: LumiKernel) async throws {}
}
