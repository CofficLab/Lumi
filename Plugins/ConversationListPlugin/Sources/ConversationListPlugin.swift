import LumiCoreKit
import SuperLogKit
import AgentToolKit
import LumiUI
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
    public static let displayName: String = String(localized: "Conversation List", bundle: .module)
    public static let description: String = String(localized: "Show all conversation history", bundle: .module)
    public static let iconName: String = "message.fill"
    public static var order: Int { 76 }
    public nonisolated static let policy: PluginPolicy = .alwaysOn

    public nonisolated var instanceLabel: String { Self.id }
    public static let shared = ConversationListPlugin()

    public init() {}

    // MARK: - Poster Views

    @MainActor
    public func addPosterViews() -> [AnyView] {
        [
            PluginPosterSupport.poster(
                title: "会话历史",
                subtitle: "从工具栏访问会话列表，并提供会话创建、删除和项目关联工具。",
                icon: Self.iconName,
                accent: .blue,
                metrics: [
                    PluginPosterSupport.metric("History", "历史"),
                    PluginPosterSupport.metric("Tools", "工具"),
                ],
                rows: ["最近会话", "新建会话", "项目关联"],
                chips: ["Agent", "会话", "历史"]
            ),
        ]
    }

    // MARK: - Toolbar Views

    /// 工具栏右侧：会话列表按钮
    @MainActor
    public func addToolBarTrailingView(context: PluginContext) -> AnyView? {
        guard context.supportsAIChat else { return nil }
        guard let conversationListContext = context.conversationListContext else { return nil }
        return AnyView(ConversationListPopoverButton(context: conversationListContext))
    }

    // MARK: - Send Middlewares

    /// 发送管线中间件：项目切换对话引导
    @MainActor
    public func sendMiddlewares() -> [AnySuperSendMiddleware] {
        [AnySuperSendMiddleware(ProjectSwitchSendMiddleware())]
    }

    // MARK: - Agent Tools

    /// 提供对话管理相关的 Agent 工具
    @MainActor
    public func agentTools(context: ToolContext) -> [SuperAgentTool] {
        guard let conversationListContext = context.conversationListContext else { return [] }
        return [
            CreateNewConversationTool(
                conversationListContext: conversationListContext,
                projectName: context.currentProjectName,
                projectPath: context.currentProjectPath,
                languagePreference: context.languagePreference
            ),
            DeleteConversationTool(
                conversationListContext: conversationListContext,
                languagePreference: context.languagePreference
            ),
            GetRecentConversationsTool(
                conversationListContext: conversationListContext,
                currentProjectPath: context.currentProjectPath
            ),
            GetConversationCountTool(conversationListContext: conversationListContext),
            SetConversationProjectTool(conversationListContext: conversationListContext),
        ]
    }
}
