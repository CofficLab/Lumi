import LumiKernel
import LumiUI

@MainActor
public final class AgentOpenInXcodePlugin: LumiPlugin {
    public let id = "com.coffic.lumi.plugin.open-in-xcode"
    public let name = "Open in Xcode"
    public let order = 95

    public init() {}

    public func register(kernel: LumiKernel) throws {
        // Register services here
    }

    public func boot(kernel: LumiKernel) async throws {}
}
