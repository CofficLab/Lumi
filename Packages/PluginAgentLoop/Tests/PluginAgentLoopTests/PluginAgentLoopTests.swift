import Testing
import Foundation
import KitLLM
@testable import PluginAgentLoop
import ProviderAgentLoop
import ProviderConversation
import ProviderLifecycleHooks
import ProviderMessage

@MainActor
@Test func testPluginInitialization() async throws {
    let plugin = PluginAgentLoop()
    #expect(plugin.id == "com.coffic.lumi.plugin.agent-loop")
    #expect(plugin.order == 8)
}

@MainActor
@Test func testPluginMetadata() async throws {
    let plugin = PluginAgentLoop()
    let metadata = plugin.metadata
    #expect(metadata.name == "Plugin Agent Loop")
    #expect(metadata.category == .core)
}

@Test("willSendToLLM message restoration preserves assistant tool calls")
func testMessageFromLLMMessagePreservesToolCalls() {
    let conversationID = UUID()
    let message = LLMMessage(
        role: .assistant,
        content: "",
        toolCalls: [
            LLMToolCall(id: "tool-1", name: "run_command", arguments: "{\"command\":\"git status\"}")
        ],
        reasoningContent: "先检查状态"
    )

    let restored = messageFromLLMMessage(message, conversationID: conversationID)

    #expect(restored.conversationID == conversationID)
    #expect(restored.toolCalls == [
        MessageToolCall(id: "tool-1", name: "run_command", arguments: "{\"command\":\"git status\"}")
    ])
    #expect(restored.reasoningContent == "先检查状态")
}

@MainActor
@Test("挂起 ask_user 时发送新消息会跳过挂起点并恢复原回合")
func testMessageObserverResumesSuspendedTurnWhenUserContinuesChatting() async throws {
    let messages = DefaultMessageManager()
    let loop = RecordingAgentLoop()
    let observer = MessageObserver(messages: messages, agentLoop: loop)
    defer { observer.cancel() }

    let conversationID = UUID()
    messages.insertMessage(
        Message(
            conversationID: conversationID,
            role: .assistant,
            content: "",
            toolCalls: [
                MessageToolCall(
                    id: "ask-1",
                    name: "ask_user",
                    arguments: "{\"question\":\"继续吗?\",\"mode\":\"yes_no\"}",
                    result: MessageToolResult(
                        content: "{\"question\":\"继续吗?\"}",
                        awaitingUserResponse: true
                    )
                )
            ]
        ),
        to: conversationID
    )
    messages.insertMessage(
        Message(conversationID: conversationID, role: .user, content: "继续聊"),
        to: conversationID
    )

    // MessageObserver 通过 Task 异步消费消息插入事件。
    try await Task.sleep(nanoseconds: 50_000_000)

    #expect(loop.runTurnCallCount == 0)
    let request = try #require(loop.resumeRequests.first)
    #expect(request.suspensionID == "userInput:ask-1")
    #expect(request.answer.contains("without answering"))
}

@MainActor
@Test("挂起高风险工具审批时发送新消息不会绕过审批")
func testMessageObserverDoesNotSkipNonAskUserSuspension() async throws {
    let messages = DefaultMessageManager()
    let loop = RecordingAgentLoop(suspensionToolCallID: "approval-1")
    let observer = MessageObserver(messages: messages, agentLoop: loop)
    defer { observer.cancel() }

    let conversationID = UUID()
    messages.insertMessage(
        Message(
            conversationID: conversationID,
            role: .assistant,
            content: "",
            toolCalls: [
                MessageToolCall(
                    id: "approval-1",
                    name: "run_command",
                    arguments: "{}",
                    result: MessageToolResult(
                        content: "需要批准",
                        awaitingUserResponse: true
                    )
                )
            ]
        ),
        to: conversationID
    )
    messages.insertMessage(
        Message(conversationID: conversationID, role: .user, content: "继续聊"),
        to: conversationID
    )

    try await Task.sleep(nanoseconds: 50_000_000)

    #expect(loop.runTurnCallCount == 0)
    #expect(loop.resumeRequests.isEmpty)
}

@MainActor
private final class RecordingAgentLoop: AgentLoopProviding {
    private let pendingSuspension: AgentLoopSuspension

    private(set) var runTurnCallCount = 0
    private(set) var resumeRequests: [AgentTurnResumeRequest] = []

    init(suspensionToolCallID: String = "ask-1") {
        pendingSuspension = AgentLoopSuspension(
            suspensionID: "userInput:\(suspensionToolCallID)",
            conversationID: UUID(),
            toolCallID: suspensionToolCallID,
            kind: "userInput",
            payload: "{\"question\":\"继续吗?\"}"
        )
    }

    func addAgentLoopObserver(
        _ callback: @escaping (AgentLoopEvent) -> Void
    ) -> any AgentLoopObserverHandle {
        NoopAgentLoopObserverHandle()
    }

    func runTurn(in conversationID: UUID) async throws -> AgentLoopOutcome {
        runTurnCallCount += 1
        return .completed
    }

    func resumeTurn(
        in conversationID: UUID,
        request: AgentTurnResumeRequest
    ) async throws -> AgentLoopOutcome {
        resumeRequests.append(request)
        return .completed
    }

    func cancelTurn(in conversationID: UUID) {}

    func state(for conversationID: UUID) -> AgentLoopState { .suspended }

    func suspension(for conversationID: UUID) -> AgentLoopSuspension? {
        AgentLoopSuspension(
            suspensionID: pendingSuspension.suspensionID,
            conversationID: conversationID,
            toolCallID: pendingSuspension.toolCallID,
            kind: pendingSuspension.kind,
            payload: pendingSuspension.payload
        )
    }

    func isRunning(for conversationID: UUID) -> Bool { true }

    func currentTurnID(for conversationID: UUID) -> UUID? { nil }

    func setLifecycleHooks(_ hooks: (any LifecycleHooksProviding)?) {}
}

@MainActor
private final class NoopAgentLoopObserverHandle: AgentLoopObserverHandle {
    func cancel() {}
}
