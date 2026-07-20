import LumiKernel
import LumiUI

@MainActor
public final class WebFetchPlugin: LumiPlugin {
    public let id = "WebFetch"
    public let name = "WebFetch"
    public let order = 100
public static let policy: LumiPluginPolicy = .disabled

    public init() {}

    public func register(kernel: LumiKernel) throws {
        // Register services here
    }

    public func boot(kernel: LumiKernel) async throws {}
}
