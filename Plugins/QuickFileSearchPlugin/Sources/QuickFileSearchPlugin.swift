import LumiKernel
import LumiUI

@MainActor
public final class QuickFileSearchPlugin: LumiPlugin {
    public let id = "QuickFileSearch"
    public let name = "Quick File Search"
    public let order = 50

    public init() {}

    public func register(kernel: LumiKernel) throws {
        // Register services here
    }

    public func boot(kernel: LumiKernel) async throws {}
}
