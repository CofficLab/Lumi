import LumiCoreKit
import LumiUI
import SwiftUI

public enum ChatPanelPlugin: LumiPlugin {
    public static let policy: LumiPluginPolicy = .alwaysOn
    public static let category: LumiPluginCategory = .agent
    public static let iconName = "bubble.left.and.bubble.right.fill"
    public static let info = LumiPluginInfo(
        id: "com.coffic.lumi.plugin.chat-panel",
        displayName: String(localized: "Chat", bundle: .module),
        description: String(localized: "Conversation list with chat surface", bundle: .module),
        order: 78
    )

    @MainActor
    public static func viewContainers(context: LumiPluginContext) -> [LumiViewContainerItem] {
        [
            LumiViewContainerItem(
                id: info.id,
                title: info.displayName,
                systemImage: iconName
            ) {
                if let chatService = context.resolve(LumiChatServicing.self) {
                    ChatPanelView(chatService: chatService)
                } else {
                    MissingChatServiceView()
                }
            }
        ]
    }
}

private struct MissingChatServiceView: View {
    var body: some View {
        AppEmptyState(
            icon: "exclamationmark.triangle",
            title: "Chat service is not available"
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
