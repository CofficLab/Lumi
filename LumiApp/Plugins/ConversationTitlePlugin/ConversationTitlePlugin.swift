import AgentToolKit
import Foundation
import os
import SwiftUI

/// Conversation Title Plugin: 自动对话标题生成
///
/// 在首条用户消息发送后，通过 LLM 自动生成简洁的对话标题。
actor ConversationTitlePlugin: SuperPlugin, SuperLog {
    /// 插件专用 Logger
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.conversation-title")

    // MARK: - Plugin Properties

    nonisolated static let emoji = "✏️"
    static var category: PluginCategory { .agent }
    nonisolated static let enable: Bool = true
    nonisolated static let verbose: Bool = true
    static let id: String = "ConversationTitle"
    static let displayName: String = String(localized: "Auto Conversation Title", table: "ConversationTitle")
    static let description: String = String(localized: "Automatically generate conversation titles from the first user message", table: "ConversationTitle")
    static let iconName: String = "character.cursor.ibeam"
    static let isConfigurable: Bool = false
    static var order: Int { 77 }

    nonisolated var instanceLabel: String { Self.id }
    static let shared = ConversationTitlePlugin()

    init() {}

    // MARK: - Send Middlewares

    /// 发送管线中间件：首条消息后自动生成标题 + 注入标题漂移提示
    @MainActor
    func sendMiddlewares() -> [AnySuperSendMiddleware] {
        [
            AnySuperSendMiddleware(AutoConversationTitleSuperSendMiddleware()),
            AnySuperSendMiddleware(ConversationTitleHintSendMiddleware()),
        ]
    }

    // MARK: - Agent Tools

    /// 提供对话标题相关的 Agent 工具
    @MainActor
    func agentTools(context: ToolContext) -> [SuperAgentTool] {
        guard let conversationVM = context.conversationVM else { return [] }
        return [
            UpdateConversationTitleTool(conversationVM: conversationVM),
        ]
    }
}
