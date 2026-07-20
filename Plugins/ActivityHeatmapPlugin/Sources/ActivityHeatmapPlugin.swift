import LumiKernel
import LumiUI

@MainActor
public final class ActivityHeatmapPlugin: LumiPlugin {
    public let id = "com.coffic.lumi.plugin.activity-heatmap"
    public let name = "Activity Heatmap"
    public let order = 60
public static let policy: LumiPluginPolicy = .disabled

    public init() {}

    public func register(kernel: LumiKernel) throws {
        // Register services here
    }

    public func boot(kernel: LumiKernel) async throws {}
}
