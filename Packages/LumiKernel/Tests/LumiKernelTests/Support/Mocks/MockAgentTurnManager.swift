import Foundation
@testable import LumiKernel

/// 测试用 `AgentTurnManaging` 实现。
///
/// 通过 `runTurnError` 模拟回合失败、通过 `gate` 把回合挂起到受控时刻,
/// 用于断言发送管道对"失败回溯""队列消费""取消"等场景的编排规则。
@MainActor
final class MockAgentTurnManager: AgentTurnManaging {
    let log: OrchestrationEventLog?

    /// 非 nil 时 `runTurn` 抛出该错误(模拟 LLM/工具失败)。
    var runTurnError: Error?

    /// 非 nil 时 `runTurn` 在其上 `wait()`,直到外部 `release()` 放行。
    var gate: TurnGate?

    /// `runTurn` 进入的次数(含挂起期间)。
    private(set) var runTurnCount = 0

    /// `cancelTurn` 被调用的次数。
    private(set) var cancelTurnCount = 0

    init(log: OrchestrationEventLog? = nil) {
        self.log = log
    }

    func runTurn(in conversationID: UUID) async throws -> AgentTurnOutcome {
        runTurnCount += 1
        log?.record("runTurn")
        if let runTurnError { throw runTurnError }
        if let gate { await gate.wait() }
        return .completed
    }

    func cancelTurn(in conversationID: UUID) {
        cancelTurnCount += 1
        log?.record("cancelTurn")
    }

    func isRunning(for conversationID: UUID) -> Bool { false }
}
