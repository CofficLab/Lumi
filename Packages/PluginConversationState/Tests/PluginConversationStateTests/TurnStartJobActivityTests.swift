import Foundation
import KitAgentTool
import ProviderAgentLoop
import ProviderConversationState
import ProviderLifecycleHooks
import ProviderToolManager
import Testing
@testable import PluginConversationState

/// 回归 #595：新回合开始时必须重置上一回合的 ToolJob 汇总。
///
/// Brief 的「等待你的确认」旁会拼接 `jobActivity.recentJobDescription`。
/// 需要授权的调用走 `executeBatch` 兼容路径，不创建 ToolJob、不发任何
/// ToolJobEvent，`ToolManagerStateObserver` 的 job map 清理逻辑永不触发；
/// 若 `AgentLoopStateObserver` 在 `.started` 时不重置 jobActivity，
/// 新回合的授权提示旁就会显示上一回合的工具描述。
@Suite("新回合重置 ToolJob 汇总")
struct TurnStartJobActivityTests {

    @Test("新回合的授权等待不得显示上一回合的工具描述")
    @MainActor
    func authorizationInNewTurnDoesNotShowPreviousTurnTool() {
        let conversationID = UUID()
        let turnA = UUID()
        let turnB = UUID()

        let loop = StartTestAgentLoop()
        let toolManager = StartTestToolManager()
        let provider = ConversationStateProvider()
        let loopObserver = AgentLoopStateObserver(agentLoop: loop, provider: provider)
        let toolObserver = ToolManagerStateObserver(toolManager: toolManager, provider: provider)

        // 回合 A：自动放行的工具创建 Job，汇总里留下可识别的描述。
        loop.emit(.started(conversationID: conversationID, turnID: turnA))
        let oldCall = ToolCall(
            id: "call_old",
            name: "run_command",
            arguments: "{\"command\":\"deploy-prod\"}"
        )
        let oldJob = ToolJob(
            conversationID: conversationID,
            turnID: turnA,
            toolCall: oldCall,
            status: .running
        )
        toolManager.emitJob(.started(oldJob))
        #expect(provider.state(for: conversationID).jobActivity.recentJobDescription != nil)

        // 回合 B 只调用需要授权的工具：授权路径不产生 ToolJobEvent。
        loop.emit(.started(conversationID: conversationID, turnID: turnB))
        toolManager.emit(.authorizationRequired(
            conversationID: conversationID,
            turnID: turnB,
            toolCall: ToolCall(
                id: "call_edit",
                name: "edit_file",
                arguments: "{\"file_path\":\"/tmp/x.swift\"}"
            )
        ))

        let snapshot = provider.state(for: conversationID)
        #expect(snapshot.authorizationState == .required)
        #expect(snapshot.activity == .waitingForUser)
        #expect(
            !snapshot.jobActivity.hasJobs,
            "新回合开始时必须重置上一回合的 ToolJob 汇总，否则授权提示旁会显示旧回合的工具描述"
        )
        #expect(snapshot.jobActivity.recentJobDescription == nil)

        loopObserver.cancel()
        toolObserver.cancel()
    }
}

// MARK: - Test Doubles

@MainActor
private final class StartTestAgentLoop: AgentLoopProviding {
    private var callback: ((AgentLoopEvent) -> Void)?
    var currentState: AgentLoopState = .running
    var activeTurnID: UUID?

    func addAgentLoopObserver(
        _ callback: @escaping (AgentLoopEvent) -> Void
    ) -> any AgentLoopObserverHandle {
        self.callback = callback
        return StartAgentLoopObserverHandle { [weak self] in
            self?.callback = nil
        }
    }

    func emit(_ event: AgentLoopEvent) {
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
private final class StartAgentLoopObserverHandle: AgentLoopObserverHandle {
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
private final class StartTestToolManager: ToolManagerProviding {
    private var managerCallback: ((ToolManagerEvent) -> Void)?
    private var jobCallback: ((ToolJobEvent) -> Void)?

    func addToolManagerObserver(
        _ callback: @escaping (ToolManagerEvent) -> Void
    ) -> any ToolManagerObserverHandle {
        managerCallback = callback
        return StartToolManagerObserverHandle { [weak self] in
            self?.managerCallback = nil
        }
    }

    func addToolJobObserver(
        _ callback: @escaping (ToolJobEvent) -> Void
    ) -> any ToolJobObserverHandle {
        jobCallback = callback
        return StartToolJobObserverHandle { [weak self] in
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
private final class StartToolManagerObserverHandle: ToolManagerObserverHandle {
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
private final class StartToolJobObserverHandle: ToolJobObserverHandle {
    private var cancellation: (() -> Void)?

    init(cancellation: @escaping () -> Void) {
        self.cancellation = cancellation
    }

    func cancel() {
        cancellation?()
        cancellation = nil
    }
}
