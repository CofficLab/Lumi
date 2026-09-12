import KernelCore
import ProviderChatSection
import ProviderConversation
import ProviderMessage
import Testing
@testable import PluginMessageListEmpty

@Test @MainActor func pluginShowsEmptyStateOnlyForSelectedConversationWithoutVisibleMessages() throws {
    let kernel = KernelCoreContainer()
    let conversations = DefaultConversationManager()
    let messages = DefaultMessageManager()
    let chat = DefaultChatSectionProviding()
    try kernel.registerProvider((any ChatSectionProviding).self, chat)
    try kernel.registerProvider((any ConversationManaging).self, conversations)
    try kernel.registerProvider((any MessageManaging).self, messages)
    let plugin = PluginMessageListEmptyPlugin()

    try plugin.onBoot(kernel: kernel)
    #expect(chat.items.map(\.id) == [plugin.id])
    #expect(chat.items.first?.exclusiveGroup == "message-list")
    #expect(chat.items.first?.fillsRemainingHeight == true)

    let firstID = try conversations.createConversation(title: "First", projectPath: nil, providerID: nil, modelName: nil)
    let selectedID = try conversations.createConversation(title: "Selected", projectPath: nil, providerID: nil, modelName: nil)
    let firstMessageID = UUID()
    messages.insertMessage(
        Message(id: firstMessageID, conversationID: firstID, role: .user, content: "Non-selected"),
        to: firstID
    )
    #expect(chat.items.map(\.id) == [plugin.id])

    messages.insertMessage(Message(conversationID: selectedID, role: .tool, content: "Tool output"), to: selectedID)
    #expect(chat.items.map(\.id) == [plugin.id])

    let visibleMessageID = UUID()
    messages.insertMessage(Message(id: visibleMessageID, conversationID: selectedID, role: .user, content: "Hello"), to: selectedID)
    #expect(chat.items.isEmpty)

    messages.clearMessages(in: selectedID)
    #expect(chat.items.map(\.id) == [plugin.id])

    conversations.selectConversation(id: firstID)
    #expect(chat.items.isEmpty)

    messages.deleteMessage(id: firstMessageID, in: firstID)
    #expect(chat.items.map(\.id) == [plugin.id])

    conversations.deselectConversation()
    #expect(chat.items.map(\.id) == [plugin.id])

    try plugin.onShutdown(kernel: kernel)
    #expect(chat.items.isEmpty)

    messages.clearMessages(in: selectedID)
    conversations.selectConversation(id: selectedID)
    #expect(chat.items.isEmpty)
}

@Test @MainActor func pluginCanProvideNoSelectionEmptyStateWithoutOptionalProviders() throws {
    let kernel = KernelCoreContainer()
    let chat = DefaultChatSectionProviding()
    try kernel.registerProvider((any ChatSectionProviding).self, chat)
    let plugin = PluginMessageListEmptyPlugin()

    try plugin.onBoot(kernel: kernel)

    #expect(chat.items.map(\.id) == [plugin.id])
    try plugin.onShutdown(kernel: kernel)
    #expect(chat.items.isEmpty)
}

@Test @MainActor func pluginDoesNotBootWithoutChatSectionProvider() throws {
    let plugin = PluginMessageListEmptyPlugin()

    try plugin.onBoot(kernel: KernelCoreContainer())
}
