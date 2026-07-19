import LumiCoreKit
import SwiftUI

/// 语言切换插件：在 Chat 工具栏提供语言选择，并通过中间件注入 LLM 系统提示。
public enum ConversationLanguagePlugin: LumiPlugin {

    public static let info = LumiPluginInfo(
        id: "com.coffic.lumi.plugin.conversation-language",
        displayName: LumiPluginLocalization.string("Language Selector", bundle: .module),
        description: LumiPluginLocalization.string("AI response language in header", bundle: .module),
        order: 83,
        category: .agent,
        policy: .alwaysOn,
        stage: .beta,
        iconName: "globe",
    )

    @MainActor
    public static func chatSectionToolbarBarItems(context: any LumiCoreAccessing) -> [LumiChatSectionToolbarBarItem] {
        guard context.showsChatSection,
              let chatService = context.resolve(LumiChatServicing.self)
        else {
            return []
        }

        return [
            LumiChatSectionToolbarBarItem(id: info.id, order: info.order) {
                ConversationLanguageToolbarView(chatService: chatService)
            }
        ]
    }

    @MainActor
    public static func sendMiddlewares(context: any LumiCoreAccessing) -> [any LumiSendMiddleware] {
        [LanguageChatMiddleware()]
    }
}
