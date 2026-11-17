import Foundation
import ProviderAgentLoop
import ProviderLifecycleHooks
import Testing
@testable import PluginConversationStats

/// 回归覆盖 issue #802：ask_user 挂起等待用户回答时，工具栏仍亮橙色 Running。
///
/// 工具栏此前用 `agentLoop.isRunning(for:)` 判断是否显示 Running，而 FSM 的
/// `isRunning` 把 `.awaitingUser` 也算作运行中（语义是「回合仍活跃、可恢复/停止」）。
/// 等待用户输入时既没有 LLM 请求也没有工具任务在执行，不该亮 Running。
/// 修复限定在工具栏：改用 `state(for:) == .running`，它把挂起区分成 `.suspended`，
/// 不改动全局 `isRunning` 语义。
@Suite("Agent turn 工具栏 Running 判定")
@MainActor
struct AgentTurnStatusToolbarRunningTests {

    @Test("挂起等待用户回答时不得显示 Running（即使 isRunning 为真）")
    func suspendedDoesNotShowRunning() {
        // 复现 FSM 的语义分歧：awaitingUser 时 isRunning=true 但 state=.suspended。
        let agentLoop = MockAgentLoop(state: .suspended, isRunning: true)
        #expect(AgentTurnStatusToolbarView.showsRunning(agentLoop: agentLoop, conversationID: UUID()) == false)
    }

    @Test("真正执行 LLM/工具时显示 Running")
    func runningShowsRunning() {
        let agentLoop = MockAgentLoop(state: .running, isRunning: true)
        #expect(AgentTurnStatusToolbarView.showsRunning(agentLoop: agentLoop, conversationID: UUID()) == true)
    }

    @Test("空闲与终态都不显示 Running")
    func idleAndTerminalDoNotShowRunning() {
        for state in [AgentLoopState.idle, .completed, .failed, .cancelled] {
            let agentLoop = MockAgentLoop(state: state, isRunning: false)
            #expect(AgentTurnStatusToolbarView.showsRunning(agentLoop: agentLoop, conversationID: UUID()) == false)
        }
    }

    @Test("没有选中会话时不显示 Running")
    func nilConversationDoesNotShowRunning() {
        let agentLoop = MockAgentLoop(state: .running, isRunning: true)
        #expect(AgentTurnStatusToolbarView.showsRunning(agentLoop: agentLoop, conversationID: nil) == false)
    }
}

/// `state` 与 `isRunning` 独立可配，刻意复现二者在 `.awaitingUser` 下的分歧。
@MainActor
private final class MockAgentLoop: AgentLoopProviding {
    private let stateValue: AgentLoopState
    private let runningFlag: Bool

    init(state: AgentLoopState, isRunning: Bool) {
        self.stateValue = state
        self.runningFlag = isRunning
    }

    func addAgentLoopObserver(_ callback: @escaping (AgentLoopEvent) -> Void) -> any AgentLoopObserverHandle {
        MockHandle()
    }
    func runTurn(in conversationID: UUID) async throws -> AgentLoopOutcome { .completed }
    func resumeTurn(in conversationID: UUID, request: AgentTurnResumeRequest) async throws -> AgentLoopOutcome { .completed }
    func cancelTurn(in conversationID: UUID) {}
    func state(for conversationID: UUID) -> AgentLoopState { stateValue }
    func suspension(for conversationID: UUID) -> AgentLoopSuspension? { nil }
    func isRunning(for conversationID: UUID) -> Bool { runningFlag }
    func currentTurnID(for conversationID: UUID) -> UUID? { nil }
    func setLifecycleHooks(_ hooks: (any LifecycleHooksProviding)?) {}
}

@MainActor
private final class MockHandle: AgentLoopObserverHandle {
    func cancel() {}
}