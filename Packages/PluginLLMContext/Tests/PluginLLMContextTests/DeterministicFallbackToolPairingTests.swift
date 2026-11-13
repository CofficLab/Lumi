import Foundation
import KitLLM
import ProviderConversation
import ProviderLLMContext
import ProviderLLMManager
import ProviderMessage
import Testing

@testable import PluginLLMContext

/// 确定性降级的 tool-call / tool-result 配对保护（回归 #205）。
///
/// `fallbackSelection` 从新到旧按预算取用尾部消息：当 assistant 的 tool-call
/// 超预算被丢弃时，对应的 tool 结果会失去配对，provider 收到孤立的 tool 消息
/// 会直接返回 400。压缩路径 `compactedHistory` 已有配对保护，降级路径必须一致。
@MainActor
struct DeterministicFallbackToolPairingTests {
    /// 约 1,096 token 输入上限：触发确定性降级且不依赖摘要 Provider。
    private static func fallbackRequest(conversationID: UUID) -> LLMContextPreparationRequest {
        LLMContextPreparationRequest(
            conversationID: conversationID,
            providerID: nil,
            model: nil,
            budget: LLMContextBudget(
                contextWindowTokens: 4_096,
                reservedOutputTokens: 2_000,
                safetyMarginTokens: 1_000
            ),
            mode: .beforeSend
        )
    }

    private static func makeProvider() -> (LLMContextProvider, DefaultMessageManager) {
        let messages = DefaultMessageManager()
        let provider = LLMContextProvider(
            messages: messages,
            conversations: DefaultConversationManager(),
            llmProvider: DefaultLLMManager()
        )
        return (provider, messages)
    }

    /// 输出里任何 tool 结果都必须能在它之前找到携带同一 callID 的 assistant 调用。
    private func assertNoOrphanedToolResults(_ messages: [Message]) {
        for (index, message) in messages.enumerated() where message.role == .tool {
            let callID = message.toolCallID
            let paired = messages[..<index].contains { prior in
                prior.role == .assistant
                    && (prior.toolCalls ?? []).contains { $0.id == callID }
            }
            #expect(paired, "orphaned tool result: \(callID ?? "nil")")
        }
    }

    @Test("降级裁剪丢弃超预算 assistant 调用时，不能留下孤立的 tool 结果")
    func deterministicFallbackDropsOrphanedToolResult() async {
        let (provider, messages) = Self.makeProvider()
        let conversationID = UUID()
        let base = Date(timeIntervalSince1970: 1_000_000)

        messages.insertMessage(
            Message(
                conversationID: conversationID,
                role: .assistant,
                content: "",
                createdAt: base,
                toolCalls: [
                    MessageToolCall(
                        id: "call-orphan",
                        name: "f",
                        arguments: String(repeating: "a", count: 40_000)
                    )
                ]
            ),
            to: conversationID
        )
        messages.insertMessage(
            Message(
                conversationID: conversationID,
                role: .tool,
                content: "ok",
                createdAt: base.addingTimeInterval(1),
                toolCallID: "call-orphan"
            ),
            to: conversationID
        )
        messages.insertMessage(
            Message(
                conversationID: conversationID,
                role: .user,
                content: "continue",
                createdAt: base.addingTimeInterval(2)
            ),
            to: conversationID
        )

        let result = await provider.prepareContext(
            for: Self.fallbackRequest(conversationID: conversationID)
        )

        #expect(result.didFallback)
        assertNoOrphanedToolResults(result.messages)
        // assistant 调用装不下，对应的 tool 结果必须一起去掉，而不是单独保留。
        #expect(!result.messages.contains { $0.role == .tool })
        #expect(result.messages.contains { $0.role == .user })
        #expect(LLMContextTokenEstimator.estimate(messages: result.messages) <= result.inputTokenLimit)
    }

    @Test("降级裁剪保留装得下的 assistant 调用与配对的 tool 结果")
    func deterministicFallbackKeepsPairedToolResultWhenAssistantFits() async {
        let (provider, messages) = Self.makeProvider()
        let conversationID = UUID()
        let base = Date(timeIntervalSince1970: 1_000_000)

        // 一条超大的旧用户消息把整体估算推过硬阈值，触发降级；
        // 但最近的 assistant + tool + user 仍装得下，必须完整保留配对。
        messages.insertMessage(
            Message(
                conversationID: conversationID,
                role: .user,
                content: String(repeating: "old", count: 20_000),
                createdAt: base
            ),
            to: conversationID
        )
        messages.insertMessage(
            Message(
                conversationID: conversationID,
                role: .assistant,
                content: "calling",
                createdAt: base.addingTimeInterval(1),
                toolCalls: [MessageToolCall(id: "call-1", name: "f", arguments: "{}")]
            ),
            to: conversationID
        )
        messages.insertMessage(
            Message(
                conversationID: conversationID,
                role: .tool,
                content: "ok",
                createdAt: base.addingTimeInterval(2),
                toolCallID: "call-1"
            ),
            to: conversationID
        )
        messages.insertMessage(
            Message(
                conversationID: conversationID,
                role: .user,
                content: "continue",
                createdAt: base.addingTimeInterval(3)
            ),
            to: conversationID
        )

        let result = await provider.prepareContext(
            for: Self.fallbackRequest(conversationID: conversationID)
        )

        #expect(result.didFallback)
        assertNoOrphanedToolResults(result.messages)
        #expect(result.messages.contains { $0.role == .tool && $0.toolCallID == "call-1" })
        #expect(result.messages.contains {
            $0.role == .assistant && ($0.toolCalls ?? []).contains { $0.id == "call-1" }
        })
        #expect(LLMContextTokenEstimator.estimate(messages: result.messages) <= result.inputTokenLimit)
    }

    @Test("并行工具调用超预算时，所有孤立 tool 结果都要丢弃")
    func deterministicFallbackDropsAllParallelOrphanedToolResults() async {
        let (provider, messages) = Self.makeProvider()
        let conversationID = UUID()
        let base = Date(timeIntervalSince1970: 1_000_000)

        messages.insertMessage(
            Message(
                conversationID: conversationID,
                role: .assistant,
                content: "",
                createdAt: base,
                toolCalls: [
                    MessageToolCall(id: "c1", name: "f", arguments: String(repeating: "a", count: 40_000)),
                    MessageToolCall(id: "c2", name: "g", arguments: String(repeating: "b", count: 40_000))
                ]
            ),
            to: conversationID
        )
        messages.insertMessage(
            Message(
                conversationID: conversationID,
                role: .tool,
                content: "ok",
                createdAt: base.addingTimeInterval(1),
                toolCallID: "c1"
            ),
            to: conversationID
        )
        messages.insertMessage(
            Message(
                conversationID: conversationID,
                role: .tool,
                content: "ok",
                createdAt: base.addingTimeInterval(2),
                toolCallID: "c2"
            ),
            to: conversationID
        )
        messages.insertMessage(
            Message(
                conversationID: conversationID,
                role: .user,
                content: "continue",
                createdAt: base.addingTimeInterval(3)
            ),
            to: conversationID
        )

        let result = await provider.prepareContext(
            for: Self.fallbackRequest(conversationID: conversationID)
        )

        #expect(result.didFallback)
        assertNoOrphanedToolResults(result.messages)
        #expect(!result.messages.contains { $0.role == .tool })
        #expect(result.messages.contains { $0.role == .user })
        #expect(LLMContextTokenEstimator.estimate(messages: result.messages) <= result.inputTokenLimit)
    }
}
