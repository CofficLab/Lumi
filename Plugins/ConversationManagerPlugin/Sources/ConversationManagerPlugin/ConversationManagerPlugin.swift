import Foundation
import LumiKernel
import SuperLogKit
import os

/// Conversation Manager Plugin
///
/// Implements ConversationManaging protocol with mock data for testing.
@MainActor
public final class ConversationManagerPlugin: LumiPlugin, SuperLog {
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.conversation-manager")
    nonisolated public static let emoji = "💬"
    public static let verbose = false

    // MARK: - LumiPlugin

    public let id = "com.coffic.lumi.plugin.conversation-manager"
    public let name = "Conversation Manager"
    public let order = 61

    // MARK: - Initialization

    public init() {}

    // MARK: - LumiPlugin

    public func register(kernel: LumiKernel) throws {
        let service = MockConversationManager()
        kernel.registerConversations(service)
        if Self.verbose {
            Self.logger.info("\(Self.t)已注册 MockConversationManager")
        }
    }

    public func boot(kernel: LumiKernel) async throws {
        // No additional boot logic needed
    }
}
