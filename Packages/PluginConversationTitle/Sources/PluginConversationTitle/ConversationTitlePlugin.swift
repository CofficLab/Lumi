import AgentToolKit
import LumiCoreKit
import SuperLogKit
import Foundation
import os
import SwiftUI

/// Conversation Title Plugin: 自动对话标题生成
///
/// 在首条用户消息发送后，通过 LLM 自动生成简洁的对话标题。
public actor ConversationTitlePlugin: SuperPlugin, SuperLog {
    /// 插件专用 Logger
    public nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.conversation-title")

    // MARK: - Plugin Properties

    public nonisolated static let emoji = "✏️"
    public static var category: PluginCategory { .agent }
    public nonisolated static let verbose: Bool = true
    public static let id: String = "ConversationTitle"
    public static let displayName: String = String(localized: "Auto Conversation Title", table: "ConversationTitle")
    public static let description: String = String(localized: "Automatically generate conversation titles from the first user message", table: "ConversationTitle")
    public static let iconName: String = "character.cursor.ibeam"
    public static var order: Int { 77 }

    public nonisolated var instanceLabel: String { Self.id }
    public static let shared = ConversationTitlePlugin()

    public init() {}

    // MARK: - Send Middlewares

    /// 发送管线中间件：首条消息后自动生成标题 + 注入标题漂移提示
    @MainActor
    public func sendMiddlewares() -> [AnySuperSendMiddleware] {
        []
    }

    // MARK: - Agent Tools

    /// 提供对话标题相关的 Agent 工具
    @MainActor
    public func agentTools(context: ToolContext) -> [SuperAgentTool] {
        []
    }
}
