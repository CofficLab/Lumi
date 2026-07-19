import LumiKernel
import LumiUI
import SwiftUI

@MainActor
public final class ConversationTurnDurationPlugin: LumiPlugin {
    public let id = "com.coffic.lumi.plugin.conversation-turn-duration"
    public let name = "Turn Duration"
    public let order = 86

    public init() {}

    public func register(kernel: LumiKernel) throws {
        // Services are registered via convenience methods
    }

    public func boot(kernel: LumiKernel) async throws {}
}
