import LumiKernel
import LumiUI
import SwiftUI

@MainActor
public final class ConversationTimelinePlugin: LumiPlugin {
    public let id = "com.coffic.lumi.plugin.conversation-timeline"
    public let name = "Conversation Timeline"
    public let order = 82
public static let policy: LumiPluginPolicy = .disabled

    public init() {}

    public func register(kernel: LumiKernel) throws {
        // Services are registered via convenience methods
    }

    public func boot(kernel: LumiKernel) async throws {}
}
