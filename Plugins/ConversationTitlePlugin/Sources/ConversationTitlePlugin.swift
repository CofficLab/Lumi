import LumiKernel
import LumiKernel
import SuperLogKit
import os

@MainActor
public final class ConversationTitlePlugin: LumiPlugin, SuperLog {
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.conversation-title")
    nonisolated public static let emoji = "✏️"
    public static let verbose = false

    public let id = "com.coffic.lumi.plugin.conversation-title"
    public let name = "Conversation Title"
    public let order = 77
    public static let policy: LumiPluginPolicy = .alwaysOn

    public init() {}

    public func register(kernel: LumiKernel) throws {
        if Self.verbose {
            Self.logger.info("\(Self.t)Registered conversation title header")
        }
    }

    public func boot(kernel: LumiKernel) async throws {}

    public func chatSectionHeaderItems(kernel: LumiKernel) -> [ChatSectionHeaderItem] {
        if Self.verbose {
            Self.logger.info("\(Self.t)Providing chat section header item")
        }
        return [
            ChatSectionHeaderItem(id: id) {
                ConversationTitleHeaderView(kernel: kernel)
            }
        ]
    }
}
