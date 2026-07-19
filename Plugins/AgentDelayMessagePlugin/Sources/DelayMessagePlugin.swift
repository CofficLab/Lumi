import LumiKernel
import LumiUI

@MainActor
public final class DelayMessagePlugin: LumiPlugin {
    public let id = "com.coffic.lumi.plugin.delay-message"
    public let name = "Delay Message"
    public let order = 98

    public init() {}

    public func register(kernel: LumiKernel) throws {
        // Register services here
    }

    public func boot(kernel: LumiKernel) async throws {}
}
