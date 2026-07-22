import LumiKernel
import LumiUI

@MainActor
public final class AppStoreConnectPlugin: LumiPlugin {
    public let id = "com.coffic.lumi.plugin.app-store-connect"
    public let name = "AppStoreConnect"
    public let order = 65
public static let policy: LumiPluginPolicy = .disabled

    public init() {}

    public func onReady(kernel: LumiKernel) throws {
        // Register services here
    }

    public func boot(kernel: LumiKernel) async throws {}
}
