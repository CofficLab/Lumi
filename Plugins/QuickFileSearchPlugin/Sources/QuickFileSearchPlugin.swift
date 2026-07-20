import LumiKernel
import LumiUI

@MainActor
public final class QuickFileSearchPlugin: LumiPlugin {
    public let id = "QuickFileSearch"
    public let name = "Quick File Search"
    public let order = 50
public static let policy: LumiPluginPolicy = .disabled

    public init() {}

    public func register(kernel: LumiKernel) throws {
        // Register services here
    }

    public func boot(kernel: LumiKernel) async throws {}
}
