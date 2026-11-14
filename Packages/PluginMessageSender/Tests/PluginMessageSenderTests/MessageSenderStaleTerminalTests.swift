import Foundation
import ProviderAgentLoop
import ProviderConversation
import ProviderMessage
import Testing
@testable import PluginMessageSender

/// 锁定终态事件的回合身份校验（#165）。
///
/// AgentLoop 的终态通知是异步投递的：旧回合 A 的 completed / cancelled /
/// failed 可能在新回合 B 已开始后才到达。此前这三条分支完全丢弃 turnID，
/// 迟到终态会唤醒 B 的等待任务、写 B 的完成缓存并提前排空队列。
@Suite("MessageSender 迟到终态事件（#165）")
@MainActor
struct MessageSenderStaleTerminalTests {

    @Test("旧回合的迟到 completed 不得结束新回合")
    func staleCompletedDoesNotEndNewTurn() async throws {
        let fixture = SenderFixture()
        let conversationID = try fixture.conversations.createConversation(
            title: nil, projectPath: nil, providerID: nil, modelName: nil
        )
        var outcomes: [AgentLoopOutcome] = []
        let observer = fixture.sender.addMessageSenderObserver { event in
            if case .turnCompleted(_, let outcome) = event { outcomes.append(outcome) }
        }
        defer { observer.cancel() }

        let turnA = UUID()
        let commit1 = try #require(try fixture.sender.commitUserMessage("first", conversationID: conversationID))
        let task1 = Task { await fixture.sender.startTurn(for: commit1) }
        await waitUntil { fixture.sender.isSending }
        fixture.sender.handleAgentLoopEvent(.started(conversationID: conversationID, turnID: turnA))
        fixture.sender.handleAgentLoopEvent(.completed(conversationID: conversationID, turnID: turnA))
        await task1.value

        let turnB = UUID()
        let commit2 = try #require(try fixture.sender.commitUserMessage("second", conversationID: conversationID))
        let task2 = Task { await fixture.sender.startTurn(for: commit2) }
        await waitUntil { fixture.sender.isSending }
        fixture.sender.handleAgentLoopEvent(.started(conversationID: conversationID, turnID: turnB))

        // A 的终态迟到：B 仍在等待，不得被唤醒。
        fixture.sender.handleAgentLoopEvent(.completed(conversationID: conversationID, turnID: turnA))
        try await Task.sleep(nanoseconds: 50_000_000)
        #expect(fixture.sender.isSending)
        #expect(outcomes == [.completed])

        fixture.sender.handleAgentLoopEvent(.completed(conversationID: conversationID, turnID: turnB))
        await task2.value
        #expect(outcomes == [.completed, .completed])
        #expect(fixture.sender.isSending == false)
    }

    @Test("旧回合的迟到 failed/cancelled 不得结束新回合")
    func staleFailedAndCancelledDoNotEndNewTurn() async throws {
        let fixture = SenderFixture()
        let conversationID = try fixture.conversations.createConversation(
            title: nil, projectPath: nil, providerID: nil, modelName: nil
        )
        var outcomes: [AgentLoopOutcome] = []
        var failures: [String] = []
        let observer = fixture.sender.addMessageSenderObserver { event in
            switch event {
            case .turnCompleted(_, let outcome): outcomes.append(outcome)
            case .turnFailed(_, let reason): failures.append(reason)
            default: break
            }
        }
        defer { observer.cancel() }

        let turnA = UUID()
        let turnB = UUID()
        let commit = try #require(try fixture.sender.commitUserMessage("hi", conversationID: conversationID))
        let task = Task { await fixture.sender.startTurn(for: commit) }
        await waitUntil { fixture.sender.isSending }
        fixture.sender.handleAgentLoopEvent(.started(conversationID: conversationID, turnID: turnB))

        fixture.sender.handleAgentLoopEvent(.failed(conversationID: conversationID, turnID: turnA, reason: "old failure"))
        fixture.sender.handleAgentLoopEvent(.cancelled(conversationID: conversationID, turnID: turnA))
        try await Task.sleep(nanoseconds: 50_000_000)
        #expect(fixture.sender.isSending)
        #expect(outcomes.isEmpty)
        #expect(failures.isEmpty)

        fixture.sender.handleAgentLoopEvent(.completed(conversationID: conversationID, turnID: turnB))
        await task.value
        #expect(outcomes == [.completed])
    }

