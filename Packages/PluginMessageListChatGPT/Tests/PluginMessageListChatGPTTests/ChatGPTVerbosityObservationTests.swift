import Foundation
import KernelCore
import ProviderChatSection
import ProviderConversation
import Testing
@testable import PluginMessageListChatGPT

@MainActor
@Suite("ChatGPT verbosity observation")
struct ChatGPTVerbosityObservationTests {
    @Test("V5 activates only its own message-list contribution")
    func activatesOnlyForChatGPT() throws {
        let kernel = KernelCoreContainer()
        let chat = DefaultChatSectionProviding()
        let conversations = DefaultConversationManager()
        try kernel.registerProvider((any ChatSectionProviding).self, chat)
        try kernel.registerProvider((any ConversationManaging).self, conversations)
        let plugin = PluginMessageListChatGPTPlugin()
        try plugin.onBoot(kernel: kernel)
        let conversationID = try conversations.createConversation(
            title: "ChatGPT fixture",
            projectPath: nil,
            providerID: nil,
            modelName: nil
        )

        conversations.setVerbosity(.standard, for: conversationID)
        #expect(chat.items.first { $0.id == plugin.id }?.isActive() == false)

        conversations.setVerbosity(.chatGPT, for: conversationID)
        let item = try #require(chat.items.first { $0.id == plugin.id })
        #expect(item.isActive())
        #expect(item.exclusiveGroup == "message-list")
        #expect(item.fillsRemainingHeight)
        #expect(item.order == 82)
    }

    @Test("Shutdown cancels observation and removes the contribution")
    func shutdownRemovesContribution() throws {
        let kernel = KernelCoreContainer()
        let chat = DefaultChatSectionProviding()
        try kernel.registerProvider((any ChatSectionProviding).self, chat)
        try kernel.registerProvider((any ConversationManaging).self, DefaultConversationManager())
        let plugin = PluginMessageListChatGPTPlugin()
        try plugin.onBoot(kernel: kernel)
        #expect(chat.items.contains { $0.id == plugin.id })

        try plugin.onShutdown(kernel: kernel)

        #expect(!chat.items.contains { $0.id == plugin.id })
    }
}
