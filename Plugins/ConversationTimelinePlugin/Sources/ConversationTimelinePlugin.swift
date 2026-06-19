import LumiCoreKit
import SwiftUI

/// 在 Chat 工具栏显示当前对话的 LLM 上下文用量。
public enum ConversationTimelinePlugin: LumiPlugin {
    public static let policy: LumiPluginPolicy = .alwaysOn
    public static let category: LumiPluginCategory = .agent
    public static let iconName = "chart.bar.xaxis"

    public static let info = LumiPluginInfo(
        id: "com.coffic.lumi.plugin.conversation-timeline",
        displayName: LumiPluginLocalization.string("Conversation Timeline", bundle: .module),
        description: LumiPluginLocalization.string("Display conversation message timeline in status bar", bundle: .module),
        order: 82
    )

    @MainActor
    public static func chatSectionToolbarBarItems(context: LumiPluginContext) -> [LumiChatSectionToolbarBarItem] {
        guard context.showsChatSection,
              let chatService = context.resolve(LumiChatServicing.self)
        else {
            return []
        }

        return [
            LumiChatSectionToolbarBarItem(id: "\(info.id).context-usage", order: info.order) {
                ContextUsageToolbarView(chatService: chatService)
            }
        ]
    }
}
