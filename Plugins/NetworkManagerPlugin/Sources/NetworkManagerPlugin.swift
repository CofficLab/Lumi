import LumiKernel
import LumiUI

@MainActor
public final class NetworkManagerPlugin: LumiPlugin {
    public let id = "com.coffic.lumi.plugin.network-manager"
    public let name = "Network Monitor"
    public let order = 30
public static let policy: LumiPluginPolicy = .disabled

    public init() {}

    public func onReady(kernel: LumiKernel) throws {
        // Register services here
    }

    public func boot(kernel: LumiKernel) async throws {}
}
