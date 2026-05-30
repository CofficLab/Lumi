import PluginChatMessages
import SwiftUI

actor ChatMessagesPlugin: SuperPlugin {
    nonisolated static let logger = PluginChatMessages.AgentChatPlugin.logger
    nonisolated static let emoji = PluginChatMessages.AgentChatPlugin.emoji
    nonisolated static let verbose = PluginChatMessages.AgentChatPlugin.verbose
    static let id = PluginChatMessages.AgentChatPlugin.id
    static let displayName = PluginChatMessages.AgentChatPlugin.displayName
    static let description = PluginChatMessages.AgentChatPlugin.description
    static let iconName = PluginChatMessages.AgentChatPlugin.iconName
    static var category: PluginCategory { PluginCategory(package: PluginChatMessages.AgentChatPlugin.category) }
    static var order: Int { PluginChatMessages.AgentChatPlugin.order }
    static let shared = ChatMessagesPlugin()

    @MainActor
    func addSidebarSections(context: PluginContext) -> [AnyView] {
        guard context.supportsAIChat else { return [] }
        return [AnyView(ChatMessagesRuntimeBridge())]
    }
}

@MainActor
private struct ChatMessagesRuntimeBridge: View {
    @EnvironmentObject private var conversationVM: WindowConversationVM
    @EnvironmentObject private var chatHistoryVM: AppChatHistoryVM
    @State private var messages: [ChatMessage] = []

    var body: some View {
        PluginChatMessages.ChatMessagesView()
            .onAppear(perform: sync)
            .onChange(of: conversationVM.selectedConversationId) { _, _ in reload() }
            .onReceive(NotificationCenter.default.publisher(for: .messageSaved)) { notification in
                guard let id = notification.userInfo?["conversationId"] as? UUID,
                      id == conversationVM.selectedConversationId else { return }
                reload()
            }
    }

    private func sync() {
        reload()
        PluginChatMessages.ChatMessagesRuntime.messagesProvider = { messages }
        PluginChatMessages.ChatMessagesRuntime.hasConversationProvider = {
            conversationVM.selectedConversationId != nil
        }
    }

    private func reload() {
        if let conversationId = conversationVM.selectedConversationId {
            messages = chatHistoryVM.loadMessagesAsync(forConversationId: conversationId) ?? []
        } else {
            messages = []
        }
        PluginChatMessages.ChatMessagesRuntime.messagesProvider = { messages }
    }
}
