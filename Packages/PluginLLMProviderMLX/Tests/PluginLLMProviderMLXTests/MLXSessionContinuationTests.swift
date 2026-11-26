import Foundation
import KitLLM
import Testing
@testable import PluginLLMProviderMLX

/// 跨轮复用 MLX 会话的判定。
///
/// 每回合的请求都携带完整历史，但只有「当前历史以已消费历史为精确前缀、
/// 且中间那条 assistant 与上一轮输出一致」时才能只追加后缀；其余情况
/// 必须重建，否则 KV 缓存会与提示词错位。
@Suite("MLX 会话续接判定")
struct MLXSessionContinuationTests {

    private let identity = MLXSessionContinuation.Identity(
        conversationID: UUID(),
        providerID: "com.coffic.lumi.plugin.llm-provider.mlx",
        modelID: "qwen3-4b",
        toolsSignature: "[]"
    )

    private func continuation(
        consumed: [LLMMessage],
        lastAssistant: LLMMessage?,
        identity: MLXSessionContinuation.Identity? = nil
    ) -> MLXSessionContinuation {
        MLXSessionContinuation(
            identity: identity ?? self.identity,
            consumedMessages: consumed,
            lastAssistant: lastAssistant
        )
    }

    @Test("历史前缀一致时只追加新增消息")
    func appendsOnlyNewMessages() {
        let consumed: [LLMMessage] = [
            LLMMessage(role: .system, content: "你是助手"),
            LLMMessage(role: .user, content: "第一问"),
        ]
        let assistant = LLMMessage(role: .assistant, content: "第一答")
        let messages = consumed + [assistant, LLMMessage(role: .user, content: "第二问")]

        let plan = continuation(consumed: consumed, lastAssistant: assistant)
            .plan(for: messages, identity: identity)

        #expect(plan == .appendSuffix(startIndex: 3))
    }

    @Test("工具调用参数相同即视为同一轮输出，id 不参与比较")
    func toolCallIdentityIgnoresIDs() {
        let produced = LLMMessage(
            role: .assistant,
            content: "",
            toolCalls: [LLMToolCall(id: "a", name: "get_weather", arguments: #"{"city":"Tokyo"}"#)]
        )
        let stored = LLMMessage(
            role: .assistant,
            content: "",
            toolCalls: [LLMToolCall(id: "b", name: "get_weather", arguments: #"{"city":"Tokyo"}"#)]
        )
        let consumed: [LLMMessage] = [LLMMessage(role: .user, content: "天气")]
        let messages = consumed + [
            stored,
            LLMMessage(role: .tool, content: "22°C", toolCallID: "b"),
        ]

        let plan = continuation(consumed: consumed, lastAssistant: produced)
            .plan(for: messages, identity: identity)

        #expect(plan == .appendSuffix(startIndex: 2))
    }

    @Test("历史前缀被编辑后必须重建")
    func prefixMismatchRebuilds() {
        let consumed: [LLMMessage] = [
            LLMMessage(role: .user, content: "第一问"),
        ]
        let assistant = LLMMessage(role: .assistant, content: "第一答")
        let messages = [
            LLMMessage(role: .user, content: "改过的第一问"),
            assistant,
            LLMMessage(role: .user, content: "第二问"),
        ]

        let plan = continuation(consumed: consumed, lastAssistant: assistant)
            .plan(for: messages, identity: identity)

        #expect(plan == .rebuild)
    }

    @Test("上一轮 assistant 被编辑或重新生成后必须重建")
    func assistantMismatchRebuilds() {
        let consumed: [LLMMessage] = [LLMMessage(role: .user, content: "第一问")]
        let produced = LLMMessage(role: .assistant, content: "原始回答")
        let messages = consumed + [
            LLMMessage(role: .assistant, content: "编辑后的回答"),
            LLMMessage(role: .user, content: "第二问"),
        ]

        let plan = continuation(consumed: consumed, lastAssistant: produced)
            .plan(for: messages, identity: identity)

        #expect(plan == .rebuild)
    }

    @Test("模型或工具集变化后必须重建")
    func identityChangeRebuilds() {
        let consumed: [LLMMessage] = [LLMMessage(role: .user, content: "第一问")]
        let assistant = LLMMessage(role: .assistant, content: "第一答")
        let messages = consumed + [assistant, LLMMessage(role: .user, content: "第二问")]
        let otherIdentity = MLXSessionContinuation.Identity(
            conversationID: identity.conversationID,
            providerID: identity.providerID,
            modelID: "llama-3.2-3b",
            toolsSignature: identity.toolsSignature
        )

        let plan = continuation(consumed: consumed, lastAssistant: assistant)
            .plan(for: messages, identity: otherIdentity)

        #expect(plan == .rebuild)
    }

    @Test("没有新增消息时（重新生成）必须重建")
    func nothingNewRebuilds() {
        let consumed: [LLMMessage] = [LLMMessage(role: .user, content: "第一问")]
        let assistant = LLMMessage(role: .assistant, content: "第一答")
        let messages = consumed + [assistant]

        let plan = continuation(consumed: consumed, lastAssistant: assistant)
            .plan(for: messages, identity: identity)

        #expect(plan == .rebuild)
    }

    @Test("历史短于已消费内容时重建")
    func shorterHistoryRebuilds() {
        let consumed: [LLMMessage] = [
            LLMMessage(role: .user, content: "第一问"),
            LLMMessage(role: .assistant, content: "第一答"),
        ]

        let plan = continuation(consumed: consumed, lastAssistant: nil)
            .plan(for: [LLMMessage(role: .user, content: "第一问")], identity: identity)

        #expect(plan == .rebuild)
    }
}