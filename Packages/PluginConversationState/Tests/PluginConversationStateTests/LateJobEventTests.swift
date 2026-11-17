import Foundation
import KitAgentTool
import ProviderAgentLoop
import ProviderConversationState
import ProviderLifecycleHooks
import ProviderToolManager
import Testing
@testable import PluginConversationState

/// 回归 #536：旧回合被取消后，迟到的 ToolJob 事件不得改写新回合的投影。
///
/// ToolJob 事件异步投递；旧回合残余的 output / 终态事件若不按当前回合
/// 过滤，会清空新回合的 job 汇总、把 turnID 回退成旧回合、甚至把
/// 「正在执行」活动清掉。
@Suite("迟到 ToolJob 事件按当前回合过滤")
struct LateJobEventTests {

    @Test("旧回合迟到的 Job 事件不得改写新回合的投影（#536）")
    @MainActor
    func lateOldTurnJobEventDoesNotRewriteNewTurnProjection() {
        let conversationID = UUID()
        let turnA = UUID()
        let turnB = UUID()

        let loop = LateTestAgentLoop()
        let toolManager = LateTestToolManager()
        let provider = ConversationStateProvider()
        let loopObserver = AgentLoopStateObserver(agentLoop: loop, provider: provider)
        let toolObserver = ToolManagerStateObserver(toolManager: toolManager, provider: provider)

        // 回合 A 启动一个工具 Job。
        loop.emit(.started(conversationID: conversationID, turnID: turnA))
        var oldJob = ToolJob(
            conversationID: conversationID,
            turnID: turnA,
            toolCall: ToolCall(
                id: "call_old",
                name: "run_command",
                arguments: "{\"command\":\"deploy-prod\"}"
            ),
            status: .running
        )
        toolManager.emitJob(.started(oldJob))
        #expect(provider.state(for: conversationID).jobActivity.currentJobCount == 1)

        // 回合 B 开始，job 汇总重置（#595），并进入新的工具批次。
        loop.emit(.started(conversationID: conversationID, turnID: turnB))
        toolManager.emit(.started(
            conversationID: conversationID,
            turnID: turnB,
            toolCall: ToolCall(id: "call_new", name: "read_file", arguments: "{}")
        ))
        let running = provider.state(for: conversationID)
        #expect(running.turnID == turnB)
        #expect(running.activity == .executingTool)

        // A 的迟到 output 事件：不得清空 B 的 job 汇总、不得回退 turnID。
        oldJob.updatedAt = oldJob.updatedAt.addingTimeInterval(5)
        toolManager.emitJob(.output(
            jobID: oldJob.id,
            stream: .stdout,
            chunk: "late output",
            snapshot: oldJob
        ))
        let afterOutput = provider.state(for: conversationID)
        #expect(afterOutput.turnID == turnB, "迟到事件不得把 turnID 回退成旧回合")
        #expect(
            !afterOutput.jobActivity.hasJobs,
            "迟到事件不得把旧回合的 Job 并入新回合的汇总"
        )
        #expect(afterOutput.activity == .executingTool)

