import Foundation
import KernelCore
import ProviderAgentLoop
import ProviderConversation
import ProviderMessage
import ProviderMessageSender
import Testing
@testable import PluginMessageSender

@Suite("PluginMessageSender")
@MainActor
struct MessageSenderPluginTests {

    @Test("onBoot 解析基础 Provider 并注册自带 LumiMessageSender 实现")
    func pluginRegistersMessageSendingProvider() throws {
        let kernel = KernelCoreContainer()
        let conversations = DefaultConversationManager()
        try kernel.registerProvider((any ConversationManaging).self, conversations)
        let messages = DefaultMessageManaging()
        try kernel.registerProvider((any MessageManaging).self, messages, forwardsObjectWillChange: false)
        let agentLoop = DefaultAgentLoopProviding(messages: messages)
        try kernel.registerProvider((any AgentLoopProviding).self, agentLoop, forwardsObjectWillChange: false)

        // 走真实装配路径：`start(plugins:)` 会设置 activePluginID，
        // 使 `registerProvider` 记录 provider 归属（ownedByPlugin）。
        let plugin = MessageSenderPlugin()
        try kernel.start(plugins: [plugin])

        let sender = kernel.resolveProvider((any MessageSendingProviding).self)
        #expect(sender != nil)
        // 注册的是插件自带的实现，而不是 ProviderMessageSender 的 DefaultMessageSender。
        #expect(sender is LumiMessageSender)
        // 注册的实例归属于本插件，可被插件管理卸载/撤回
        #expect(kernel.isProvider((any MessageSendingProviding).self, ownedByPlugin: plugin.id))
    }

    @Test("缺依赖时 onBoot 不抛错且不注册（no-op 降级）")
    func pluginNoOpsWithoutDependencies() throws {
        let kernel = KernelCoreContainer()

        let plugin = MessageSenderPlugin()
        try plugin.onBoot(kernel: kernel)

        #expect(kernel.resolveProvider((any MessageSendingProviding).self) == nil)
    }

    @Test("注册后可通过 sendMessage 走完整发送链路")
    func registeredSenderSendsMessage() async throws {
        let kernel = KernelCoreContainer()
        let conversations = DefaultConversationManager()
        try kernel.registerProvider((any ConversationManaging).self, conversations)
        let messages = DefaultMessageManaging()
        try kernel.registerProvider((any MessageManaging).self, messages, forwardsObjectWillChange: false)
        let agentLoop = DefaultAgentLoopProviding(messages: messages)
        agentLoop.setResponder { _ in "response" }
        try kernel.registerProvider((any AgentLoopProviding).self, agentLoop, forwardsObjectWillChange: false)

        let plugin = MessageSenderPlugin()
        try plugin.onBoot(kernel: kernel)

        let sender = try #require(kernel.resolveProvider((any MessageSendingProviding).self))
        try await sender.sendMessage("hello", conversationID: nil)
        let id = try #require(conversations.selectedConversationID)
        #expect(messages.messages(for: id).map(\.content) == ["hello", "response"])
        #expect(sender.isSending == false)
    }
}
