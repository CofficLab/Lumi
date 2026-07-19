import LumiKernel
import LumiUI

@MainActor
public final class ChatPanelPlugin: LumiPlugin {
    public let id = "\(info.id).timeline"
    public let name = "Chat"
    public let order = 78

    public init() {}

    public func register(kernel: LumiKernel) throws {
        // Register services here
    }

    public func boot(kernel: LumiKernel) async throws {}
}
