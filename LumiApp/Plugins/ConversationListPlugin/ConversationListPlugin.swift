import AgentToolKit
import Foundation
import os
import SwiftUI

/// Conversation List Plugin: 对话历史列表
///
/// 在工具栏右侧提供会话列表入口（ConversationListPopoverButton）。
/// 同时在首条用户消息发送后自动生成会话标题。
actor ConversationListPlugin: SuperPlugin, SuperLog {
    /// 插件专用 Logger
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.conversation-list")

    // MARK: - Plugin Properties

    nonisolated static let emoji = "💬"
    static var category: PluginCategory { .agent }
    nonisolated static let enable: Bool = true
    nonisolated static let verbose: Bool = true
    static let id: String = "ConversationList"
    static let displayName: String = String(localized: "Conversation List", table: "ConversationList")
    static let description: String = String(localized: "Show all conversation history", table: "ConversationList")
    static let iconName: String = "message.fill"
    static let isConfigurable: Bool = false
    static var order: Int { 76 }

    nonisolated var instanceLabel: String { Self.id }
    static let shared = ConversationListPlugin()

    init() {}

    // MARK: - Toolbar Views

    /// 工具栏右侧：会话列表按钮
    @MainActor
    func addToolBarTrailingView(activeIcon: String?) -> AnyView? {
        if activeIcon != EditorPlugin.iconName {
            return nil
        }
        
        return AnyView(ConversationListPopoverButton())
    }

    // MARK: - Send Middlewares

    /// 发送管线中间件：首条消息后自动生成标题
    @MainActor
    func sendMiddlewares() -> [AnySuperSendMiddleware] {
        [AnySuperSendMiddleware(AutoConversationTitleSuperSendMiddleware())]
    }

    // MARK: - Agent Tools

    /// 提供对话管理相关的 Agent 工具
    @MainActor
    func agentTools(context: ToolContext) -> [SuperAgentTool] {
        [
            GetConversationCountTool(),
            GetRecentConversationsTool(),
        ]
    }
}
