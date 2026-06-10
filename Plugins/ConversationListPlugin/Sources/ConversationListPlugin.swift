import LumiChatKit
import LumiCoreKit
import os

/// Conversation List Plugin: rail conversation list, project switch guidance, and agent tools.
public enum ConversationListPlugin: LumiPlugin {
    public static let policy: LumiPluginPolicy = .alwaysOn
    public static let category: LumiPluginCategory = .agent
    public static let iconName = "message.fill"
    public static let verbose = false
    public static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.conversation-list")
    public static let t = "💬"

    public static let info = LumiPluginInfo(
        id: "com.coffic.lumi.plugin.conversation-list",
        displayName: String(localized: "Conversation List", bundle: .module),
        description: String(localized: "Show all conversation history", bundle: .module),
        order: 76
    )

    @MainActor
    public static func sendMiddlewares(context: LumiPluginContext) -> [any LumiSendMiddleware] {
        [ProjectSwitchChatMiddleware()]
    }

    @MainActor
    public static func panelRailTabItems(context: LumiPluginContext) -> [LumiPanelRailTabItem] {
        guard context.showsRail,
              context.activeSectionID == ChatPanelSection.id,
              let chatService = context.resolve(LumiChatServicing.self) as? ChatService
        else {
            return []
        }

        let projectPathStore = context.resolve(LumiCurrentProjectPathStoring.self)

        return [
            LumiPanelRailTabItem(
                id: "chats",
                order: 0,
                title: String(localized: "Chats", bundle: .module),
                systemImage: "message.fill"
            ) {
                ConversationRailPanelView(
                    chatService: chatService,
                    projectPathStore: projectPathStore
                )
            }
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
