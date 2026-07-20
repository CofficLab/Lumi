import LumiKernel
import LumiUI

@MainActor
public final class IdleTimePlugin: LumiPlugin {
    public let id = "com.coffic.lumi.plugin.idle-time"
    public let name = "Idle Time"
    public let order = 96

    public var policy: LumiPluginPolicy { .disabled }

    public init() {}

    public func register(kernel: LumiKernel) throws {
        // Register services here
    }

    public func boot(kernel: LumiKernel) async throws {}
}
