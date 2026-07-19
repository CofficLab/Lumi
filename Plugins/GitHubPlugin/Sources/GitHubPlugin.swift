import LumiKernel
import LumiUI

@MainActor
public final class GitHubPlugin: LumiPlugin {
    public let id = "com.coffic.lumi.plugin.github"
    public let name = "GitHub"
    public let order = 16

    public init() {}

    public func register(kernel: LumiKernel) throws {
        // Register services here
    }

    public func boot(kernel: LumiKernel) async throws {}
}
