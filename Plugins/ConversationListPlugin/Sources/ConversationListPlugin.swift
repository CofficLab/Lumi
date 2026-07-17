import LumiChatKit
import LumiCoreKit
import os
import SwiftUI

/// Conversation List Plugin: rail conversation list, project switch guidance, and agent tools.
public enum ConversationListPlugin: LumiPlugin {
    public static let verbose = false
    public static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.conversation-list")
    public static let t = "💬"

    public static let info = LumiPluginInfo(
        id: "com.coffic.lumi.plugin.conversation-list",
        displayName: LumiPluginLocalization.string("Conversation List", bundle: .module),
        description: LumiPluginLocalization.string("Show all conversation history", bundle: .module),
        order: 76,
        category: .agent,
        policy: .alwaysOn,
        stage: .beta,
        iconName: "message.fill",
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

        let projectComponent = context.lumiCore?.projectComponent
        return [
            LumiTitleToolbarItem(
                id: "\(info.id).conversation-list",
                title: LumiPluginLocalization.string("会话列表", bundle: .module),
                placement: .trailing
            ) {
                ConversationListPopoverButton(
                    chatService: chatService,
                    projectPathStore: projectComponent,
                    projectStore: projectComponent
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
                    order: info.order,
                    title: LumiPluginLocalization.string("Chats", bundle: .module),
                    systemImage: "message.fill"
                ) {
                    ConversationListErrorView()
                },
            ]
        }

        let projectComponent = context.lumiCore?.projectComponent

        return [
            LumiPanelRailTabItem(
                id: "chats",
                order: info.order,
                title: LumiPluginLocalization.string("Chats", bundle: .module),
                systemImage: "message.fill"
            ) {
                ConversationRailPanelView(
                    chatService: chatService,
                    projectPathStore: projectComponent,
                    projectStore: projectComponent
                )
            },
        ]
    }

    @MainActor
    public static func agentTools(context: LumiPluginContext) throws -> [any LumiAgentTool] {
        guard let chatService = context.resolve((any LumiChatServicing).self) else {
            throw LumiPluginDependencyError.serviceUnavailable("LumiChatServicing")
        }
        return [
            CreateNewConversationLumiTool(chatService: chatService),
            DeleteConversationLumiTool(chatService: chatService),
            GetRecentConversationsLumiTool(chatService: chatService),
            GetConversationCountLumiTool(chatService: chatService),
            SetConversationProjectLumiTool(chatService: chatService),
        ]
    }

    @MainActor
    public static func pluginAboutView(context: LumiPluginContext) -> AnyView? {
        AnyView(
            VStack(alignment: .leading, spacing: 12) {
                Text(verbatim: LumiPluginLocalization.string(
                    "会话列表插件会在工具栏右侧展示一个对话历史入口，支持快速搜索、新建、删除和按项目过滤会话。",
                    bundle: .module
                ))
                .font(.appCaption)
                .foregroundStyle(.secondary)

                Divider()

                Label(
                    LumiPluginLocalization.string("策略：始终启用，无法关闭", bundle: .module),
                    systemImage: "lock.fill"
                )
                .font(.appMicro)
                .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .topLeading)
        )
    }
}
