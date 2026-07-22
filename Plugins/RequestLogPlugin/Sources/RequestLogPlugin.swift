import LumiKernel
import LumiUI

@MainActor
public final class RequestLogPlugin: LumiPlugin {
    public let id = "com.coffic.lumi.plugin.request-log"
    public let name = "PluginName"
    public let order = 100
public static let policy: LumiPluginPolicy = .disabled

    public init() {}

    public func onReady(kernel: LumiKernel) throws {
        // Register services here
    }

    public func boot(kernel: LumiKernel) async throws {}
}
