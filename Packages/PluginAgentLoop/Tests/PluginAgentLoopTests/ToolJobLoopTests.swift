import Foundation
import KitLLM
import KitAgentTool
import ProviderAgentLoop
import ProviderMessage
import ProviderConversation
import ProviderLLMContext
import ProviderLLMManager
import ProviderMessageStreaming
import ProviderToolManager
import Testing
@testable import PluginAgentLoop

@Test("工具 Job 创建后进入等待态，全部完成后才恢复请求 LLM")
func toolJobsTransitionThroughWaitingPhase() {
    let turnID = UUID()
    let assistantMessageID = UUID()
    let response = LLMResponse(
        content: "",
        toolCalls: [
            LLMToolCall(id: "job-1", name: "first", arguments: "{}"),
            LLMToolCall(id: "job-2", name: "second", arguments: "{}"),
        ]
    )

    let started = TurnReducer.reduce(
        TurnRuntime(),
        event: .startTurn(turnID: turnID)
    )
    let executing = TurnReducer.reduce(
        started.0,
        event: .llmResponded(response: response, assistantMessageID: assistantMessageID)
    )

    let firstCreated = TurnReducer.reduce(
        executing.0,
        event: .toolJobCreated(jobID: "job-1")
    )
    guard case let .waitingForToolJobs(_, assistantID, pending, jobIDs) = firstCreated.0.phase else {
        Issue.record("第一个 Job 创建后应进入 waitingForToolJobs")
        return
    }
    #expect(assistantID == assistantMessageID)
    #expect(pending.map(\.id) == ["job-1", "job-2"])
    #expect(jobIDs == ["job-1"])

    let secondCreated = TurnReducer.reduce(
        firstCreated.0,
        event: .toolJobCreated(jobID: "job-2")
    )
    guard case let .waitingForToolJobs(_, _, pendingAfterCreation, jobIDsAfterCreation) = secondCreated.0.phase else {
        Issue.record("第二个 Job 创建后仍应处于 waitingForToolJobs")
        return
    }
    #expect(pendingAfterCreation.map(\.id) == ["job-1", "job-2"])
    #expect(jobIDsAfterCreation == ["job-1", "job-2"])

    let firstCompleted = TurnReducer.reduce(
        secondCreated.0,
        event: .toolJobCompleted(
            toolCallID: "job-1",
            result: MessageToolResult(content: "first result")
        )
    )
    guard case let .waitingForToolJobs(_, _, pendingAfterFirst, remainingJobIDs) = firstCompleted.0.phase else {
        Issue.record("一个 Job 完成后仍应等待其余 Job")
        return
    }
    #expect(pendingAfterFirst.map(\.id) == ["job-2"])
    #expect(remainingJobIDs == ["job-2"])

    let allCompleted = TurnReducer.reduce(
        firstCompleted.0,
        event: .toolJobCompleted(
            toolCallID: "job-2",
            result: MessageToolResult(content: "second result")
        )
    )
    #expect(allCompleted.0.phase == .requestingLLM(turnID: turnID))
    #expect(allCompleted.1 == nil)
}

@Test("取消等待中的工具 Job 后不会被迟到完成事件重新唤醒")
func cancellingWaitingToolJobsIgnoresLateCompletion() {
    let turnID = UUID()
    let started = TurnReducer.reduce(
        TurnRuntime(),
        event: .startTurn(turnID: turnID)
    )
    let executing = TurnReducer.reduce(
        started.0,
        event: .llmResponded(
            response: LLMResponse(
                content: "",
                toolCalls: [LLMToolCall(id: "job-1", name: "slow", arguments: "{}")]
            ),
            assistantMessageID: UUID()
        )
    )
    let waiting = TurnReducer.reduce(
        executing.0,
        event: .toolJobCreated(jobID: "job-1")
    )
    let cancelled = TurnReducer.reduce(waiting.0, event: .cancel)
    #expect(cancelled.0.phase == .cancelled)
    #expect(cancelled.1 == .cancelled)

    let lateCompletion = TurnReducer.reduce(
        cancelled.0,
        event: .toolJobCompleted(
            toolCallID: "job-1",
            result: MessageToolResult(content: "too late")
        )
    )
    #expect(lateCompletion.0.phase == .cancelled)
    #expect(lateCompletion.1 == nil)
}

