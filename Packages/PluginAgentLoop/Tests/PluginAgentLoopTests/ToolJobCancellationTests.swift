import Foundation
import Testing
import KitAgentTool
import KitLLM
import ProviderAgentLoop
import ProviderConversation
import ProviderLifecycleHooks
import ProviderMessage
import ProviderMessageStreaming
import ProviderLLMContext
import ProviderLLMManager
import ProviderToolManager
@testable import PluginAgentLoop

@MainActor
@Test("取消回合后迟到的 LLM 响应不会复活回合")
func lateLLMResponseAfterCancellationIsIgnored() async throws {
    let llmManager = BlockingLLMManager()
    let messages = DefaultMessageManager()
    let conversationID = UUID()
    let loop = AgentLoopManager(
        messages: messages,
        llmManager: llmManager,
        toolManager: DefaultToolManagerProviding(),
        streaming: DefaultMessageStreamingProviding(),
        conversations: DefaultConversationManager(),
        contextProvider: PassthroughLLMContextProvider(messages: messages)
    )

    let runTask = Task { @MainActor in
        do {
            return try await loop.runTurn(in: conversationID)
        } catch {
            return AgentLoopOutcome.failed(error.localizedDescription)
        }
    }

    for _ in 0..<40 where llmManager.requestCount == 0 {
        try await Task.sleep(nanoseconds: 5_000_000)
    }
    #expect(llmManager.requestCount == 1)

    loop.cancelTurn(in: conversationID)
    llmManager.release(response: LLMResponse(content: "迟到的响应"))

    let outcome = await runTask.value
    #expect(outcome == .cancelled)
    #expect(loop.state(for: conversationID) == .cancelled)
    #expect(llmManager.requestCount == 1)
    #expect(messages.messages(for: conversationID).filter { $0.role == .assistant }.isEmpty)
}

@MainActor
@Test("工具失败和超时都会回写错误并恢复 AgentLoop")
func terminalToolErrorsWakeAgentLoop() throws {
    for (status, content) in [
        (ToolJobStatus.failed, "Tool execution failed: boom"),
        (ToolJobStatus.timedOut, "Tool execution timed out: command timed out")
    ] {
        let messages = DefaultMessageManager()
        let conversationID = UUID()
        let turnID = UUID()
        let assistantMessageID = UUID()
        let toolCallID = "terminal-(status.rawValue)"
        let messageToolCall = MessageToolCall(id: toolCallID, name: "slow", arguments: "{}")
        messages.insertMessage(
            Message(
                id: assistantMessageID,
                conversationID: conversationID,
                role: .assistant,
                content: "",
                turnID: turnID,
                toolCalls: [messageToolCall]
            ),
            to: conversationID
        )

        let loop = AgentLoopManager(
            messages: messages,
            llmManager: DefaultLLMManager(),
            toolManager: DefaultToolManagerProviding(),
            streaming: DefaultMessageStreamingProviding(),
            conversations: DefaultConversationManager(),
            contextProvider: PassthroughLLMContextProvider(messages: messages)
        )
        loop.runtimes[conversationID] = TurnRuntime(
            phase: .waitingForToolJobs(
                turnID: turnID,
                assistantMessageID: assistantMessageID,
                pendingToolCalls: [messageToolCall],
                jobIDs: [toolCallID]
            )
        )
        let job = ToolJob(
            conversationID: conversationID,
            turnID: turnID,
            toolCall: ToolCall(id: toolCallID, name: "slow", arguments: "{}"),
            status: status
        )

        loop.handleToolJobEvent(.created(job))
        switch status {
        case .failed:
            loop.handleToolJobEvent(
                .failed(
                    jobID: toolCallID,
                    result: ToolCallResult(content: content, isError: true),
                    snapshot: job
                )
            )
        case .timedOut:
            loop.handleToolJobEvent(
                .timedOut(
                    jobID: toolCallID,
                    result: ToolCallResult(content: content, isError: true),
                    snapshot: job
                )
            )
        default:
            Issue.record("test case must use a terminal error")
        }

        let toolResult = messages.messages(for: conversationID).last {
            $0.role == .tool && $0.toolCallID == toolCallID
        }
        #expect(toolResult?.isError == true)
        #expect(toolResult?.content == content)
        #expect(loop.runtimes[conversationID]?.phase == .requestingLLM(turnID: turnID))
    }
}

