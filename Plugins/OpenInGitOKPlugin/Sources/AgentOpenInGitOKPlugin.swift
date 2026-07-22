import LumiKernel
import LumiUI

@MainActor
public final class AgentOpenInGitOKPlugin: LumiPlugin {
    public let id = "com.coffic.lumi.plugin.open-in-gitok"
    public let name = "Open in GitOK"
    public let order = 98
public static let policy: LumiPluginPolicy = .disabled

    public init() {}

    public func onReady(kernel: LumiKernel) throws {
        // Register services here
    }

    public func boot(kernel: LumiKernel) async throws {}
}
