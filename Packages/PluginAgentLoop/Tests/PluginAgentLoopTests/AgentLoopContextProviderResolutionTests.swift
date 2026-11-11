import Foundation
import KernelCore
import ProviderAgentLoop
import ProviderConversation
import ProviderLLMContext
import ProviderLLMManager
import ProviderMessage
import ProviderMessageStreaming
import ProviderToolManager
import Testing

@testable import PluginAgentLoop

// MARK: - Fixtures

/// 记录自己被调用的上下文 Provider。
@MainActor
private final class RecordingLLMContextProvider: LLMContextProviding {
    private let messages: any MessageManaging
    private(set) var prepareCallCount = 0

    init(messages: any MessageManaging) {
        self.messages = messages
    }

    func messagesForLLM(in conversationID: UUID) async -> [Message] {
        await messages.messagesForLLM(in: conversationID)
    }

    func prepareContext(
        for request: LLMContextPreparationRequest
    ) async -> LLMContextPreparationResult {
        prepareCallCount += 1
        let messages = await messagesForLLM(in: request.conversationID)
        return LLMContextPreparationResult(
            messages: messages,
            estimatedInputTokens: LLMContextTokenEstimator.estimate(messages: messages),
            inputTokenLimit: request.budget.inputTokenLimit,
            estimateSource: .estimated
        )
    }
}

// MARK: - Tests

@MainActor
@Suite("AgentLoop 上下文 Provider 解析")
struct AgentLoopContextProviderResolutionTests {

    @Test("onBoot 后注册的真实上下文 Provider 会被后续请求使用")
    func laterRegisteredProviderIsUsed() throws {
        let kernel = KernelCoreContainer()
        let messages = DefaultMessageManager()
        try kernel.registerProvider((any MessageManaging).self, messages)
        try kernel.registerProvider((any LLMManaging).self, DefaultLLMManager())
        try kernel.registerProvider((any ToolManagerProviding).self, DefaultToolManagerProviding())
        try kernel.registerProvider((any MessageStreamingProviding).self, DefaultMessageStreamingProviding())
        try kernel.registerProvider((any ConversationManaging).self, DefaultConversationManager())

        // 启动阶段只有降级的透传实现。
        let passthrough = PassthroughLLMContextProvider(messages: messages)
        try kernel.registerProvider((any LLMContextProviding).self, passthrough)

        let plugin = PluginAgentLoop()
        try plugin.onBoot(kernel: kernel)

        guard let manager = kernel.resolveProvider((any AgentLoopProviding).self) as? AgentLoopManager else {
            Issue.record("AgentLoopProviding 未注册为 AgentLoopManager")
            return
        }

        // 启动后真实实现替换了内核注册表里的降级实现。
        let real = RecordingLLMContextProvider(messages: messages)
        kernel.unregisterProvider((any LLMContextProviding).self)
        try kernel.registerProvider((any LLMContextProviding).self, real)

        // AgentLoop 必须使用真实实现，而不是启动阶段捕获的透传实现。
        #expect(manager.contextProvider === real)
    }

    @Test("内核注册表里没有上下文 Provider 时回退到启动阶段的快照")
    func fallsBackToStartupSnapshot() throws {
        let kernel = KernelCoreContainer()
        let messages = DefaultMessageManager()
        try kernel.registerProvider((any MessageManaging).self, messages)
        try kernel.registerProvider((any LLMManaging).self, DefaultLLMManager())
        try kernel.registerProvider((any ToolManagerProviding).self, DefaultToolManagerProviding())
        try kernel.registerProvider((any MessageStreamingProviding).self, DefaultMessageStreamingProviding())
        try kernel.registerProvider((any ConversationManaging).self, DefaultConversationManager())

        let passthrough = PassthroughLLMContextProvider(messages: messages)
        try kernel.registerProvider((any LLMContextProviding).self, passthrough)

        let plugin = PluginAgentLoop()
        try plugin.onBoot(kernel: kernel)

        guard let manager = kernel.resolveProvider((any AgentLoopProviding).self) as? AgentLoopManager else {
            Issue.record("AgentLoopProviding 未注册为 AgentLoopManager")
            return
        }

        kernel.unregisterProvider((any LLMContextProviding).self)

        #expect(manager.contextProvider === passthrough)
    }
}
