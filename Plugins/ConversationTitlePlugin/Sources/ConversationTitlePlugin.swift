import LumiChatKit
import LumiCoreKit
import SwiftUI

/// Conversation Title Plugin: title header UI, auto-generation, and drift hints during chat sends.
public enum ConversationTitlePlugin: LumiPlugin {
    public static let policy: LumiPluginPolicy = .alwaysOn
    public static let stage: LumiPluginStage = .beta
    public static let category: LumiPluginCategory = .agent
    public static let iconName = "character.cursor.ibeam"

    public static let info = LumiPluginInfo(
        id: "com.coffic.lumi.plugin.conversation-title",
        displayName: LumiPluginLocalization.string("Auto Conversation Title", bundle: .module),
        description: LumiPluginLocalization.string(
            "Automatically generate conversation titles from the first user message",
            bundle: .module
        ),
        order: 77
    )

    static var verbose: Bool { false }

    @MainActor
    public static func bootstrap(
        chatServiceProvider: @escaping @MainActor () -> (any LumiChatServicing)?
    ) {
        ConversationTitleRuntimeBridge.chatServiceProvider = chatServiceProvider
        ConversationTitleNotificationObserver.start()
    }

    @MainActor
    public static func chatSectionHeaderItems(context: LumiPluginContext) -> [LumiChatSectionHeaderItem] {
        guard context.showsChatSection else {
            return []
        }

        // ChatSectionCoordinator 不可用时显示错误按钮
        // header 排在 info.order + 4，介于 info.order (77) 和顶部 error 区域 (95/96) 之间。
        guard let coordinator = context.resolve(ChatSectionCoordinator.self) else {
            return [
                LumiChatSectionHeaderItem(id: "\(info.id).header-error", order: info.order + 4) {
                    ChatSectionCoordinatorErrorButton()
                }
            ]
        }

        return [
            LumiChatSectionHeaderItem(id: "\(info.id).header", order: info.order + 4) {
                ConversationTitleSectionView(coordinator: coordinator)
            }
        ]
    }

    @MainActor
    public static func sendMiddlewares(context: LumiPluginContext) -> [any LumiSendMiddleware] {
        [ConversationTitleChatMiddleware()]
    }

    @MainActor
    public static func agentTools(context: LumiPluginContext) -> [any LumiAgentTool] {
        guard let chatService = context.resolve((any LumiChatServicing).self) else {
            return []
        }
        return [UpdateConversationTitleLumiTool(chatService: chatService)]
    }
}
