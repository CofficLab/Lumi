import PluginConversationNew
import SwiftUI

actor ConversationNewPlugin: SuperPlugin {
    nonisolated static let emoji = PluginConversationNew.ConversationNewPlugin.emoji
    nonisolated static let verbose = PluginConversationNew.ConversationNewPlugin.verbose
    static let id = PluginConversationNew.ConversationNewPlugin.id
    static let displayName = PluginConversationNew.ConversationNewPlugin.displayName
    static let description = PluginConversationNew.ConversationNewPlugin.description
    static let iconName = PluginConversationNew.ConversationNewPlugin.iconName
    static var category: PluginCategory { PluginCategory(package: PluginConversationNew.ConversationNewPlugin.category) }
    static var order: Int { PluginConversationNew.ConversationNewPlugin.order }
    static let shared = ConversationNewPlugin()

    @MainActor
    func addToolBarTrailingView(context: PluginContext) -> AnyView? {
        guard context.supportsAIChat else { return nil }
        return AnyView(ConversationNewButtonBridge())
    }
}

private struct ConversationNewButtonBridge: View {
    @EnvironmentObject private var conversationVM: WindowConversationVM

    var body: some View {
        PluginConversationNew.NewChatButton()
            .onAppear {
                ConversationNewRuntime.createConversation = {
                    await conversationVM.createNewConversation()
                }
            }
    }
}
