import LumiCoreKit
import SuperLogKit
import SwiftUI
import os

/// 聊天待发送消息插件
///
/// 负责在输入框上方展示已进入发送队列但尚未开始处理的消息。
public actor ChatPendingMessagesPlugin: LumiPlugin, SuperLog {
    public nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.chat-pending-messages")

    public nonisolated static let emoji = "📋"
    public nonisolated static let verbose: Bool = true
    public static let policy: LumiPluginPolicy = .alwaysOn

    public static let id = "ChatPendingMessages"
    public static let displayName = LumiPluginLocalization.string("Chat Pending Messages", bundle: .module)
    public static let description = LumiPluginLocalization.string("Show queued chat messages above the input area", bundle: .module)
    public static let iconName = "clock"
    public static let category: LumiPluginCategory = .agent
    public static let order = 95

    public nonisolated var instanceLabel: String { Self.id }

    public nonisolated func onRegister() {}
    public nonisolated func onEnable() {}
    public nonisolated func onDisable() {}

    @MainActor
    public func addSidebarSections(context: PluginContext) -> [AnyView] {
        guard context.showChat.isVisible else { return [] }
        return [AnyView(PendingMessagesView())]
    }
}
