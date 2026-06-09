import LumiCoreKit

/// Conversation Title Plugin: inject title drift hints during chat sends.
public enum ConversationTitlePlugin: LumiPlugin {
    public static let policy: LumiPluginPolicy = .alwaysOn
    public static let category: LumiPluginCategory = .agent
    public static let iconName = "character.cursor.ibeam"

    public static let info = LumiPluginInfo(
        id: "com.coffic.lumi.plugin.conversation-title",
        displayName: String(localized: "Auto Conversation Title", bundle: .module),
        description: String(
            localized: "Automatically generate conversation titles from the first user message",
            bundle: .module
        ),
        order: 77
    )

    static var verbose: Bool { false }

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
