import LumiCoreKit
import SwiftUI

/// 新建对话标题栏插件
///
/// 在标题栏右侧提供新建对话按钮（NewChatButton）。
public enum ConversationNewPlugin: LumiPlugin {
    public static let policy: LumiPluginPolicy = .alwaysOn
    public static let stage: LumiPluginStage = .beta
    public static let category: LumiPluginCategory = .agent
    public static let iconName = "bubble.left.and.bubble.right"

    public static let info = LumiPluginInfo(
        id: "com.coffic.lumi.plugin.conversation-new",
        displayName: LumiPluginLocalization.string("New Chat Button", bundle: .module),
        description: LumiPluginLocalization.string("Create new chat from header", bundle: .module),
        order: 60
    )

    @MainActor
    public static func titleToolbarItems(context: LumiPluginContext) -> [LumiTitleToolbarItem] {
        guard context.showsChatSection,
              let chatService = context.resolve(LumiChatServicing.self)
        else {
            return []
        }

        let projectState = LumiCore.projectState
        return [
            LumiTitleToolbarItem(
                id: "\(info.id).new-chat",
                title: LumiPluginLocalization.string("Start New Conversation", bundle: .module),
                placement: .trailing
            ) {
                NewChatButton(
                    chatService: chatService,
                    projectState: projectState
                )
            }
        ]
    }
}
