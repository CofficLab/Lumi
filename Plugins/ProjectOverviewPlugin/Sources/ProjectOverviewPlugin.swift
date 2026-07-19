import LumiKernel
import LumiUI

@MainActor
public final class ProjectOverviewPlugin: LumiPlugin {
    public let id = "ProjectOverview"
    public let name = "ProjectOverview"
    public let order = 14

    public init() {}

    public func register(kernel: LumiKernel) throws {
        // Register services here
    }

    public func boot(kernel: LumiKernel) async throws {}
}
