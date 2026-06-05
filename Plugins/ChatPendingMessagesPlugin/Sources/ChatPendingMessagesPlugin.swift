import LumiCoreKit
import SuperLogKit
import SwiftUI
import os

/// 聊天待发送消息插件
///
/// 负责在输入框上方展示已进入发送队列但尚未开始处理的消息。
public actor ChatPendingMessagesPlugin: SuperPlugin, SuperLog {
    public nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.chat-pending-messages")

    public nonisolated static let emoji = "📋"
    public nonisolated static let verbose: Bool = true
    public nonisolated static let policy: PluginPolicy = .alwaysOn

    public static let id = "ChatPendingMessages"
    public static let displayName = String(localized: "Chat Pending Messages", bundle: .module)
    public static let description = String(localized: "Show queued chat messages above the input area", bundle: .module)
    public static let iconName = "clock"
    public static var category: PluginCategory { .agent }
    public static var order: Int { 95 }
    public static let shared = ChatPendingMessagesPlugin()

    // MARK: - Lifecycle

    public nonisolated func onRegister() {}
    public nonisolated func onEnable() {}
    public nonisolated func onDisable() {}

    // MARK: - UI Contributions

    @MainActor public func addSidebarSections(context: PluginContext) -> [AnyView] {
        guard context.showChat else { return [] }
        return [AnyView(PendingMessagesView())]
    }
}
