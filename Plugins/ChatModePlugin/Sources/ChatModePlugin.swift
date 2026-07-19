import LumiKernel
import SwiftUI

/// 自动化程度切换插件：在 Chat 工具栏提供 Chat / Build / 自主 模式选择。
public enum ChatModePlugin: LumiPlugin {

    public static let info = LumiPluginInfo(
        id: "com.coffic.lumi.plugin.chat-mode",
        displayName: LumiPluginLocalization.string("Chat Mode", bundle: .module),
        description: LumiPluginLocalization.string("Switch between Chat and Build modes", bundle: .module),
        order: 84,
        category: .agent,
        policy: .alwaysOn,
        stage: .beta,
        iconName: "arrow.triangle.2.circlepath",
    )

    @MainActor
    public static func chatSectionToolbarBarItems(context: LumiPluginContext) -> [LumiChatSectionToolbarBarItem] {
        guard context.showsChatSection,
              let chatService = context.resolve(LumiChatServicing.self)
        else {
            return []
        }

        return [
            LumiChatSectionToolbarBarItem(id: info.id, order: info.order) {
                AutomationLevelToolbarView(chatService: chatService)
            }
        ]
    }
}
