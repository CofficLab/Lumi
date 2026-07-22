import LumiKernel
import LumiUI

@MainActor
public final class ProjectOverviewPlugin: LumiPlugin {
    public let id = "ProjectOverview"
    public let name = "ProjectOverview"
    public let order = 14
public static let policy: LumiPluginPolicy = .disabled

    public init() {}

    public func onReady(kernel: LumiKernel) throws {
        // Register services here
    }

    public func boot(kernel: LumiKernel) async throws {}
}
