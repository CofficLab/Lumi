import Foundation
import ProviderAgentLoop
import ProviderConversation
import ProviderMessage
import Testing
@testable import PluginMessageSender

/// 会话删除后，它的待发工作必须随之失效（#167）。
///
/// 删除通知先于异步清理到达。此前 sender 对删除一无所知：排队消息还在，
/// 跟踪任务还挂在 continuation 上，取消的终态事件一到，队列照样排空——
/// 已删除会话的消息被重新落库，甚至再拉起一个回合。
@Suite("MessageSender 会话删除失效（#167）")
@MainActor
struct MessageSenderDeletionTests {

    @Test("删除会话立即清空队列并结束跟踪任务")
    func deletionInvalidatesQueueAndTrackingTask() async throws {
        let fixture = SenderFixture()
        let conversationID = try fixture.conversations.createConversation(
            title: nil, projectPath: nil, providerID: nil, modelName: nil
        )

        let turnA = UUID()
        let commit = try #require(try fixture.sender.commitUserMessage("first", conversationID: conversationID))
        let task = Task { await fixture.sender.startTurn(for: commit) }
        await waitUntil { fixture.sender.isSending }
        fixture.sender.handleAgentLoopEvent(.started(conversationID: conversationID, turnID: turnA))

        // 忙碌时第二条消息入队。
        _ = try fixture.sender.commitUserMessage("second", conversationID: conversationID)
        #expect(fixture.sender.pendingMessages(for: conversationID).count == 1)

        fixture.conversations.deleteConversation(id: conversationID)

        #expect(fixture.sender.pendingMessages(for: conversationID).isEmpty)
        #expect(fixture.sender.isSending == false)
        // 跟踪任务挂在 continuation 上：删除必须唤醒它，而不是让它永久挂起。
        await task.value

        // 迟到的终态事件不得把排队消息重新落库，也不得拉起新回合。
        fixture.sender.handleAgentLoopEvent(.cancelled(conversationID: conversationID, turnID: turnA))
        fixture.sender.handleAgentLoopEvent(.completed(conversationID: conversationID, turnID: turnA))
        try await Task.sleep(nanoseconds: 50_000_000)
        #expect(fixture.messages.messages(for: conversationID).map(\.content) == ["first"])
        #expect(fixture.sender.pendingMessages(for: conversationID).isEmpty)
        #expect(fixture.sender.isSending == false)
        #expect(fixture.agentLoop.runTurnCount == 0)
    }

    @Test("提交后尚未启动的回合在删除后不得再启动")
    func deletionBeforeTurnStartPreventsStart() async throws {
        let fixture = SenderFixture()
        let conversationID = try fixture.conversations.createConversation(
            title: nil, projectPath: nil, providerID: nil, modelName: nil
        )
        var startedConversations: [UUID] = []
        let observer = fixture.sender.addMessageSenderObserver { event in
            if case .started(let id) = event { startedConversations.append(id) }
        }
        defer { observer.cancel() }

        // 提交后、跟踪任务调度前：pendingTurnStarts 窗口内删除会话。
        let commit = try #require(try fixture.sender.commitUserMessage("first", conversationID: conversationID))
        _ = try fixture.sender.commitUserMessage("second", conversationID: conversationID)
        #expect(fixture.sender.pendingMessages(for: conversationID).count == 1)

        fixture.conversations.deleteConversation(id: conversationID)
        #expect(fixture.sender.pendingMessages(for: conversationID).isEmpty)
        #expect(fixture.sender.isSending == false)

        await fixture.sender.startTurn(for: commit)
        #expect(startedConversations.isEmpty)
        #expect(fixture.messages.messages(for: conversationID).map(\.content) == ["first"])
        #expect(fixture.sender.isSending == false)
    }

    @Test("删除一个会话不影响其他会话的排队与发送")
    func deletionDoesNotAffectOtherConversations() async throws {
        let fixture = SenderFixture()
        let idA = try fixture.conversations.createConversation(
            title: nil, projectPath: nil, providerID: nil, modelName: nil
        )
        let idB = try fixture.conversations.createConversation(
            title: nil, projectPath: nil, providerID: nil, modelName: nil
        )

        let turnA = UUID()
        let turnB = UUID()
        let commitA = try #require(try fixture.sender.commitUserMessage("a1", conversationID: idA))
        let taskA = Task { await fixture.sender.startTurn(for: commitA) }
        let commitB = try #require(try fixture.sender.commitUserMessage("b1", conversationID: idB))
        let taskB = Task { await fixture.sender.startTurn(for: commitB) }
        await waitUntil { fixture.sender.isSending }
        fixture.sender.handleAgentLoopEvent(.started(conversationID: idA, turnID: turnA))
        fixture.sender.handleAgentLoopEvent(.started(conversationID: idB, turnID: turnB))
        _ = try fixture.sender.commitUserMessage("a2", conversationID: idA)
        _ = try fixture.sender.commitUserMessage("b2", conversationID: idB)

        fixture.conversations.deleteConversation(id: idA)
        await taskA.value
        #expect(fixture.sender.pendingMessages(for: idA).isEmpty)
        #expect(fixture.sender.pendingMessages(for: idB).count == 1)
        #expect(fixture.sender.isSending)

        // B 不受影响：正常结束后照常排空自己的队列。
        fixture.sender.handleAgentLoopEvent(.completed(conversationID: idB, turnID: turnB))
        await taskB.value
        await waitUntil { fixture.sender.pendingMessages(for: idB).isEmpty && fixture.sender.isSending }
        let turnB2 = UUID()
        fixture.sender.handleAgentLoopEvent(.started(conversationID: idB, turnID: turnB2))
        fixture.sender.handleAgentLoopEvent(.completed(conversationID: idB, turnID: turnB2))
        await waitUntil { !fixture.sender.isSending }
        #expect(fixture.messages.messages(for: idB).map(\.content) == ["b1", "b2"])
        #expect(fixture.messages.messages(for: idA).map(\.content) == ["a1"])
    }
}