import LumiKernel
import LumiUI

@MainActor
public final class TerminalPlugin: LumiPlugin {
    public let id = "com.coffic.lumi.plugin.terminal"
    public let name = "Terminal"
    public let order = 90
public static let policy: LumiPluginPolicy = .disabled

    public init() {}

    public func onReady(kernel: LumiKernel) throws {
        // Register services here
    }

    public func boot(kernel: LumiKernel) async throws {}
}
