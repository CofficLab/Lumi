import LumiCoreKit
import SwiftUI

/// 一键续接对话插件。
///
/// 在聊天区工具栏提供「续接到新对话」按钮：把当前对话摘要后注入新对话续写，
/// 用于当前对话卡住、希望带上下文重新开始 的场景。
public enum ConversationForkPlugin: LumiPlugin {

    public static let info = LumiPluginInfo(
        id: "com.coffic.lumi.plugin.conversation-fork",
        displayName: LumiPluginLocalization.string("Continue in New Chat", bundle: .module),
        description: LumiPluginLocalization.string(
            "Summarize the current conversation and continue it in a new chat",
            bundle: .module
        ),
        // 紧跟 ConversationNewPlugin (order 60)，让两个按钮相邻。
        order: 61,
        category: .agent,
        policy: .alwaysOn,
        stage: .beta,
        iconName: "arrow.uturn.forward.circle",
    )

    @MainActor
    public static func chatSectionToolbarItems(context: any LumiCoreAccessing) -> [LumiChatSectionToolbarItem] {
        guard context.showsChatSection,
              let chatService = context.resolve((any LumiChatServicing).self)
        else {
            return []
        }

        return [
            LumiChatSectionToolbarItem(
                id: "\(info.id).button",
                order: info.order,
                placement: .trailing
            ) {
                ConversationForkButton(chatService: chatService)
            }
        ]
    }
}
