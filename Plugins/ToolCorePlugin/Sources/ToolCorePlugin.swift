import LumiKernel
import LumiUI

@MainActor
public final class ToolCorePlugin: LumiPlugin {
    public let id = "ToolCore"
    public let name = "Tool Core"
    public let order = 0
public static let policy: LumiPluginPolicy = .disabled

    public init() {}

    public func register(kernel: LumiKernel) throws {
        // Register services here
    }

    public func boot(kernel: LumiKernel) async throws {}
}
