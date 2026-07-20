import LumiKernel
import LumiUI

@MainActor
public final class AgentOpenInFinderPlugin: LumiPlugin {
    public let id = "com.coffic.lumi.plugin.open-in-finder"
    public let name = "Open in Finder"
    public let order = 61
public static let policy: LumiPluginPolicy = .disabled

    public init() {}

    public func register(kernel: LumiKernel) throws {
        // Register services here
    }

    public func boot(kernel: LumiKernel) async throws {}
}
