import LumiKernel
import LumiUI
import SwiftUI

@MainActor
public final class ConversationForkPlugin: LumiPlugin {
    public let id = "com.coffic.lumi.plugin.conversation-fork"
    public let name = "Continue in New Chat"
    public let order = 61
public static let policy: LumiPluginPolicy = .disabled

    public init() {}

    public func register(kernel: LumiKernel) throws {
        // Services are registered via convenience methods
    }

    public func boot(kernel: LumiKernel) async throws {}
}
