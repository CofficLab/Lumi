import LumiKernel
import LumiUI

@MainActor
public final class AgentOpenInGitHubDesktopPlugin: LumiPlugin {
    public let id = "com.coffic.lumi.plugin.open-in-github-desktop"
    public let name = "Open in GitHub Desktop"
    public let order = 97

    public init() {}

    public func register(kernel: LumiKernel) throws {
        // Register services here
    }

    public func boot(kernel: LumiKernel) async throws {}
}
