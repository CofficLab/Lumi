import LumiKernel
import LumiUI

@MainActor
public final class AgentTurnNotificationPlugin: LumiPlugin {
    public let id = "com.coffic.lumi.plugin.turn-notification"
    public let name = "Turn Notification"
    public let order = 99
public static let policy: LumiPluginPolicy = .disabled

    public init() {}

    public func onReady(kernel: LumiKernel) throws {
        // Register services here
    }

    public func boot(kernel: LumiKernel) async throws {}
}
