import LumiKernel
import LumiUI

@MainActor
public final class MemoryPlugin: LumiPlugin {
    public let id = "com.coffic.lumi.plugin.memory"
    public let name = "Memory"
    public let order = 15
public static let policy: LumiPluginPolicy = .disabled

    public init() {}

    public func register(kernel: LumiKernel) throws {
        // Register services here
    }

    public func boot(kernel: LumiKernel) async throws {}
}