    @Test("旧回合的迟到终态不得提前排空队列")
    func staleTerminalDoesNotDrainQueue() async throws {
        let fixture = SenderFixture()
        let conversationID = try fixture.conversations.createConversation(
            title: nil, projectPath: nil, providerID: nil, modelName: nil
        )
        var outcomes: [AgentLoopOutcome] = []
        let observer = fixture.sender.addMessageSenderObserver { event in
            if case .turnCompleted(_, let outcome) = event { outcomes.append(outcome) }
        }
        defer { observer.cancel() }

        let turnA = UUID()
        let commit1 = try #require(try fixture.sender.commitUserMessage("first", conversationID: conversationID))
        let task1 = Task { await fixture.sender.startTurn(for: commit1) }
        await waitUntil { fixture.sender.isSending }
        fixture.sender.handleAgentLoopEvent(.started(conversationID: conversationID, turnID: turnA))

        // 忙碌时第二条消息入队。
        let queued = try #require(try fixture.sender.commitUserMessage("second", conversationID: conversationID))
        #expect(queued.userMessageID == nil)
        #expect(fixture.sender.pendingQueues[conversationID]?.count == 1)

        // A 正常结束 → 排空队列，第二条消息发出（回合 B）。
        fixture.sender.handleAgentLoopEvent(.completed(conversationID: conversationID, turnID: turnA))
        await task1.value
        await waitUntil { fixture.sender.pendingQueues[conversationID] == nil && fixture.sender.isSending }
        let turnB = UUID()
        fixture.sender.handleAgentLoopEvent(.started(conversationID: conversationID, turnID: turnB))

        // 第三条消息入队，随后 A 的迟到终态不得把它提前发出。
        _ = try fixture.sender.commitUserMessage("third", conversationID: conversationID)
        #expect(fixture.sender.pendingQueues[conversationID]?.count == 1)
        fixture.sender.handleAgentLoopEvent(.cancelled(conversationID: conversationID, turnID: turnA))
        fixture.sender.handleAgentLoopEvent(.failed(conversationID: conversationID, turnID: turnA, reason: "old"))
        try await Task.sleep(nanoseconds: 50_000_000)
        #expect(fixture.sender.isSending)
        #expect(fixture.sender.pendingQueues[conversationID]?.count == 1)
        #expect(outcomes == [.completed])

        // B 正常结束才排空第三条。
        let turnC = UUID()
        fixture.sender.handleAgentLoopEvent(.completed(conversationID: conversationID, turnID: turnB))
        await waitUntil { fixture.sender.pendingQueues[conversationID] == nil && fixture.sender.isSending }
        fixture.sender.handleAgentLoopEvent(.started(conversationID: conversationID, turnID: turnC))
        fixture.sender.handleAgentLoopEvent(.completed(conversationID: conversationID, turnID: turnC))
        await waitUntil { !fixture.sender.isSending }
        #expect(outcomes == [.completed, .completed, .completed])
    }

    @Test("未携带 turnID 的终态保持旧行为（合成取消仍可唤醒等待）")
    func terminalWithoutTurnIDStillWakesWaiter() async throws {
        let fixture = SenderFixture()
        let conversationID = try fixture.conversations.createConversation(
            title: nil, projectPath: nil, providerID: nil, modelName: nil
        )
        let commit = try #require(try fixture.sender.commitUserMessage("hi", conversationID: conversationID))
        let task = Task { await fixture.sender.startTurn(for: commit) }
        await waitUntil { fixture.sender.isSending }

        fixture.sender.handleAgentLoopEvent(.cancelled(conversationID: conversationID, turnID: nil))
        await task.value
        #expect(fixture.sender.isSending == false)
    }
}