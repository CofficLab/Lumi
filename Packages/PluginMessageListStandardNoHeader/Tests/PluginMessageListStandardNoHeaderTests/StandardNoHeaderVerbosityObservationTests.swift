import Foundation
import KernelCore
import ProviderChatSection
import ProviderConversation
import Testing
@testable import PluginMessageListStandardNoHeader

@MainActor
@Suite("V6 无消息头列表的 verbosity 观察")
struct StandardNoHeaderVerbosityObservationTests {
    @Test("V6 只在自己的 verbosity 下接管 message-list")
    func activatesOnlyForStandardNoHeader() throws {
        let kernel = KernelCoreContainer()
        let chat = DefaultChatSectionProviding()
        let conversations = DefaultConversationManager()
        try kernel.registerProvider((any ChatSectionProviding).self, chat)
        try kernel.registerProvider((any ConversationManaging).self, conversations)
        let plugin = PluginMessageListStandardNoHeaderPlugin()
        try plugin.onBoot(kernel: kernel)
        let conversationID = try conversations.createConversation(
            title: "V6 fixture",
            projectPath: nil,
            providerID: nil,
            modelName: nil
        )

        conversations.setVerbosity(.standard, for: conversationID)
        #expect(chat.items.first { $0.id == plugin.id }?.isActive() == false)

        conversations.setVerbosity(.standardNoHeader, for: conversationID)
        let item = try #require(chat.items.first { $0.id == plugin.id })
        #expect(item.isActive())
        #expect(item.exclusiveGroup == "message-list")
        #expect(item.fillsRemainingHeight)
        #expect(item.order == 82)
    }

    @Test("关闭插件会注销 ChatSection 贡献")
    func shutdownRemovesContribution() throws {
        let kernel = KernelCoreContainer()
        let chat = DefaultChatSectionProviding()
        try kernel.registerProvider((any ChatSectionProviding).self, chat)
        try kernel.registerProvider((any ConversationManaging).self, DefaultConversationManager())
        let plugin = PluginMessageListStandardNoHeaderPlugin()
        try plugin.onBoot(kernel: kernel)
        #expect(chat.items.contains { $0.id == plugin.id })

        try plugin.onShutdown(kernel: kernel)

        #expect(!chat.items.contains { $0.id == plugin.id })
    }
}
