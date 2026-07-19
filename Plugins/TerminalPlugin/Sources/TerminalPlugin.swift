import LumiKernel
import LumiUI

@MainActor
public final class TerminalPlugin: LumiPlugin {
    public let id = "com.coffic.lumi.plugin.terminal"
    public let name = "Terminal"
    public let order = 90

    public init() {}

    public func register(kernel: LumiKernel) throws {
        // Register services here
    }

    public func boot(kernel: LumiKernel) async throws {}
}
