import LumiCoreKit
import SwiftUI
import os

/// 聊天待发送消息插件
///
/// 负责在输入框上方展示已进入发送队列但尚未开始处理的消息。
actor ChatPendingMessagesPlugin: SuperPlugin, SuperLog {
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.chat-pending-messages")

    nonisolated static let emoji = "📋"
    nonisolated static let verbose: Bool = true
    static let id = "ChatPendingMessages"
    static let displayName = String(localized: "Chat Pending Messages", table: "AgentChat")
    static let description = String(localized: "Show queued chat messages above the input area", table: "AgentChat")
    static let iconName = "clock"
    static var category: PluginCategory { .agent }
    static var order: Int { 95 }
    static let shared = ChatPendingMessagesPlugin()

    // MARK: - Lifecycle

    nonisolated func onRegister() {}
    nonisolated func onEnable() {}
    nonisolated func onDisable() {}

    // MARK: - UI Contributions

    @MainActor func addSidebarSections(context: PluginContext) -> [AnyView] {
        guard context.supportsAIChat else { return [] }
        return [AnyView(PendingMessagesView())]
    }
}
