import Foundation
import ProviderAgentLoop
import ProviderConversation
import ProviderMessage
import Testing
@testable import PluginMessageSender

/// 覆盖 TestPlan「停止语义」与「附件挂起池」章节：ID 9–11、ID 16。
@Suite("MessageSender 停止与附件")
@MainActor
struct MessageSenderCancellationTests {

    // MARK: - ID 10: 停止取消活动回合

    @Test("cancelCurrentRequest 取消活动回合并广播 cancelled")
    func cancelCurrentRequestCancelsActiveTurn() async throws {
        let fixture = SenderFixture()
        let conversationID = try fixture.conversations.createConversation(
            title: nil, projectPath: nil, providerID: nil, modelName: nil
        )
        var outcomes: [AgentLoopOutcome] = []
        let observer = fixture.sender.addMessageSenderObserver { event in
            if case .turnCompleted(_, let outcome) = event { outcomes.append(outcome) }
        }
        defer { observer.cancel() }

        let result = try fixture.sender.commitUserMessage("hi", conversationID: conversationID)
        let commit = try #require(result)
        let turn = Task { await fixture.sender.startTurn(for: commit) }
        await waitUntil { fixture.sender.isSending }

        fixture.sender.cancelCurrentRequest()
        await turn.value

        #expect(fixture.agentLoop.cancelledConversationIDs == [conversationID])
        #expect(outcomes == [.cancelled])
        #expect(fixture.sender.isSending == false)
    }

    @Test("停止也会清掉尚未开始回合跟踪的提交")
    func cancelClearsPendingTurnStarts() throws {
        let fixture = SenderFixture()
        let conversationID = try fixture.conversations.createConversation(
            title: nil, projectPath: nil, providerID: nil, modelName: nil
        )
        var outcomes: [AgentLoopOutcome] = []
        let observer = fixture.sender.addMessageSenderObserver { event in
            if case .turnCompleted(_, let outcome) = event { outcomes.append(outcome) }
        }
        defer { observer.cancel() }

        // 仅 commit（未调用 startTurn）时，会话处于 pendingTurnStarts 状态。
        let result = try fixture.sender.commitUserMessage("hi", conversationID: conversationID)
        let commit = try #require(result)
        #expect(commit.userMessageID != nil)

        fixture.sender.cancelCurrentRequest()

        #expect(fixture.agentLoop.cancelledConversationIDs == [conversationID])
        #expect(outcomes == [.cancelled])
        #expect(fixture.sender.isSending == false)
    }

    // MARK: - ID 11: 无活动回合时停止是 no-op

    @Test("无活动回合时停止是安全 no-op")
    func cancelWithoutActiveTurnIsNoOp() throws {
        let fixture = SenderFixture()
        var stateValues: [Bool] = []
        let stateObserver = fixture.sender.addSendingStateObserver { stateValues.append($0) }
        defer { stateObserver.cancel() }

        // 完全没有选中会话。
        fixture.sender.cancelCurrentRequest()
        #expect(fixture.agentLoop.cancelledConversationIDs.isEmpty)
        #expect(stateValues.isEmpty)

        // 有选中会话但没有活动回合。
        _ = try fixture.conversations.createConversation(
            title: nil, projectPath: nil, providerID: nil, modelName: nil
        )
        fixture.sender.cancelCurrentRequest()
        fixture.sender.cancelCurrentRequest()

        #expect(fixture.agentLoop.cancelledConversationIDs.isEmpty)
        #expect(fixture.sender.isSending == false)
        #expect(stateValues.isEmpty)
    }

    // MARK: - 取消权归 AgentLoop：sender 不知道的回合也必须能停

    @Test("AgentLoop 在跑但 sender 没有账本时仍然取消回合")
    func cancelStopsTurnUnknownToSender() throws {
        let fixture = SenderFixture()
        let conversationID = try fixture.conversations.createConversation(
            title: nil, projectPath: nil, providerID: nil, modelName: nil
        )
        // 模拟 ACP 托管 / 事件驱动 / 自动重试拉起的回合：
        // AgentLoop 在跑，但 sender 从未 startTurn 过，没有自己的任务账本。
        fixture.agentLoop.currentState = .running

        fixture.sender.cancelCurrentRequest()

        #expect(fixture.agentLoop.cancelledConversationIDs == [conversationID])
    }

