import LumiChatKit
import LumiCoreKit
import LumiUI
import SwiftUI

public enum MessageListPlugin: LumiPlugin {
    public static let policy: LumiPluginPolicy = .alwaysOn
    public static let stage: LumiPluginStage = .beta
    public static let category: LumiPluginCategory = .agent
    public static let iconName = "text.bubble.fill"

    public static let info = LumiPluginInfo(
        id: "com.coffic.lumi.plugin.chat-messages-section",
        displayName: LumiPluginLocalization.string("Chat Messages", bundle: .module),
        description: LumiPluginLocalization.string("Agent chat messages timeline in the right ChatSection.", bundle: .module),
        order: 82
    )

    @MainActor
    public static func chatSectionItems(context: LumiPluginContext) -> [LumiChatSectionItem] {
        guard context.showsChatSection else {
            return []
        }

        // ChatSectionCoordinator 不可用时显示错误视图
        guard let coordinator = context.resolve(ChatSectionCoordinator.self) else {
            return [
                LumiChatSectionItem(id: info.id, order: info.order, fillsRemainingHeight: true) {
                    ChatMessagesErrorView(pluginName: info.displayName)
                }
            ]
        }

        return [
            LumiChatSectionItem(id: info.id, order: info.order, fillsRemainingHeight: true) {
                ChatMessagesSectionView(coordinator: coordinator)
            }
        ]
    }
}