@Test("未知工具 Job 不会修改等待中的 pending 集合")
func unknownToolJobEventIsIgnoredByReducer() {
    let turnID = UUID()
    let started = TurnReducer.reduce(
        TurnRuntime(),
        event: .startTurn(turnID: turnID)
    )
    let executing = TurnReducer.reduce(
        started.0,
        event: .llmResponded(
            response: LLMResponse(
                content: "",
                toolCalls: [LLMToolCall(id: "job-1", name: "slow", arguments: "{}")]
            ),
            assistantMessageID: UUID()
        )
    )
    let waiting = TurnReducer.reduce(
        executing.0,
        event: .toolJobCreated(jobID: "job-1")
    )
    let ignored = TurnReducer.reduce(
        waiting.0,
        event: .toolJobCompleted(
            toolCallID: "stale-job",
            result: MessageToolResult(content: "stale")
        )
    )
    #expect(ignored.0.phase == waiting.0.phase)
    #expect(ignored.1 == nil)
}

@Test("审批挂起期间其他 Job 完成时保留挂起点并消费结果")
func completedSiblingJobDuringApprovalRemovesOnlyItsPendingCall() {
    let turnID = UUID()
    let assistantMessageID = UUID()
    let firstCall = MessageToolCall(id: "job-1", name: "read", arguments: "{}")
    let approvalCall = MessageToolCall(id: "job-2", name: "write", arguments: "{}")
    let started = TurnReducer.reduce(
        TurnRuntime(),
        event: .startTurn(turnID: turnID)
    )
    let executing = TurnReducer.reduce(
        started.0,
        event: .llmResponded(
            response: LLMResponse(
                content: "",
                toolCalls: [
                    LLMToolCall(id: firstCall.id, name: firstCall.name, arguments: firstCall.arguments),
                    LLMToolCall(id: approvalCall.id, name: approvalCall.name, arguments: approvalCall.arguments),
                ]
            ),
            assistantMessageID: assistantMessageID
        )
    )
    let firstCreated = TurnReducer.reduce(executing.0, event: .toolJobCreated(jobID: firstCall.id))
    let bothCreated = TurnReducer.reduce(firstCreated.0, event: .toolJobCreated(jobID: approvalCall.id))
    let suspension = AgentLoopSuspension(
        suspensionID: "userInput:\(approvalCall.id)",
        conversationID: UUID(),
        toolCallID: approvalCall.id,
        kind: "permission",
        payload: "需要批准"
    )
    let awaiting = TurnReducer.reduce(
        bothCreated.0,
        event: .toolNeedsUserInput(toolCallID: approvalCall.id, suspension: suspension)
    )
    let siblingCompleted = TurnReducer.reduce(
        awaiting.0,
        event: .toolJobCompleted(
            toolCallID: firstCall.id,
            result: MessageToolResult(content: "read result")
        )
    )

    guard case let .awaitingUser(_, _, pending, activeSuspension) = siblingCompleted.0.phase else {
        Issue.record("审批挂起期间应继续保持 awaitingUser")
        return
    }
    #expect(pending.isEmpty)
    #expect(activeSuspension == suspension)
}

