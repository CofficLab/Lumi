import Foundation
import ProviderAgentLoop
import ProviderConversation
import ProviderMessage
import Testing
@testable import PluginMessageSender

/// 锁定恢复路径的全局发送状态收尾（#166）。
///
/// `resumeTurn` 的 defer 此前无条件把全局 `isSending` 置 false：会话 A
/// 还在跑时恢复会话 B，B 返回后全局状态变成「空闲」，与真实活动不符。
/// 收尾必须像 `finishTurnTracking` 一样按全部会话的账本重算。
@Suite("MessageSender 恢复与全局发送状态（#166）")
@MainActor
struct MessageSenderResumeSendingStateTests {

    @Test("恢复会话 B 成功时不得清掉会话 A 的发送状态")
    func resumeSuccessKeepsOtherConversationSending() async throws {
        let fixture = SenderFixture()
        let conversationA = try fixture.conversations.createConversation(
            title: nil, projectPath: nil, providerID: nil, modelName: nil
        )
        let conversationB = try fixture.conversations.createConversation(
            title: nil, projectPath: nil, providerID: nil, modelName: nil
        )

        let commitA = try #require(try fixture.sender.commitUserMessage("a", conversationID: conversationA))
        let taskA = Task { await fixture.sender.startTurn(for: commitA) }
        await waitUntil { fixture.sender.isSending }

        fixture.agentLoop.resumeOutcome = .completed
        _ = try await fixture.sender.resumeTurn(
            in: conversationB,
            request: AgentTurnResumeRequest(suspensionID: "userInput:approval-1", answer: "allow")
        )
        #expect(fixture.sender.isSending, "会话 A 仍在跑，全局发送状态不得被 B 的收尾清掉")

        let turnA = UUID()
        fixture.sender.handleAgentLoopEvent(.started(conversationID: conversationA, turnID: turnA))
        fixture.sender.handleAgentLoopEvent(.completed(conversationID: conversationA, turnID: turnA))
        await taskA.value
        #expect(fixture.sender.isSending == false)
    }

    @Test("恢复会话 B 失败时同样不得清掉会话 A 的发送状态")
    func resumeFailureKeepsOtherConversationSending() async throws {
        let fixture = SenderFixture()
        let conversationA = try fixture.conversations.createConversation(
            title: nil, projectPath: nil, providerID: nil, modelName: nil
        )
        let conversationB = try fixture.conversations.createConversation(
            title: nil, projectPath: nil, providerID: nil, modelName: nil
        )

        let commitA = try #require(try fixture.sender.commitUserMessage("a", conversationID: conversationA))
        let taskA = Task { await fixture.sender.startTurn(for: commitA) }
        await waitUntil { fixture.sender.isSending }

        fixture.agentLoop.resumeError = StubAgentLoopError(reason: "resume failed")
        await #expect(throws: StubAgentLoopError.self) {
            _ = try await fixture.sender.resumeTurn(
                in: conversationB,
                request: AgentTurnResumeRequest(suspensionID: "userInput:approval-1", answer: "allow")
            )
        }
        #expect(fixture.sender.isSending, "失败分支的收尾同样要按账本重算")

        let turnA = UUID()
        fixture.sender.handleAgentLoopEvent(.started(conversationID: conversationA, turnID: turnA))
        fixture.sender.handleAgentLoopEvent(.completed(conversationID: conversationA, turnID: turnA))
        await taskA.value
        #expect(fixture.sender.isSending == false)
    }
}