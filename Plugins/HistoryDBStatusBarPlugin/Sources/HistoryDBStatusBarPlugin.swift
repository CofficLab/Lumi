import LumiKernel
import LumiUI

@MainActor
public final class HistoryDBStatusBarPlugin: LumiPlugin {
    public let id = "com.coffic.lumi.plugin.history-db-status-bar"
    public let name = "History Database Browser"
    public let order = 98
public static let policy: LumiPluginPolicy = .disabled

    public init() {}

    public func onReady(kernel: LumiKernel) throws {
        // Register services here
    }

    public func boot(kernel: LumiKernel) async throws {}
}
