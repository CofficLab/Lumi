import LumiKernel
import LumiUI
import SwiftUI

@MainActor
public final class ConversationNewPlugin: LumiPlugin {
    public let id = "com.coffic.lumi.plugin.conversation-new"
    public let name = "New Chat Button"
    public let order = 60

    public init() {}

    public func register(kernel: LumiKernel) throws {
        // Services are registered via convenience methods
    }

    public func boot(kernel: LumiKernel) async throws {}
}
