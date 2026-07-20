import LumiKernel
import LumiUI

@MainActor
public final class WebSearchPlugin: LumiPlugin {
    public let id = "WebSearch"
    public let name = "WebSearch"
    public let order = 101
public static let policy: LumiPluginPolicy = .disabled

    public init() {}

    public func register(kernel: LumiKernel) throws {
        // Register services here
    }

    public func boot(kernel: LumiKernel) async throws {}
}