        // A 的迟到终态事件：不得清掉 B 的「正在执行」活动。
        oldJob.status = .cancelled
        toolManager.emitJob(.cancelled(
            jobID: oldJob.id,
            result: ToolCallResult(content: "cancelled", isError: true),
            snapshot: oldJob
        ))
        let afterCancel = provider.state(for: conversationID)
        #expect(afterCancel.turnID == turnB)
        #expect(afterCancel.agentLoopState == .running)
        #expect(afterCancel.toolState == .executing)
        #expect(
            afterCancel.activity == .executingTool,
            "迟到终态事件不得清掉新回合的执行中活动"
        )

        loopObserver.cancel()
        toolObserver.cancel()
    }

    @Test("当前回合的 Job 事件不受迟到过滤影响（#536 护栏）")
    @MainActor
    func currentTurnJobEventsStillIngested() {
        let conversationID = UUID()
        let turnA = UUID()
        let turnB = UUID()

        let loop = LateTestAgentLoop()
        let toolManager = LateTestToolManager()
        let provider = ConversationStateProvider()
        let loopObserver = AgentLoopStateObserver(agentLoop: loop, provider: provider)
        let toolObserver = ToolManagerStateObserver(toolManager: toolManager, provider: provider)

        loop.emit(.started(conversationID: conversationID, turnID: turnA))
        var oldJob = ToolJob(
            conversationID: conversationID,
            turnID: turnA,
            toolCall: ToolCall(id: "call_old", name: "run_command", arguments: "{}"),
            status: .running
        )
        toolManager.emitJob(.started(oldJob))

        loop.emit(.started(conversationID: conversationID, turnID: turnB))
        oldJob.status = .cancelled
        toolManager.emitJob(.cancelled(
            jobID: oldJob.id,
            result: ToolCallResult(content: "cancelled", isError: true),
            snapshot: oldJob
        ))
        #expect(!provider.state(for: conversationID).jobActivity.hasJobs)

        // 新回合自己的 Job 事件必须照常并入汇总。
        var newJob = ToolJob(
            conversationID: conversationID,
            turnID: turnB,
            toolCall: ToolCall(id: "call_new", name: "read_file", arguments: "{}"),
            status: .running
        )
        toolManager.emitJob(.started(newJob))
        let runningState = provider.state(for: conversationID)
        #expect(runningState.turnID == turnB)
        #expect(runningState.jobActivity.currentJobCount == 1)
        #expect(runningState.jobActivity.runningJobCount == 1)
        #expect(runningState.activity == .executingTool)

        newJob.status = .completed
        toolManager.emitJob(.completed(
            jobID: newJob.id,
            result: ToolCallResult(content: "ok"),
            snapshot: newJob
        ))
        let completedState = provider.state(for: conversationID)
        #expect(completedState.jobActivity.currentJobCount == 1)
        #expect(completedState.jobActivity.runningJobCount == 0)
        #expect(completedState.activity == nil, "当前回合 Job 终态后 activity 应被清理")

        loopObserver.cancel()
        toolObserver.cancel()
    }
}

// MARK: - Test Doubles

@MainActor
private final class LateTestAgentLoop: AgentLoopProviding {
    private var callback: ((AgentLoopEvent) -> Void)?
    var currentState: AgentLoopState = .running
    var activeTurnID: UUID?

    func addAgentLoopObserver(
        _ callback: @escaping (AgentLoopEvent) -> Void
    ) -> any AgentLoopObserverHandle {
        self.callback = callback
        return LateAgentLoopObserverHandle { [weak self] in
            self?.callback = nil
        }
    }

    func emit(_ event: AgentLoopEvent) {
        if case .started(_, let turn) = event { activeTurnID = turn }
        callback?(event)
    }

    func runTurn(in conversationID: UUID) async throws -> AgentLoopOutcome { .completed }

    func resumeTurn(
        in conversationID: UUID,
        request: AgentTurnResumeRequest
    ) async throws -> AgentLoopOutcome { .completed }

    func cancelTurn(in conversationID: UUID) {}

    func state(for conversationID: UUID) -> AgentLoopState { currentState }

    func suspension(for conversationID: UUID) -> AgentLoopSuspension? { nil }

    func lastFailure(for conversationID: UUID) -> AgentLoopFailure? { nil }

    func isRunning(for conversationID: UUID) -> Bool { true }

    func currentTurnID(for conversationID: UUID) -> UUID? { activeTurnID }

    func isAutoReplySuppressed(for conversationID: UUID) -> Bool { false }

    func setAutoReplySuppressed(_ suppressed: Bool, for conversationID: UUID) {}

    func retryTurn(
        in conversationID: UUID,
        after failedTurnID: UUID
    ) async throws -> AgentLoopOutcome { .completed }

    func setLifecycleHooks(_ hooks: (any LifecycleHooksProviding)?) {}
}

