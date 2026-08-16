import Foundation
import Testing
import KernelCore
import ProviderChatSection
import ProviderConversation
import ProviderMessageSender
import ProviderAgentLoop
import ProviderMessage

@testable import PluginConversationPendingMessage

@Suite("ConversationPendingMessagePlugin")
@MainActor
struct ConversationPendingMessagePluginTests {
    @Test("插件 onBoot 注册 bottom-fixed 待发列表且不抛错")
    func pluginLifecycle() throws {
        let kernel = KernelCoreContainer()
        let conversations = DefaultConversationManager()
        let chat = DefaultChatSectionProviding()
        let messages = DefaultMessageManaging()
        let loop = DefaultAgentLoopProviding(messages: messages)
        let sender = DefaultMessageSendingProviding(
            conversations: conversations,
            messages: messages,
            agentLoop: loop
        )
        try kernel.registerProvider((any ConversationManaging).self, conversations)
        try kernel.registerProvider((any ChatSectionProviding).self, chat)
        try kernel.registerProvider((any MessageSendingProviding).self, sender)

        let plugin = ConversationPendingMessagePlugin()
        try plugin.onBoot(kernel: kernel)
        #expect(kernel.resolveProvider((any MessageSendingProviding).self) != nil)

        try plugin.onShutdown(kernel: kernel)
    }

    @Test("ObservableMessageSendingBox 桥接 sender 状态")
    func boxBridges() {
        let conversations = DefaultConversationManager()
        let messages = DefaultMessageManaging()
        let loop = DefaultAgentLoopProviding(messages: messages)
        let sender = DefaultMessageSendingProviding(
            conversations: conversations,
            messages: messages,
            agentLoop: loop
        )
        let box = ObservableMessageSendingBox(sender: sender)
        #expect(box.sender.isSending == false)
    }
}
