import LumiKernel
import LumiUI

@MainActor
public final class GitHubPlugin: LumiPlugin {
    public let id = "com.coffic.lumi.plugin.github"
    public let name = "GitHub"
    public let order = 16
public static let policy: LumiPluginPolicy = .disabled

    public init() {}

    public func onReady(kernel: LumiKernel) throws {
        // Register services here
    }

    public func boot(kernel: LumiKernel) async throws {}
}
