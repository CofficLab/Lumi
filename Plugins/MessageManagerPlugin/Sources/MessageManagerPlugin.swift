import Foundation
import LumiKernel

/// Message Manager Plugin
///
/// Implements MessageManaging protocol with mock data for testing.
@MainActor
public final class MessageManagerPlugin: LumiPlugin {
    public let id = "com.coffic.lumi.plugin.message-manager"
    public let name = "Message Manager"
    public let order = 62  // After ConversationManagerPlugin

    public init() {}

    public func register(kernel: LumiKernel) throws {
        let service = MessageManager(kernel: kernel)
        kernel.registerMessageManager(service)
    }

    public func boot(kernel: LumiKernel) async throws {}
}