@MainActor
@Test("Job 完成事件会回写 assistant 工具调用并恢复下一轮 LLM")
func completedToolJobResumesAgentLoop() {
    let messages = DefaultMessageManager()
    let conversationID = UUID()
    let turnID = UUID()
    let assistantMessageID = UUID()
    let toolCallID = "integration-job-1"
    let toolCall = MessageToolCall(
        id: toolCallID,
        name: "slow_tool",
        arguments: "{}"
    )
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
        phase: .executingTools(
            turnID: turnID,
            assistantMessageID: assistantMessageID,
            pendingToolCalls: [toolCall]
        )
    )

    let job = ToolJob(
        conversationID: conversationID,
        turnID: turnID,
        toolCall: KitAgentTool.ToolCall(id: toolCallID, name: "slow_tool", arguments: "{}"),
        status: .running
    )
    loop.handleToolJobEvent(.created(job))
    loop.handleToolJobEvent(
        .completed(
            jobID: toolCallID,
            result: ToolCallResult(content: "job result"),
            snapshot: job
        )
    )

    let updatedToolCall = messages
        .message(id: assistantMessageID, in: conversationID)?
        .toolCalls?.first(where: { $0.id == toolCallID })
    #expect(updatedToolCall?.result?.content == "job result")
    #expect(messages.messages(for: conversationID).contains {
        $0.role == .tool && $0.toolCallID == toolCallID && $0.content == "job result"
    })
    #expect(loop.currentTurnID(for: conversationID) == turnID)
    #expect(loop.runtimes[conversationID]?.phase == .requestingLLM(turnID: turnID))
}

@MainActor
@Test("取消 Agent 回合时会先取消对应的 Tool Job")
func cancellingAgentTurnCancelsAssociatedJobs() {
    let toolManager = CancellationTrackingToolManager()
    let conversations = DefaultConversationManager()
    let messages = DefaultMessageManager()
    let loop = AgentLoopManager(
        messages: messages,
        llmManager: DefaultLLMManager(),
        toolManager: toolManager,
        streaming: DefaultMessageStreamingProviding(),
        conversations: conversations,
        contextProvider: PassthroughLLMContextProvider(messages: messages)
    )
    let conversationID = UUID()
    let turnID = UUID()
    let assistantMessageID = UUID()
    loop.runtimes[conversationID] = TurnRuntime(
        phase: .waitingForToolJobs(
            turnID: turnID,
            assistantMessageID: assistantMessageID,
            pendingToolCalls: [MessageToolCall(id: "cancel-job", name: "slow", arguments: "{}")],
            jobIDs: ["cancel-job"]
        )
    )

    loop.cancelTurn(in: conversationID)

    #expect(toolManager.cancelledTurnID == turnID)
    #expect(loop.state(for: conversationID) == .cancelled)
}

@MainActor
private final class CancellationTrackingToolManager: ToolManagerProviding {
    private(set) var cancelledTurnID: UUID?

    @discardableResult
    func addToolManagerObserver(
        _ callback: @escaping (ToolManagerEvent) -> Void
    ) -> any ToolManagerObserverHandle {
        NoopToolManagerObserverHandle()
    }

    @discardableResult
    func addToolJobObserver(
        _ callback: @escaping (ToolJobEvent) -> Void
    ) -> any ToolJobObserverHandle {
        NoopToolJobObserverHandle()
    }

    func allTools() -> [any SuperAgentTool] { [] }
    func add(_ tool: any SuperAgentTool, pluginID: String) {}
    func remove(id: String) {}
    func toolsGroupedByPlugin() -> [(pluginID: String, tools: [any SuperAgentTool])] { [] }
    func tool(named name: String) -> (any SuperAgentTool)? { nil }
    func displayDescription(for toolCall: KitAgentTool.ToolCall) -> String? { nil }
    func riskLevel(for toolCall: KitAgentTool.ToolCall) -> CommandRiskLevel? { nil }
    func authorizationDecision(
        for toolCall: KitAgentTool.ToolCall,
        conversationID: UUID
    ) -> ToolAuthorizationDecision { .autoApproved }
    func execute(
        _ toolCall: KitAgentTool.ToolCall,
        conversationID: UUID,
        turnID: UUID?
    ) async -> ToolCallResult { ToolCallResult(content: "unused") }
    func toolCalls(for turnID: UUID) async -> [ToolCallRecord] { [] }
    func toolCallResult(for toolCallID: String) async -> ToolCallResult? { nil }
    func deleteToolCalls(for conversationID: UUID) async {}

    func cancelJobs(forTurnID turnID: UUID) {
        cancelledTurnID = turnID
    }
}

@MainActor
private final class NoopToolManagerObserverHandle: ToolManagerObserverHandle {
    func cancel() {}
}

@MainActor
private final class NoopToolJobObserverHandle: ToolJobObserverHandle {
    func cancel() {}
}
