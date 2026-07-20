import LumiKernel
import LumiUI

@MainActor
public final class MessageListPlugin: LumiPlugin {
    public let id = "com.coffic.lumi.plugin.chat-messages-section"
    public let name = "Chat Messages"
    public let order = 82
public static let policy: LumiPluginPolicy = .disabled

    public init() {}

    public func register(kernel: LumiKernel) throws {
        // Register services here
    }

    public func boot(kernel: LumiKernel) async throws {}
}
