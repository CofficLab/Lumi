import LumiCoreKit
import SuperLogKit
import AgentToolKit
import Foundation
import os
import SwiftUI

/// Conversation List Plugin: 对话历史列表
///
/// 在工具栏右侧提供会话列表入口（ConversationListPopoverButton）。
public actor ConversationListPlugin: SuperPlugin, SuperLog {
    /// 插件专用 Logger
    public nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.conversation-list")

    // MARK: - Plugin Properties

    public nonisolated static let emoji = "💬"
    public static var category: PluginCategory { .agent }
    public nonisolated static let verbose: Bool = true
    public static let id: String = "ConversationList"
    public static let displayName: String = String(localized: "Conversation List", table: "ConversationList")
    public static let description: String = String(localized: "Show all conversation history", table: "ConversationList")
    public static let iconName: String = "message.fill"
    public static var order: Int { 76 }
    public nonisolated static let policy: PluginPolicy = .alwaysOn

    public nonisolated var instanceLabel: String { Self.id }
    public static let shared = ConversationListPlugin()

    public init() {}

    // MARK: - Toolbar Views

    @MainActor
    public func addPosterViews() -> [AnyView] {
        []
    }

    /// 工具栏右侧：会话列表按钮
    @MainActor
    public func addToolBarTrailingView(context: PluginContext) -> AnyView? {
        nil
    }

    // MARK: - Send Middlewares

    /// 发送管线中间件：项目切换对话引导
    @MainActor
    public func sendMiddlewares() -> [AnySuperSendMiddleware] {
        []
    }

    // MARK: - Agent Tools

    /// 提供对话管理相关的 Agent 工具
    @MainActor
    public func agentTools(context: ToolContext) -> [SuperAgentTool] {
        []
    }
}
