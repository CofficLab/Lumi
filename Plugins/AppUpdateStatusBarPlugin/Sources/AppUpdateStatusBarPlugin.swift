import LumiKernel
import LumiUI

@MainActor
public final class AppUpdateStatusBarPlugin: LumiPlugin {
    public let id = "com.coffic.lumi.plugin.app-update-status-bar"
    public let name = "AppUpdateStatusBar"
    public let order = 8
public static let policy: LumiPluginPolicy = .disabled

    public init() {}

    public func register(kernel: LumiKernel) throws {
        // Register services here
    }

    public func boot(kernel: LumiKernel) async throws {}
}
