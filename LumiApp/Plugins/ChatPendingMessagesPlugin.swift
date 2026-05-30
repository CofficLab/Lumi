import PluginChatPendingMessages
import SwiftUI

actor ChatPendingMessagesPlugin: SuperPlugin {
    nonisolated static let logger = PluginChatPendingMessages.ChatPendingMessagesPlugin.logger
    nonisolated static let emoji = PluginChatPendingMessages.ChatPendingMessagesPlugin.emoji
    nonisolated static let verbose = PluginChatPendingMessages.ChatPendingMessagesPlugin.verbose
    static let id = PluginChatPendingMessages.ChatPendingMessagesPlugin.id
    static let displayName = PluginChatPendingMessages.ChatPendingMessagesPlugin.displayName
    static let description = PluginChatPendingMessages.ChatPendingMessagesPlugin.description
    static let iconName = PluginChatPendingMessages.ChatPendingMessagesPlugin.iconName
    static var category: PluginCategory { PluginCategory(package: PluginChatPendingMessages.ChatPendingMessagesPlugin.category) }
    static var order: Int { PluginChatPendingMessages.ChatPendingMessagesPlugin.order }
    static let shared = ChatPendingMessagesPlugin()

    @MainActor
    func addSidebarSections(context: PluginContext) -> [AnyView] {
        guard context.supportsAIChat else { return [] }
        return [AnyView(PendingMessagesRuntimeBridge())]
    }
}

@MainActor
private struct PendingMessagesRuntimeBridge: View {
    @EnvironmentObject private var messageQueueVM: WindowMessageQueueVM
    @EnvironmentObject private var conversationVM: WindowConversationVM

    var body: some View {
        PluginChatPendingMessages.PendingMessagesView()
            .onAppear(perform: sync)
            .onChange(of: messageQueueVM.queueVersion) { _, _ in sync() }
            .onChange(of: conversationVM.selectedConversationId) { _, _ in sync() }
    }

    private func sync() {
        PluginChatPendingMessages.PendingMessagesRuntime.messagesProvider = {
            guard let id = conversationVM.selectedConversationId else { return [] }
            return messageQueueVM.pendingMessages(for: id)
        }
        PluginChatPendingMessages.PendingMessagesRuntime.removeMessage = { id in
            messageQueueVM.removeMessage(id: id)
        }
        PluginChatPendingMessages.PendingMessagesRuntime.titleProvider = {
            String(localized: "Waiting to Send", table: "AgentChat")
        }
    }
}
