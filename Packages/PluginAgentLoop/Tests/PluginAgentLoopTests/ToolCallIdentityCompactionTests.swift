import Foundation
import KitLLM
import ProviderConversation
import ProviderLLMContext
import ProviderLLMManager
import ProviderMessage
import ProviderMessageStreaming
import ProviderToolManager
import Testing

@testable import PluginAgentLoop

/// 回归 #1024：同回合较早的工具调用被上下文压缩掉后，provider 复用同一个
/// tool-call ID 时必须仍然拿到新 ID，否则 ToolManager 会把新调用当成旧 Job。
@MainActor
@Suite("压缩历史下的工具调用身份归一化")
struct ToolCallIdentityCompactionTests {
    @Test("被压缩掉的同回合工具调用 ID 仍会被归一化")
    func compressedTurnToolCallIDIsStillNormalized() async throws {
        let fixture = Fixture()
        let conversationID = UUID()
        let turnID = UUID()

        // 同一回合较早的 ls_0 已落库，但压缩后的上下文里没有它们。
        fixture.seedAssistantToolCall(
            conversationID: conversationID,
            turnID: turnID,
            toolCallID: "ls_0"
        )
        fixture.loop.runtimes[conversationID] = TurnRuntime(
            phase: .requestingLLM(turnID: turnID),
            lastTurnID: turnID
        )

        let result = await fixture.loop.performLLMRequest(
            conversationID: conversationID,
            turnID: turnID
        )

        guard case let .success(response, assistantMessageID) = result else {
            Issue.record("请求应当成功，实际为 \(result)")
            return
        }
        let normalizedIDs = response.toolCalls?.map(\.id) ?? []
        #expect(normalizedIDs.count == 1)
        #expect(normalizedIDs.first != "ls_0")

        let persisted = fixture.messages.message(id: assistantMessageID, in: conversationID)
        #expect(persisted?.toolCalls?.first?.id == normalizedIDs.first)
    }

    @Test("其他回合的工具调用 ID 不参与本回合去重")
    func otherTurnToolCallIDIsNotReserved() async throws {
        let fixture = Fixture()
        let conversationID = UUID()
        let turnID = UUID()
        let otherTurnID = UUID()

        fixture.seedAssistantToolCall(
            conversationID: conversationID,
            turnID: otherTurnID,
            toolCallID: "ls_0"
        )
        fixture.loop.runtimes[conversationID] = TurnRuntime(
            phase: .requestingLLM(turnID: turnID),
            lastTurnID: turnID
        )

        let result = await fixture.loop.performLLMRequest(
            conversationID: conversationID,
            turnID: turnID
        )

        guard case let .success(response, _) = result else {
            Issue.record("请求应当成功，实际为 \(result)")
            return
        }
        #expect(response.toolCalls?.map(\.id) == ["ls_0"])
    }
}

@MainActor
private final class Fixture {
    let messages = DefaultMessageManager()
    let loop: AgentLoopManager

    init() {
        let messages = self.messages
        let llm = ReusingToolCallLLMManager()
        // 压缩后的上下文里只有用户消息，较早的 assistant/tool 配对都已被移出。
        loop = AgentLoopManager(
            messages: messages,
            llmManager: llm,
            toolManager: DefaultToolManagerProviding(),
            streaming: DefaultMessageStreamingProviding(),
            conversations: DefaultConversationManager(),
            contextProvider: FixedHistoryLLMContextProvider(
                history: [Message(conversationID: UUID(), role: .user, content: "继续")]
            )
        )
    }

    func seedAssistantToolCall(
        conversationID: UUID,
        turnID: UUID,
        toolCallID: String
    ) {
        messages.insertMessage(
            Message(
                conversationID: conversationID,
                role: .assistant,
                content: "listing",
                turnID: turnID,
                toolCalls: [
                    MessageToolCall(id: toolCallID, name: "ls", arguments: "{}"),
                ]
            ),
            to: conversationID
        )
        messages.insertMessage(
            Message(
                conversationID: conversationID,
                role: .tool,
                content: "done",
                turnID: turnID,
                toolCallID: toolCallID
            ),
            to: conversationID
        )
        messages.insertMessage(
            Message(conversationID: conversationID, role: .user, content: "继续"),
            to: conversationID
        )
    }
}

@MainActor
private final class FixedHistoryLLMContextProvider: LLMContextProviding {
    private let history: [Message]

    init(history: [Message]) {
        self.history = history
    }

    func messagesForLLM(in conversationID: UUID) async -> [Message] {
        _ = conversationID
        return history
    }
}

@MainActor
private final class ReusingToolCallLLMManager: LLMManaging, LLMStreamingProviding, @unchecked Sendable {
    private let provider = ReusingToolCallProvider()

    var providerID: String { provider.providerID }
    var providerInfo: LLMProviderInfo { provider.providerInfo }

    func complete(_ request: LLMRequest) async throws -> LLMResponse {
        LLMResponse(content: "ok", model: request.model)
    }

    func streamComplete(
        _ request: LLMRequest,
        onChunk: @escaping @Sendable (LLMStreamChunk) async -> Void
    ) async throws -> LLMResponse {
        _ = onChunk
        return LLMResponse(
            content: "",
            model: request.model,
            toolCalls: [
                LLMToolCall(id: "ls_0", name: "ls", arguments: "{}"),
            ]
        )
    }

    func allProviders() -> [any SuperLLMProvider] { [provider] }
    func provider(id: String) -> (any SuperLLMProvider)? { id == provider.providerID ? provider : nil }
    var providerCount: Int { 1 }
    func register(_ provider: any SuperLLMProvider) throws {}
    func unregister(id: String) {}
    var selectedProviderID: String? { provider.providerID }
    var selectedModel: String? { provider.providerInfo.defaultModel }
    func models(for providerID: String) -> [String] { provider.providerInfo.modelIDs }
    func select(providerID: String, model: String?, reason: ModelSelectionReason) {}
}

@MainActor
private final class ReusingToolCallProvider: SuperLLMProvider {
    let providerInfo = LLMProviderInfo(
        id: "reusing-tool-call-provider",
        displayName: "Reusing Tool Call Provider",
        defaultModel: "reusing-model",
        models: [LLMModelInfo(id: "reusing-model")],
        isLocal: true
    )

    var providerID: String { providerInfo.id }

    func complete(_ request: LLMRequest) async throws -> LLMResponse {
        LLMResponse(content: "ok", model: request.model)
    }
}
