import LumiKernel
import LumiUI

@MainActor
public final class Plugin: LumiPlugin {
    public let id = "com.coffic.lumi.plugin.goal-task"
    public let name = ""
    public let order = 91
public static let policy: LumiPluginPolicy = .disabled

    public init() {}

    public func onReady(kernel: LumiKernel) throws {
        // Register services here
    }

    public func boot(kernel: LumiKernel) async throws {}
}
