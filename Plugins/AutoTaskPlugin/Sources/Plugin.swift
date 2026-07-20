import LumiKernel
import LumiUI

@MainActor
public final class Plugin: LumiPlugin {
    public let id = "com.coffic.lumi.plugin.auto-task"
    public let name = "Auto Task (Deprecated)"
    public let order = 90

    public var policy: LumiPluginPolicy { .disabled }

    public init() {}

    public func register(kernel: LumiKernel) throws {
        // Register services here
    }

    public func boot(kernel: LumiKernel) async throws {}
}
