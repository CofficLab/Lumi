import LumiKernel
import LumiUI

@MainActor
public final class CaffeinatePlugin: LumiPlugin {
    public let id = "Caffeinate"
    public let name = "Caffeinate"
    public let order = 1

    public init() {}

    public func register(kernel: LumiKernel) throws {
        // Register services here
    }

    public func boot(kernel: LumiKernel) async throws {}
}
