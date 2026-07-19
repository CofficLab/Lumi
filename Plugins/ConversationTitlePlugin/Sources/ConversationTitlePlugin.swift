import LumiKernel
import LumiUI
import SwiftUI

@MainActor
public final class ConversationTitlePlugin: LumiPlugin {
    public let id = "com.coffic.lumi.plugin.conversation-title"
    public let name = "Auto Conversation Title"
    public let order = 77

    public init() {}

    public func register(kernel: LumiKernel) throws {
        // Services are registered via convenience methods
    }

    public func boot(kernel: LumiKernel) async throws {}
}
