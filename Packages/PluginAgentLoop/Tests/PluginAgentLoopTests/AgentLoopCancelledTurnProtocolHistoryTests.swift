import Foundation
import KernelCore
import KitAgentTool
import KitLLM
import ProviderAgentLoop
import ProviderConversation
import ProviderLLMContext
import ProviderLLMManager
import ProviderMessage
import ProviderMessageStreaming
import ProviderToolManager
import Testing
@testable import PluginAgentLoop

/// 停止部分完成的多工具回合后，历史必须是协议完整的。
///
/// ## 为什么要有这条测试
///
/// 一次 assistant 响应可以请求多个工具：自动执行的 A 先完成，审批中的 B
/// 一直挂着。此时按下停止，B 的结果只写进了 assistant 消息的**嵌套**结果，
/// 没有独立的 `role == .tool` 消息。
///
/// 于是持久化的历史是：
/// ```
/// assistant: toolCalls = [A, B]
/// tool:      toolCallID = A, content = "done"
/// user:      "continue"
/// ```
/// B 的 `tool_call` 没有对应的结果。OpenAI / Anthropic 协议都要求同一次
/// assistant 回合里的每个 tool call 都有结果，新请求会在模型看到新消息
/// 之前就被上游拒绝——用户无法继续对话。
@MainActor
@Suite("取消多工具回合后的协议历史")
struct AgentLoopCancelledTurnProtocolHistoryTests {

    /// 记录请求的 LLM 管理器替身。
    private final class RecordingLLMManager: LLMManaging, LLMStreamingProviding, @unchecked Sendable {
        private(set) var requests: [LLMRequest] = []

        var providerID: String { Self.managerProviderID }
        var providerInfo: LLMProviderInfo {
            LLMProviderInfo(id: providerID, displayName: "Test Manager", defaultModel: "", models: [], isLocal: true)
        }

        func complete(_ request: LLMRequest) async throws -> LLMResponse {
            requests.append(request)
            return LLMResponse(content: "ok", model: request.model)
        }

        func streamComplete(
            _ request: LLMRequest,
            onChunk: @escaping @Sendable (LLMStreamChunk) async -> Void
        ) async throws -> LLMResponse {
            requests.append(request)
            return LLMResponse(content: "ok", model: request.model)
        }

        func allProviders() -> [any SuperLLMProvider] { [] }
        func provider(id: String) -> (any SuperLLMProvider)? { nil }
        var providerCount: Int { 0 }
        func register(_ provider: any SuperLLMProvider) throws {}
        func unregister(id: String) {}
        var selectedProviderID: String? { nil }
        var selectedModel: String? { nil }
        func models(for providerID: String) -> [String] { [] }
        func select(providerID: String, model: String?, reason: ModelSelectionReason) {}
    }

    private func makeManager(
        llmManager: any LLMManaging,
        messages: DefaultMessageManager
    ) -> AgentLoopManager {
        AgentLoopManager(
            messages: messages,
            llmManager: llmManager,
            toolManager: DefaultToolManagerProviding(),
            streaming: DefaultMessageStreamingProviding(),
            conversations: DefaultConversationManager(),
            contextProvider: PassthroughLLMContextProvider(messages: messages)
        )
    }

    /// 检查会话历史里每个 assistant 的 tool_call 都有对应的 tool 消息。
    private func assertProtocolHistoryIsComplete(_ messages: [Message]) {
        for message in messages where message.role == .assistant {
            let declared = message.toolCalls?.map(\.id) ?? []
            guard !declared.isEmpty else { continue }
            let answered = Set(
                messages
                    .filter { $0.role == .tool }
                    .compactMap(\.toolCallID)
            )
            for callID in declared {
                #expect(
                    answered.contains(callID),
                    "assistant 的 tool_call \(callID) 没有对应的 tool 消息，历史不完整"
                )
            }
        }
    }

    @Test("取消挂起的回合后，每个 tool_call 都有对应的 tool 消息")
    func cancelledTurnLeavesCompleteProtocolHistory() async throws {
        let messages = DefaultMessageManager()
        let llmManager = RecordingLLMManager()
        let manager = makeManager(llmManager: llmManager, messages: messages)
        let conversationID = UUID()

        // 一条 assistant 消息声明了两个工具调用：A 已完成，B 仍在等待授权。
        let assistant = Message(
            conversationID: conversationID,
            role: .assistant,
            content: "",
            toolCalls: [
                MessageToolCall(id: "call_a", name: "tool_a", arguments: "{}"),
                MessageToolCall(id: "call_b", name: "tool_b", arguments: "{}"),
            ]
        )
        messages.insertMessage(assistant, to: conversationID)

        // A 的独立 tool 消息已经落库。
        messages.insertMessage(
            Message(
                conversationID: conversationID,
                role: .tool,
                content: "done",
                toolCallID: "call_a"
            ),
            to: conversationID
        )

        // B 处于等待授权的挂起态。
        messages.updateToolCallResult(
            MessageToolResult(
                content: "",
                isError: false,
                awaitingUserResponse: true
            ),
            toolCallID: "call_b",
            assistantMessageID: assistant.id,
            in: conversationID,
            authorizationState: ToolCallAuthorizationState.pendingAuthorization.rawValue
        )

        // 构造真实的挂起态：`cancelTurn` 要求回合正在运行。
        let turnID = UUID()
        let suspension = AgentLoopSuspension(
            suspensionID: "userInput:call_b",
            conversationID: conversationID,
            toolCallID: "call_b",
            kind: "userInput",
            payload: "{}"
        )
        var runtime = TurnRuntime()
        runtime.phase = .awaitingUser(
            turnID: turnID,
            assistantMessageID: assistant.id,
            pendingToolCalls: [MessageToolCall(id: "call_b", name: "tool_b", arguments: "{}")],
            suspension: suspension
        )
        runtime.lastTurnID = turnID
        manager.runtimes[conversationID] = runtime

        manager.cancelTurn(in: conversationID)

        assertProtocolHistoryIsComplete(messages.messages(for: conversationID))
    }
}
