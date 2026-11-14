import Foundation
import ProviderAgentLoop
import ProviderConversation
import ProviderMessage
import Testing
@testable import PluginMessageSender

/// 锁定恢复回合终态的单次处理（#164）。
///
/// 恢复回合有两条终态来源：AgentLoop 的异步终态事件与 `resumeTurn` 返回后
/// 的补偿逻辑。此前两条路径各自通知完成并排空队列，两条排队消息会被连续
/// 发出，破坏同一会话的串行语义。
@Suite("MessageSender 恢复回合终态去重（#164）")
@MainActor
struct MessageSenderResumeDedupTests {

    @Test("终态事件先到达时，补偿路径不得重复通知或二次排空")
    func eventFirstDoesNotDoubleDrain() async throws {
        let fixture = SenderFixture()
        let conversationID = try fixture.conversations.createConversation(
            title: nil, projectPath: nil, providerID: nil, modelName: nil
        )
        var outcomes: [AgentLoopOutcome] = []
        let observer = fixture.sender.addMessageSenderObserver { event in
            if case .turnCompleted(_, let outcome) = event, outcome.isTerminal { outcomes.append(outcome) }
        }
        defer { observer.cancel() }

        let turnA = UUID()
        try await suspendTurn(fixture, conversationID: conversationID, turnID: turnA)
        _ = try fixture.sender.commitUserMessage("second", conversationID: conversationID)
        _ = try fixture.sender.commitUserMessage("third", conversationID: conversationID)
        #expect(fixture.sender.pendingMessages(for: conversationID).count == 2)

        // 真实时序：AgentLoop 先投递终态事件，再释放 resumeTurn 的等待者。
        fixture.agentLoop.currentState = .completed
        fixture.agentLoop.resumeOutcome = .completed
        fixture.agentLoop.onResume = { id in
            fixture.agentLoop.notify(.completed(conversationID: id, turnID: turnA))
        }
        let outcome = try await fixture.sender.resumeTurn(
            in: conversationID,
            request: AgentTurnResumeRequest(suspensionID: "userInput:approval-1", answer: "allow")
        )
        #expect(outcome == .completed)

        // 只通知一次完成；只发出第二条消息，第三条必须等下一条回合结束。
        #expect(outcomes == [.completed])
        #expect(fixture.sender.pendingMessages(for: conversationID).count == 1)
        #expect(fixture.messages.messages(for: conversationID).map(\.content) == ["first", "second"])
        #expect(fixture.sender.isSending)

        // 第二条消息的回合结束后才轮到第三条。
        let turnB = UUID()
        fixture.sender.handleAgentLoopEvent(.started(conversationID: conversationID, turnID: turnB))
        fixture.sender.handleAgentLoopEvent(.completed(conversationID: conversationID, turnID: turnB))
        await waitUntil { fixture.sender.pendingMessages(for: conversationID).isEmpty }
        #expect(fixture.messages.messages(for: conversationID).map(\.content) == ["first", "second", "third"])
        let turnC = UUID()
        fixture.sender.handleAgentLoopEvent(.started(conversationID: conversationID, turnID: turnC))
        fixture.sender.handleAgentLoopEvent(.completed(conversationID: conversationID, turnID: turnC))
        await waitUntil { !fixture.sender.isSending }
        #expect(outcomes == [.completed, .completed, .completed])
    }

    @Test("补偿路径先处理时，迟到的终态事件不得重复通知或二次排空")
    func compensationFirstDoesNotDoubleDrain() async throws {
        let fixture = SenderFixture()
        let conversationID = try fixture.conversations.createConversation(
            title: nil, projectPath: nil, providerID: nil, modelName: nil
        )
        var outcomes: [AgentLoopOutcome] = []
        let observer = fixture.sender.addMessageSenderObserver { event in
            if case .turnCompleted(_, let outcome) = event, outcome.isTerminal { outcomes.append(outcome) }
        }
        defer { observer.cancel() }

        let turnA = UUID()
        try await suspendTurn(fixture, conversationID: conversationID, turnID: turnA)
        _ = try fixture.sender.commitUserMessage("second", conversationID: conversationID)
        _ = try fixture.sender.commitUserMessage("third", conversationID: conversationID)

        // 桩不投递事件：补偿路径先通知并排空第二条。
        fixture.agentLoop.currentState = .completed
        fixture.agentLoop.resumeOutcome = .completed
        _ = try await fixture.sender.resumeTurn(
            in: conversationID,
            request: AgentTurnResumeRequest(suspensionID: "userInput:approval-1", answer: "allow")
        )
        #expect(outcomes == [.completed])
        #expect(fixture.sender.pendingMessages(for: conversationID).count == 1)
        #expect(fixture.sender.isSending)

        // 排空拉起的第二条消息回合开始（真实装配中 runTurn 同步发 started）。
        let turnB = UUID()
        fixture.sender.handleAgentLoopEvent(.started(conversationID: conversationID, turnID: turnB))

        // 迟到的终态事件：不得第二次通知，也不得把第三条抢发出去。
        fixture.sender.handleAgentLoopEvent(.completed(conversationID: conversationID, turnID: turnA))
        try await Task.sleep(nanoseconds: 50_000_000)
        #expect(outcomes == [.completed])
        #expect(fixture.sender.pendingMessages(for: conversationID).count == 1)
        #expect(fixture.messages.messages(for: conversationID).map(\.content) == ["first", "second"])
    }

    // MARK: - Helpers

    /// 建立「回合挂起等授权、第一条消息已有跟踪任务」的初始状态。
    private func suspendTurn(
        _ fixture: SenderFixture,
        conversationID: UUID,
        turnID: UUID
    ) async throws {
        let suspension = AgentLoopSuspension(
            suspensionID: "userInput:approval-1",
            conversationID: conversationID,
            toolCallID: "approval-1",
            kind: "permission",
            payload: "{\"kind\":\"permission\"}"
        )
        let commit = try #require(try fixture.sender.commitUserMessage("first", conversationID: conversationID))
        let task = Task { await fixture.sender.startTurn(for: commit) }
        await waitUntil { fixture.sender.isSending }

        fixture.agentLoop.currentState = .suspended
        fixture.agentLoop.activeTurnID = turnID
        fixture.agentLoop.activeSuspension = suspension
        fixture.sender.handleAgentLoopEvent(.started(conversationID: conversationID, turnID: turnID))
        fixture.sender.handleAgentLoopEvent(.suspended(
            conversationID: conversationID,
            turnID: turnID,
            suspension: suspension
        ))
        await task.value
    }
}