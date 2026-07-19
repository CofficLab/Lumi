import LumiKernel
import LumiUI

@MainActor
public final class DatabaseManagerPlugin: LumiPlugin {
    public let id = "com.coffic.lumi.plugin.database-manager"
    public let name = "Database"
    public let order = 50

    public init() {}

    public func register(kernel: LumiKernel) throws {
        // Register services here
    }

    public func boot(kernel: LumiKernel) async throws {}
}