    @Test("挂起等待用户时也能取消回合")
    func cancelStopsSuspendedTurn() throws {
        let fixture = SenderFixture()
        let conversationID = try fixture.conversations.createConversation(
            title: nil, projectPath: nil, providerID: nil, modelName: nil
        )
        // 回合挂在等用户授权/回答：sender 同样没有账本。
        fixture.agentLoop.currentState = .suspended
        fixture.agentLoop.activeSuspension = AgentLoopSuspension(
            suspensionID: "userInput:call_1",
            conversationID: conversationID,
            toolCallID: "call_1",
            kind: "userInput",
            payload: "{}"
        )

        fixture.sender.cancelCurrentRequest()

        #expect(fixture.agentLoop.cancelledConversationIDs == [conversationID])
    }

    @Test("sender 与 AgentLoop 都认为没有活回合时仍然不取消")
    func cancelWithoutAnyActiveTurnIsNoOp() throws {
        let fixture = SenderFixture()
        let conversationID = try fixture.conversations.createConversation(
            title: nil, projectPath: nil, providerID: nil, modelName: nil
        )
        // 回合已结束：状态是终态，没有挂起点。
        fixture.agentLoop.currentState = .completed

        fixture.sender.cancelCurrentRequest()

        #expect(fixture.agentLoop.cancelledConversationIDs.isEmpty)
        #expect(fixture.sender.isSending == false)
    }

    // MARK: - ID 16: 跨会话并发不得提前复位 isSending

    @Test("两个会话并发发送，一个结束不得提前复位 isSending")
    func concurrentConversationsKeepGlobalSendingFlag() async throws {
        let fixture = SenderFixture()
        let first = try fixture.conversations.createConversation(
            title: nil, projectPath: nil, providerID: nil, modelName: nil
        )
        let second = try fixture.conversations.createConversation(
            title: nil, projectPath: nil, providerID: nil, modelName: nil
        )

        let firstResult = try fixture.sender.commitUserMessage("a", conversationID: first)
        let secondResult = try fixture.sender.commitUserMessage("b", conversationID: second)
        let firstCommit = try #require(firstResult)
        let secondCommit = try #require(secondResult)

        let firstTurn = Task { await fixture.sender.startTurn(for: firstCommit) }
        let secondTurn = Task { await fixture.sender.startTurn(for: secondCommit) }
        await waitUntil { fixture.sender.isSending }

        // 先结束第一个会话的回合。
        fixture.sender.handleAgentLoopEvent(.completed(conversationID: first, turnID: UUID()))
        await firstTurn.value

        #expect(fixture.sender.isSending == true)

        // 第二个会话结束后才复位。
        fixture.sender.handleAgentLoopEvent(.completed(conversationID: second, turnID: UUID()))
        await secondTurn.value

        #expect(fixture.sender.isSending == false)
    }

    // MARK: - ID 9: 附件挂起池

    @Test("附件池支持增删清空，并按实际变化广播 attachmentsChanged")
    func attachmentPoolMutationsBroadcastChanges() throws {
        let fixture = SenderFixture()
        var attachmentEvents = 0
        let observer = fixture.sender.addMessageSenderObserver { event in
            if case .attachmentsChanged = event { attachmentEvents += 1 }
        }
        defer { observer.cancel() }

        let firstImage = UserImageAttachment.fixture()
        fixture.sender.addImageAttachment(firstImage)
        #expect(fixture.sender.pendingImageAttachments == [firstImage])
        #expect(attachmentEvents == 1)

        let secondImage = UserImageAttachment.fixture()
        fixture.sender.addImageAttachment(secondImage)
        #expect(fixture.sender.pendingImageAttachments.count == 2)
        #expect(attachmentEvents == 2)

        // 移除中间一项。
        fixture.sender.removeImageAttachment(id: firstImage.id)
        #expect(fixture.sender.pendingImageAttachments == [secondImage])
        #expect(attachmentEvents == 3)

        // 移除不存在的 ID 不广播。
        fixture.sender.removeImageAttachment(id: UUID())
        #expect(attachmentEvents == 3)

        fixture.sender.clearImageAttachments()
        #expect(fixture.sender.pendingImageAttachments.isEmpty)
        #expect(attachmentEvents == 4)

        // 清空已空的池不广播。
        fixture.sender.clearImageAttachments()
        #expect(attachmentEvents == 4)
    }

