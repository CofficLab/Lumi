import LumiCoreKit

/// Conversation List Plugin: project switch guidance during chat sends.
public enum ConversationListPlugin: LumiPlugin {
    public static let policy: LumiPluginPolicy = .alwaysOn
    public static let category: LumiPluginCategory = .agent
    public static let iconName = "message.fill"

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
}
