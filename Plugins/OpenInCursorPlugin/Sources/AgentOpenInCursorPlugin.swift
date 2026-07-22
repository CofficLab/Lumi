import LumiKernel
import LumiUI

@MainActor
public final class AgentOpenInCursorPlugin: LumiPlugin {
    public let id = "com.coffic.lumi.plugin.open-in-cursor"
    public let name = "Open in Cursor"
    public let order = 60
public static let policy: LumiPluginPolicy = .disabled

    public init() {}

    public func onReady(kernel: LumiKernel) throws {
        // Register services here
    }

    public func boot(kernel: LumiKernel) async throws {}
}