@MainActor
@Test("取消后的迟到 Job 终态事件不会写回结果")
func lateToolJobCompletionAfterCancellationIsIgnored() {
    let messages = DefaultMessageManager()
    let conversationID = UUID()
    let turnID = UUID()
    let assistantMessageID = UUID()
    let toolCallID = "cancelled-job"
    let toolCall = MessageToolCall(id: toolCallID, name: "slow", arguments: "{}")
    messages.insertMessage(
        Message(
            id: assistantMessageID,
            conversationID: conversationID,
            role: .assistant,
            content: "",
            turnID: turnID,
            toolCalls: [toolCall]
        ),
        to: conversationID
    )
    let loop = AgentLoopManager(
        messages: messages,
        llmManager: DefaultLLMManager(),
        toolManager: DefaultToolManagerProviding(),
        streaming: DefaultMessageStreamingProviding(),
        conversations: DefaultConversationManager(),
        contextProvider: PassthroughLLMContextProvider(messages: messages)
    )
    loop.runtimes[conversationID] = TurnRuntime(
        phase: .waitingForToolJobs(
            turnID: turnID,
            assistantMessageID: assistantMessageID,
            pendingToolCalls: [toolCall],
            jobIDs: [toolCallID]
        )
    )

    loop.cancelTurn(in: conversationID)
    let job = ToolJob(
        conversationID: conversationID,
        turnID: turnID,
        toolCall: ToolCall(id: toolCallID, name: "slow", arguments: "{}"),
        status: .completed
    )
    loop.handleToolJobEvent(
        .completed(
            jobID: toolCallID,
            result: ToolCallResult(content: "late result"),
            snapshot: job
        )
    )

    #expect(loop.state(for: conversationID) == .cancelled)
    #expect(messages.messages(for: conversationID).filter { $0.role == .tool }.isEmpty)
}

@MainActor
private final class BlockingLLMManager: LLMManaging, LLMStreamingProviding, @unchecked Sendable {
    private(set) var requestCount = 0
    private var pendingResponse: CheckedContinuation<LLMResponse, Never>?

    var providerID: String { "blocking-test" }
    var providerInfo: LLMProviderInfo {
        LLMProviderInfo(
            id: providerID,
            displayName: "Blocking Test",
            defaultModel: "test-model",
            models: [LLMModelInfo(id: "test-model")],
            isLocal: true
        )
    }

    func complete(_ request: LLMRequest) async throws -> LLMResponse {
        try await streamComplete(request) { _ in }
    }

    func streamComplete(
        _ request: LLMRequest,
        onChunk: @escaping @Sendable (LLMStreamChunk) async -> Void
    ) async throws -> LLMResponse {
        requestCount += 1
        return await withCheckedContinuation { continuation in
            pendingResponse = continuation
        }
    }

    func release(response: LLMResponse) {
        pendingResponse?.resume(returning: response)
        pendingResponse = nil
    }

    func allProviders() -> [any SuperLLMProvider] { [self] }
    func provider(id: String) -> (any SuperLLMProvider)? { id == providerID ? self : nil }
    var providerCount: Int { 1 }
    func register(_ provider: any SuperLLMProvider) throws {}
    func unregister(id: String) {}
    var selectedProviderID: String? { providerID }
    var selectedModel: String? { "test-model" }
    func models(for providerID: String) -> [String] { ["test-model"] }
    func select(providerID: String, model: String?) {}
}