@MainActor
private final class LateAgentLoopObserverHandle: AgentLoopObserverHandle {
    private var cancellation: (() -> Void)?

    init(cancellation: @escaping () -> Void) {
        self.cancellation = cancellation
    }

    func cancel() {
        cancellation?()
        cancellation = nil
    }
}

@MainActor
private final class LateTestToolManager: ToolManagerProviding {
    private var managerCallback: ((ToolManagerEvent) -> Void)?
    private var jobCallback: ((ToolJobEvent) -> Void)?

    func addToolManagerObserver(
        _ callback: @escaping (ToolManagerEvent) -> Void
    ) -> any ToolManagerObserverHandle {
        managerCallback = callback
        return LateToolManagerObserverHandle { [weak self] in
            self?.managerCallback = nil
        }
    }

    func addToolJobObserver(
        _ callback: @escaping (ToolJobEvent) -> Void
    ) -> any ToolJobObserverHandle {
        jobCallback = callback
        return LateToolJobObserverHandle { [weak self] in
            self?.jobCallback = nil
        }
    }

    func emit(_ event: ToolManagerEvent) {
        managerCallback?(event)
    }

    func emitJob(_ event: ToolJobEvent) {
        jobCallback?(event)
    }

    // MARK: Unused protocol requirements

    func submit(
        _ toolCalls: [ToolCall],
        policy: ToolExecutionPolicy,
        conversationID: UUID,
        turnID: UUID?
    ) -> [ToolJob] { [] }

    func allTools() -> [any SuperAgentTool] { [] }
    func add(_ tool: any SuperAgentTool, pluginID: String) {}
    func remove(id: String) {}
    func toolsGroupedByPlugin() -> [(pluginID: String, tools: [any SuperAgentTool])] { [] }
    func tool(named name: String) -> (any SuperAgentTool)? { nil }
    func displayDescription(for toolCall: ToolCall) -> String? { nil }
    func riskLevel(for toolCall: ToolCall) -> CommandRiskLevel? { .high }
    func authorizationDecision(
        for toolCall: ToolCall,
        conversationID: UUID
    ) -> ToolAuthorizationDecision { .requiresUserApproval }
    func execute(
        _ toolCall: ToolCall,
        conversationID: UUID,
        turnID: UUID?
    ) async -> ToolCallResult { ToolCallResult(content: "") }
    func executeAuthorized(
        _ toolCall: ToolCall,
        conversationID: UUID,
        turnID: UUID?
    ) async -> ToolCallResult { ToolCallResult(content: "") }
    func rejectAuthorized(
        _ toolCall: ToolCall,
        conversationID: UUID,
        turnID: UUID?
    ) async -> ToolCallResult { ToolCallResult(content: "") }
    func resolveUserResponse(
        _ answer: String,
        for toolCall: ToolCall,
        conversationID: UUID,
        turnID: UUID?
    ) async -> ToolCallResult { ToolCallResult(content: answer) }
    func executeBatch(
        _ toolCalls: [ToolCall],
        policy: ToolExecutionPolicy,
        conversationID: UUID,
        turnID: UUID?
    ) async -> [BatchToolResult] { [] }
    func toolCalls(for turnID: UUID) async -> [ToolCallRecord] { [] }
    func toolCallResult(for toolCallID: String) async -> ToolCallResult? { nil }
    func deleteToolCalls(for conversationID: UUID) async {}
}

@MainActor
private final class LateToolManagerObserverHandle: ToolManagerObserverHandle {
    private var cancellation: (() -> Void)?

    init(cancellation: @escaping () -> Void) {
        self.cancellation = cancellation
    }

    func cancel() {
        cancellation?()
        cancellation = nil
    }
}

@MainActor
private final class LateToolJobObserverHandle: ToolJobObserverHandle {
    private var cancellation: (() -> Void)?

    init(cancellation: @escaping () -> Void) {
        self.cancellation = cancellation
    }

    func cancel() {
        cancellation?()
        cancellation = nil
    }
}
