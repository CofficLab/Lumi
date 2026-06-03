import LumiCoreKit
import SuperLogKit
import SwiftUI
import os

/// Agent 聊天插件
///
/// 负责右侧栏的消息列表 Section，显示当前会话的聊天消息时间线。
public actor AgentChatPlugin: SuperPlugin, SuperLog {
    /// 插件专用 Logger
    public nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.agent-chat")

    public nonisolated static let emoji = "💬"
    public nonisolated static let verbose: Bool = true
    public static let id = "AgentChat"
    public static let displayName = String(localized: "Agent Chat", bundle: .module)
    public static let description = String(localized: "Agent chat messages timeline", bundle: .module)
    public static let iconName = "text.bubble.fill"
    public static var category: PluginCategory { .agent }
    public static var order: Int { 82 }
    public nonisolated static let policy: PluginPolicy = .alwaysOn
    public static let shared = AgentChatPlugin()

    // MARK: - Lifecycle

    public nonisolated func onRegister() {
        // Init
    }

    public nonisolated func onEnable() {
        // Init
    }

    public nonisolated func onDisable() {
        // Cleanup
    }

    // MARK: - UI Contributions

    /// 右侧栏 Section：消息列表
    @MainActor public func addSidebarSections(context: PluginContext) -> [AnyView] {
        guard context.supportsAIChat else { return [] }
        return [AnyView(ChatMessagesView(messageRenderer: context.messageRenderer))]
    }
}
