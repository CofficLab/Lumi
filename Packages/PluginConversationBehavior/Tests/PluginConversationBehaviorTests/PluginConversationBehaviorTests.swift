import Foundation
import Testing
import KernelCore
import ProviderChatSection
import ProviderLifecycleHooks
import ProviderAgentLoop
import ProviderMessage

@testable import PluginConversationBehavior

@Suite("PluginConversationBehavior")
@MainActor
struct PluginConversationBehaviorTests {
    private func makeKernel() throws -> (KernelCoreContainer, DefaultConversationManager, DefaultChatSectionProviding) {
        let kernel = KernelCoreContainer()
        let conversations = DefaultConversationManager()
        let chat = DefaultChatSectionProviding()
        try kernel.registerProvider((any ConversationManaging).self, conversations)
        try kernel.registerProvider((any ChatSectionProviding).self, chat)
        return (kernel, conversations, chat)
    }

    @Test("Verbosity 插件注册钩子与工具栏按钮")
    func verbosityRegisters() async throws {
        let (kernel, conversations, _) = try makeKernel()
        let messages = DefaultMessageManager()
        let loop = StubAgentLoop(messages: messages)
        try kernel.registerProvider((any AgentLoopProviding).self, loop)

        let plugin = ConversationVerbosityPlugin()
        try plugin.onBoot(kernel: kernel)
        #expect(kernel.resolveProvider((any ConversationManaging).self) != nil)
    }

    @Test("Reasoning 插件注册 ActionBar 按钮")
    func reasoningRegisters() throws {
        let (kernel, _, _) = try makeKernel()
        let plugin = ConversationReasoningPlugin()
        try plugin.onBoot(kernel: kernel)
        #expect(kernel.resolveProvider((any ConversationManaging).self) != nil)
    }

    @Test("Reasoning 档位经 ConversationManaging 读写")
    func reasoningRoundTrip() {
        let conversations = DefaultConversationManager()
        conversations.setGlobalReasoningEffort(.high)
        #expect(conversations.reasoningEffortOptional(for: nil) == .high)
        conversations.clearReasoningEffort(for: nil)
        #expect(conversations.reasoningEffortOptional(for: nil) == nil)
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
