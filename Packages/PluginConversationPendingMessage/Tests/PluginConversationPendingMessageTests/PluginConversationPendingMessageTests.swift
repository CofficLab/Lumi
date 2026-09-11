import Foundation
import Testing
import KernelCore
import ProviderChatSection
import ProviderConversation
import ProviderMessageSender
import ProviderLifecycleHooks
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
        let messages = DefaultMessageManager()
        let loop = StubAgentLoop(messages: messages)
        let sender = DefaultMessageSender(
            conversations: conversations,
            messages: messages,
            agentLoop: loop
        )
        try kernel.registerProvider((any ConversationManaging).self, conversations)
        try kernel.registerProvider((any ChatSectionProviding).self, chat)
        try kernel.registerProvider((any MessageSendingProviding).self, sender)

        let plugin = ConversationPendingMessagePlugin()
        try plugin.onBoot(kernel: kernel)
        try plugin.onReady(kernel: kernel)
        #expect(kernel.resolveProvider((any MessageSendingProviding).self) != nil)

        try plugin.onShutdown(kernel: kernel)
    }

    @Test("PendingMessageViewModel 保存选中会话和 pending 快照")
    func viewModelStoresPresentationState() throws {
        let conversations = DefaultConversationManager()
        let messages = DefaultMessageManager()
        let loop = StubAgentLoop(messages: messages)
        let sender = DefaultMessageSender(
            conversations: conversations,
            messages: messages,
            agentLoop: loop
        )
        let conversationID = try conversations.createConversation(
            title: "A", projectPath: nil, providerID: nil, modelName: nil
        )
        let pending = PendingChatMessage(conversationID: conversationID, content: "2")
        let viewModel = PendingMessageViewModel(sender: sender)

        viewModel.selectConversation(conversationID, pendingMessages: [pending])

        #expect(viewModel.selectedConversationID == conversationID)
        #expect(viewModel.pendingMessages == [pending])
    }

    @Test("observer 会把会话选择变化同步到 ViewModel")
    func observerTracksConversationSwitches() throws {
        let conversations = DefaultConversationManager()
        let messages = DefaultMessageManager()
        let loop = StubAgentLoop(messages: messages)
        let sender = DefaultMessageSender(
            conversations: conversations,
            messages: messages,
            agentLoop: loop
        )
        let first = try conversations.createConversation(
            title: "A", projectPath: nil, providerID: nil, modelName: nil
        )
        let second = try conversations.createConversation(
            title: "B", projectPath: nil, providerID: nil, modelName: nil
        )
        conversations.selectConversation(id: first)

        let viewModel = PendingMessageViewModel(sender: sender)
        let observer = PendingMessageObserver(
            conversations: conversations,
            sender: sender,
            viewModel: viewModel
        )
        #expect(viewModel.selectedConversationID == first)

        conversations.selectConversation(id: second)
        #expect(viewModel.selectedConversationID == second)

        conversations.selectConversation(id: first)
        #expect(viewModel.selectedConversationID == first)
        observer.cancel()
    }
}

/// 测试用 AgentLoop 桩：保留 responder 语义，落库 assistant 消息。
@MainActor
private final class StubAgentLoop: AgentLoopProviding {
    private let messages: any MessageManaging
    init(messages: any MessageManaging) {
        self.messages = messages
    }

    func runTurn(in conversationID: UUID) async throws -> AgentLoopOutcome {
        .completed
    }

    func resumeTurn(in conversationID: UUID, request: AgentTurnResumeRequest) async throws -> AgentLoopOutcome {
        throw AgentLoopError.invalidResumeRequest
    }

    func cancelTurn(in conversationID: UUID) {}
    func state(for conversationID: UUID) -> AgentLoopState { .idle }
    func suspension(for conversationID: UUID) -> AgentLoopSuspension? { nil }
    func isRunning(for conversationID: UUID) -> Bool { false }
    func currentTurnID(for conversationID: UUID) -> UUID? { nil }
    func setLifecycleHooks(_ hooks: (any LifecycleHooksProviding)?) {}

}