    @Test("文件附件池支持增删清空，并按实际变化广播 attachmentsChanged")
    func fileAttachmentPoolMutationsBroadcastChanges() throws {
        let fixture = SenderFixture()
        var attachmentEvents = 0
        let observer = fixture.sender.addMessageSenderObserver { event in
            if case .attachmentsChanged = event { attachmentEvents += 1 }
        }
        defer { observer.cancel() }

        let file = UserFileAttachment.fixture()
        fixture.sender.addFileAttachment(file)
        #expect(fixture.sender.pendingFileAttachments == [file])
        #expect(attachmentEvents == 1)

        fixture.sender.removeFileAttachment(id: file.id)
        #expect(fixture.sender.pendingFileAttachments.isEmpty)
        #expect(attachmentEvents == 2)

        fixture.sender.removeFileAttachment(id: file.id)
        #expect(attachmentEvents == 2)

        fixture.sender.addFileAttachment(file)
        fixture.sender.clearFileAttachments()
        #expect(fixture.sender.pendingFileAttachments.isEmpty)
        #expect(attachmentEvents == 4)
    }

    @Test("发送后清空已送出的附件")
    func sendingClearsSentAttachments() throws {
        let fixture = SenderFixture()
        let conversationID = try fixture.conversations.createConversation(
            title: nil, projectPath: nil, providerID: nil, modelName: nil
        )
        let image = UserImageAttachment.fixture()
        let file = UserFileAttachment.fixture()
        fixture.sender.addImageAttachment(image)
        fixture.sender.addFileAttachment(file)

        let result = try fixture.sender.commitUserMessage("hi", conversationID: conversationID)

        let commit = try #require(result)
        let userMessageID = try #require(commit.userMessageID)
        let message = try #require(fixture.messages.message(id: userMessageID, in: conversationID))
        // 送出的正是这两个附件。
        #expect(UserAttachmentMetadata.decodeImageAttachments(from: message.metadata) == [image])
        #expect(UserAttachmentMetadata.decodeFileAttachments(from: message.metadata) == [file])
        // 挂起池已被清空。
        #expect(fixture.sender.pendingImageAttachments.isEmpty)
        #expect(fixture.sender.pendingFileAttachments.isEmpty)
    }

    @Test("发送期间用户新增的附件保留在挂起池")
    func attachmentsAddedDuringSendSurvive() async throws {
        let fixture = SenderFixture()
        let conversationID = try fixture.conversations.createConversation(
            title: nil, projectPath: nil, providerID: nil, modelName: nil
        )
        let sent = UserImageAttachment.fixture()
        fixture.sender.addImageAttachment(sent)

        let result = try fixture.sender.commitUserMessage("hi", conversationID: conversationID)
        let commit = try #require(result)
        // commit 阶段已清空池子；模拟用户在回合进行中重新添加附件。
        let addedLater = UserImageAttachment.fixture()
        fixture.sender.addImageAttachment(addedLater)

        let turn = Task { await fixture.sender.startTurn(for: commit) }
        await waitUntil { fixture.sender.isSending }
        fixture.sender.handleAgentLoopEvent(.completed(conversationID: conversationID, turnID: UUID()))
        await turn.value

        // 回合结束不得误清用户在等待期间新增的附件。
        #expect(fixture.sender.pendingImageAttachments == [addedLater])
    }
}
