import AgentToolKit
import Foundation
import os
import SwiftUI

/// Conversation List Plugin: 对话历史列表
///
/// 在工具栏右侧提供会话列表入口（ConversationListPopoverButton）。
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

    /// 发送管线中间件：项目切换对话引导
    @MainActor
    func sendMiddlewares() -> [AnySuperSendMiddleware] {
        [AnySuperSendMiddleware(ProjectSwitchSendMiddleware())]
    }

    // MARK: - Agent Tools

    /// 提供对话管理相关的 Agent 工具
    @MainActor
    func agentTools(context: ToolContext) -> [SuperAgentTool] {
        guard let conversationVM = context.conversationVM else { return [] }

        let projectName = RootContainer.shared.windowManagerVM.activeWindowContainer?.projectVM.currentProject?.name
        let projectPath = RootContainer.shared.windowManagerVM.activeWindowContainer?.projectVM.currentProject?.path

        return [
            GetConversationCountTool(conversationVM: conversationVM),
            GetRecentConversationsTool(
                conversationVM: conversationVM,
                currentProjectPath: projectPath
            ),
            CreateNewConversationTool(
                conversationVM: conversationVM,
                projectName: projectName,
                projectPath: projectPath,
                languagePreference: context.languagePreference
            ),
            DeleteConversationTool(
                conversationVM: conversationVM,
                languagePreference: context.languagePreference
            ),
            SetConversationProjectTool(conversationVM: conversationVM),
        ]
    }
}
