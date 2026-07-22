import LumiKernel
import LumiUI

@MainActor
public final class ChatModePlugin: LumiPlugin {
    public let id = "com.coffic.lumi.plugin.chat-mode"
    public let name = "Chat Mode"
    public let order = 84
public static let policy: LumiPluginPolicy = .disabled

    public init() {}

    public func onReady(kernel: LumiKernel) throws {
        // Register services here
    }

    public func boot(kernel: LumiKernel) async throws {}
}
