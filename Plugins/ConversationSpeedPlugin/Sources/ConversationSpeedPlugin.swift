import LumiKernel
import LumiUI
import SuperLogKit
import os

@MainActor
public final class ConversationSpeedPlugin: LumiPlugin, SuperLog {
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.conversationspeed")
    nonisolated public static let emoji = "⚡"
    nonisolated static let verbose = true

    public let id = "com.coffic.lumi.plugin.conversation-speed"
    public let name = "ConversationSpeed"
    public let order = 86
    public static let policy: LumiPluginPolicy = .alwaysOn

    public init() {}

    public func onReady(kernel: LumiKernel) throws {
        if Self.verbose {
            Self.logger.info("\(Self.t)ConversationSpeedPlugin onReady")
        }
    }

    public func boot(kernel: LumiKernel) async throws {
        if Self.verbose {
            Self.logger.info("\(Self.t)ConversationSpeedPlugin boot")
        }
    }

    // MARK: - Chat Section Toolbar Bar

    public func chatSectionToolbarBarItems(kernel: LumiKernel) -> [ChatSectionToolbarBarItem] {
        if Self.verbose {
            Self.logger.info("\(Self.t)chatSectionToolbarBarItems called")
        }
        let items = [
            ChatSectionToolbarBarItem(id: id) {
                ConversationSpeedToolbarView(kernel: kernel)
            }
        ]
        if Self.verbose {
            Self.logger.info("\(Self.t)Returning \(items.count) toolbar bar items")
        }
        return items
    }
}
