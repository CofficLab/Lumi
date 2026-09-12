import Foundation
import KitLLM
import KernelCore
import ProviderChatSection
import ProviderConversation
import ProviderLLMManager
import ProviderMessage
import Testing
@testable import PluginConversationContextSize

@Test func tokenFormatting() async throws {
    #expect(1000.formattedTokensShort == "1K")
    #expect(1500.formattedTokensShort == "2K")
    #expect(0.formattedTokensShort == "0K")
    #expect((-1).formattedTokensShort == "0K")
    #expect(999.formattedTokensShort == "1K")
    #expect(1001.formattedTokensShort == "2K")
    #expect(Int.max.formattedTokensShort == "9223372036854776K")
    #expect(128000.formattedContextSize == "128K")
    #expect(999999.formattedContextSize == "999K")
    #expect(1000000.formattedContextSize == "1M")
    #expect(1500000.formattedContextSize == "1.5M")
}

@Test @MainActor func contextSizeToolbarStateForwardsTypedEvents() {
    let state = ContextSizeToolbarState()
    let conversationID = UUID()
    var eventCount = 0
    let handle = state.addObserver { _ in eventCount += 1 }

    state.setSelectedConversationID(conversationID)
    state.markMessagesChanged(conversationID: conversationID)
    state.markLLMChanged()

    #expect(eventCount == 3)
    handle.cancel()
    state.markLLMChanged()
    #expect(eventCount == 3)
}

@MainActor
@Test func contextSizeObserverForwardsChangesAndStopsAfterCancellation() async throws {
    let conversations = DefaultConversationManager()
    let messages = DefaultMessageManager()
    let llmManager = DefaultLLMManager()
    let provider = ContextSizeTestLLMProvider()
    try llmManager.register(provider)

    var selectedConversations: [UUID?] = []
    var insertedMessages: [UUID] = []
    var llmChanges = 0
    let observer = ContextSizeObserver(
        conversations: conversations,
        messages: messages,
        llmManager: llmManager,
        onConversationChange: { selectedConversations.append($0) },
        onMessageInsert: { insertedMessages.append($0) },
        onLLMChange: { llmChanges += 1 }
    )

    #expect(selectedConversations.count == 1)
    #expect(selectedConversations.first! == nil)
    #expect(insertedMessages.isEmpty)
    #expect(llmChanges == 0)

    let conversationID = try conversations.createConversation(
        title: "Context size",
        projectPath: nil,
        providerID: nil,
        modelName: nil
    )
    let otherConversationID = UUID()
    messages.insertMessage(
        Message(conversationID: otherConversationID, role: .user, content: "Other"),
        to: otherConversationID
    )
    messages.insertMessage(
        Message(conversationID: conversationID, role: .user, content: "Current"),
        to: conversationID
    )
    llmManager.select(providerID: provider.providerID, model: "another-model")

    #expect(selectedConversations == [nil, conversationID])
    #expect(insertedMessages == [otherConversationID, conversationID])
    #expect(llmChanges == 1)

    observer.cancel()
    observer.cancel()
    conversations.deselectConversation()
    messages.insertMessage(
        Message(conversationID: conversationID, role: .assistant, content: "Done"),
        to: conversationID
    )
    llmManager.select(providerID: provider.providerID, model: "third-model")

    #expect(selectedConversations == [nil, conversationID])
    #expect(insertedMessages.count == 2)
    #expect(llmChanges == 1)
}

@MainActor
@Test func pluginRegistersAndRemovesItsToolbarItem() throws {
    let kernel = KernelCoreContainer()
    let chat = DefaultChatSectionProviding()
    try kernel.registerProvider((any ChatSectionProviding).self, chat)
    try kernel.registerProvider((any ConversationManaging).self, DefaultConversationManager())
    try kernel.registerProvider((any MessageManaging).self, DefaultMessageManager())
    try kernel.registerProvider((any LLMManaging).self, DefaultLLMManager())

    let plugin = ConversationContextSizePlugin()
    try plugin.onBoot(kernel: kernel)
    #expect(chat.barItems.map(\.id) == ["\(plugin.id).toolbar-button"])

    try plugin.onShutdown(kernel: kernel)
    #expect(chat.barItems.isEmpty)
}

@MainActor
@Test func pluginSkipsBootWhenARequiredProviderIsMissing() throws {
    let plugin = ConversationContextSizePlugin()
    try plugin.onBoot(kernel: KernelCoreContainer())
    try plugin.onShutdown(kernel: KernelCoreContainer())
}

@MainActor
private final class ContextSizeTestLLMProvider: SuperLLMProvider, @unchecked Sendable {
    let providerID = "context-size-test"
    let providerInfo = LLMProviderInfo(
        id: "context-size-test",
        displayName: "Context Size Test",
        defaultModel: "default-model",
        models: [],
        isLocal: true
    )

    func complete(_ request: LLMRequest) async throws -> LLMResponse {
        LLMResponse(content: "")
    }
}
