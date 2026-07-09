import LumiChatKit
import LumiCoreKit
import os
import SwiftUI

/// Conversation List Plugin: rail conversation list, project switch guidance, and agent tools.
public enum ConversationListPlugin: LumiPlugin {
    public static let policy: LumiPluginPolicy = .alwaysOn
    public static let stage: LumiPluginStage = .beta
    public static let category: LumiPluginCategory = .agent
    public static let iconName = "message.fill"
    public static let verbose = false
    public static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.conversation-list")
    public static let t = "💬"

    public static let info = LumiPluginInfo(
        id: "com.coffic.lumi.plugin.conversation-list",
        displayName: LumiPluginLocalization.string("Conversation List", bundle: .module),
        description: LumiPluginLocalization.string("Show all conversation history", bundle: .module),
        order: 76
    )

    @MainActor
    public static func sendMiddlewares(context: LumiPluginContext) -> [any LumiSendMiddleware] {
        [ProjectSwitchChatMiddleware()]
    }

    @MainActor
    public static func titleToolbarItems(context: LumiPluginContext) -> [LumiTitleToolbarItem] {
        guard context.showsChatSection else {
            return []
        }

        let chatService = context.resolve(LumiChatServicing.self) as? ChatService

        // 如果 ChatService 不可用，显示错误按钮
        guard let chatService else {
            return [
                LumiTitleToolbarItem(
                    id: "\(info.id).conversation-list",
                    title: LumiPluginLocalization.string("会话列表", bundle: .module),
                    placement: .trailing
                ) {
                    ConversationListErrorButton()
                },
            ]
        }

        let projectState = LumiCore.projectState
        return [
            LumiTitleToolbarItem(
                id: "\(info.id).conversation-list",
                title: LumiPluginLocalization.string("会话列表", bundle: .module),
                placement: .trailing
            ) {
                ConversationListPopoverButton(
                    chatService: chatService,
                    projectPathStore: projectState,
                    projectStore: projectState
                )
            },
        ]
    }

    @MainActor
    public static func panelRailTabItems(context: LumiPluginContext) -> [LumiPanelRailTabItem] {
        guard context.showsRail else {
            return []
        }

        let chatService = context.resolve(LumiChatServicing.self) as? ChatService

        // ChatService 不可用时显示错误视图
        guard let chatService else {
            return [
                LumiPanelRailTabItem(
                    id: "chats-error",
                    order: 0,
                    title: LumiPluginLocalization.string("Chats", bundle: .module),
                    systemImage: "message.fill"
                ) {
                    ConversationListErrorView()
                },
            ]
        }

        let projectState = LumiCore.projectState

        return [
            LumiPanelRailTabItem(
                id: "chats",
                order: 0,
                title: LumiPluginLocalization.string("Chats", bundle: .module),
                systemImage: "message.fill"
            ) {
                ConversationRailPanelView(
                    chatService: chatService,
                    projectPathStore: projectState,
                    projectStore: projectState
                )
            },
        ]
    }

    @MainActor
    public static func agentTools(context: LumiPluginContext) -> [any LumiAgentTool] {
        guard let chatService = context.resolve((any LumiChatServicing).self) else {
            return []
        }
        return [
            CreateNewConversationLumiTool(chatService: chatService),
            DeleteConversationLumiTool(chatService: chatService),
            GetRecentConversationsLumiTool(chatService: chatService),
            GetConversationCountLumiTool(chatService: chatService),
            SetConversationProjectLumiTool(chatService: chatService),
        ]
    }
}
