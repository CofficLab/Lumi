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
        let messages = DefaultMessageManager()
        try kernel.registerProvider((any MessageManaging).self, messages, forwardsObjectWillChange: false)
        let agentLoop = StubAgentLoop(messages: messages)
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
        let messages = DefaultMessageManager()
        try kernel.registerProvider((any MessageManaging).self, messages, forwardsObjectWillChange: false)
        let agentLoop = StubAgentLoop(messages: messages)
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

/// 测试用 AgentLoop 桩：保留 responder 语义，落库 assistant 消息。
@MainActor
private final class StubAgentLoop: AgentLoopProviding {
    private let messages: any MessageManaging
    private var responder: AgentLoopResponder = { _ in "" }

    init(messages: any MessageManaging) {
        self.messages = messages
    }

    func setResponder(_ responder: AgentLoopResponder?) {
        if let responder { self.responder = responder }
    }

    func runTurn(in conversationID: UUID) async throws -> AgentLoopOutcome {
        let request = AgentLoopRequest(
            conversationID: conversationID,
            messages: messages.messages(for: conversationID)
        )
        let content = try await responder(request)
        messages.insertMessage(
            Message(conversationID: conversationID, role: .assistant, content: content),
            to: conversationID
        )
        return .completed
    }

    func resumeTurn(in conversationID: UUID, request: AgentTurnResumeRequest) async throws -> AgentLoopOutcome {
        throw AgentLoopError.invalidResumeRequest
    }

    func cancelTurn(in conversationID: UUID) {}
    func state(for conversationID: UUID) -> AgentLoopState { .idle }
    func suspension(for conversationID: UUID) -> AgentLoopSuspension? { nil }
    func isRunning(for conversationID: UUID) -> Bool { false }
    func currentTurnID(for conversationID: UUID) -> UUID? { nil }
}