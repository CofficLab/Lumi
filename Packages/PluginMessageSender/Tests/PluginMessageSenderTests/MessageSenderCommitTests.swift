import Foundation
import ProviderConversation
import ProviderMessage
import Testing
@testable import PluginMessageSender

/// 覆盖 TestPlan「提交与队列」章节：ID 5–8、ID 15。
@Suite("MessageSender 提交与队列")
@MainActor
struct MessageSenderCommitTests {

    // MARK: - ID 5: 空内容短路

    @Test("空内容与纯空白内容短路：不写库、不建回合", arguments: ["", "   ", "\n\n", " \t "])
    func blankContentIsIgnored(content: String) throws {
        let fixture = SenderFixture()
        let conversationID = try fixture.conversations.createConversation(
            title: nil, projectPath: nil, providerID: nil, modelName: nil
        )

        let result = try fixture.sender.commitUserMessage(content, conversationID: conversationID)

        #expect(result == nil)
        #expect(fixture.messages.messages(for: conversationID).isEmpty)
        #expect(fixture.sender.isSending == false)
        #expect(fixture.agentLoop.runTurnCount == 0)
    }

    // MARK: - ID 6: 附件允许空正文

    @Test("正文为空但带图片附件时仍可提交，附件编码进 metadata")
    func attachmentOnlySubmissionIsAccepted() throws {
        let fixture = SenderFixture()
        let conversationID = try fixture.conversations.createConversation(
            title: nil, projectPath: nil, providerID: nil, modelName: nil
        )
        let image = UserImageAttachment.fixture()
        let file = UserFileAttachment.fixture()

        let result = try fixture.sender.commitUserMessage(
            "",
            imageAttachments: [image],
            fileAttachments: [file],
            conversationID: conversationID
        )

        let commit = try #require(result)
        #expect(commit.wasQueued == false)
        let userMessageID = try #require(commit.userMessageID)
        let message = try #require(fixture.messages.message(id: userMessageID, in: conversationID))
        #expect(message.role == .user)
        #expect(message.content == "")
        #expect(UserAttachmentMetadata.decodeImageAttachments(from: message.metadata) == [image])
        #expect(UserAttachmentMetadata.decodeFileAttachments(from: message.metadata) == [file])
    }

    // MARK: - ID 7: 同会话串行队列

    @Test("同会话发送中再次发送进入队列，回合结束后自动发出")
    func consecutiveSendsAreQueuedAndDrained() async throws {
        let fixture = SenderFixture()
        let conversationID = try fixture.conversations.createConversation(
            title: nil, projectPath: nil, providerID: nil, modelName: nil
        )

        let firstResult = try fixture.sender.commitUserMessage("first", conversationID: conversationID)
        let secondResult = try fixture.sender.commitUserMessage("second", conversationID: conversationID)
        let first = try #require(firstResult)
        let second = try #require(secondResult)

        // 第二条入队：commit 成功但没有消息 ID，队列可见。
        #expect(second.wasQueued)
        #expect(second.userMessageID == nil)
        #expect(fixture.sender.pendingMessages(for: conversationID).map(\.content) == ["second"])
        // 第一条已立即入库，不等待回合。
        #expect(fixture.messages.messages(for: conversationID).map(\.content) == ["first"])

        fixture.sender.handleAgentLoopEvent(.completed(conversationID: conversationID, turnID: UUID()))
        await fixture.sender.startTurn(for: first)

        // 队列排空：第二条落库，队列归空，并已开启新的回合跟踪。
        #expect(fixture.sender.pendingMessages(for: conversationID).isEmpty)
        #expect(fixture.messages.messages(for: conversationID).map(\.content) == ["first", "second"])
        #expect(fixture.sender.isSending == true)
    }

    @Test("队列排空会为下一条重新开启回合跟踪")
    func drainingQueueStartsFollowUpTurn() async throws {
        let fixture = SenderFixture()
        let conversationID = try fixture.conversations.createConversation(
            title: nil, projectPath: nil, providerID: nil, modelName: nil
        )
        var startedEvents: [UUID] = []
        let observer = fixture.sender.addMessageSenderObserver { event in
            if case .started(let id) = event { startedEvents.append(id) }
        }
        defer { observer.cancel() }

        let firstResult = try fixture.sender.commitUserMessage("first", conversationID: conversationID)
        let first = try #require(firstResult)
        _ = try fixture.sender.commitUserMessage("second", conversationID: conversationID)

        fixture.sender.handleAgentLoopEvent(.completed(conversationID: conversationID, turnID: UUID()))
        await fixture.sender.startTurn(for: first)

        // `.started` 为两条消息各广播一次，第二条来自 drainPendingQueue。
        #expect(startedEvents == [conversationID, conversationID])
    }

    // MARK: - ID 8: 取消队列条目

    @Test("cancelPendingMessage 移除指定条目并广播队列变化")
    func cancellingPendingMessageRemovesSingleEntry() throws {
        let fixture = SenderFixture()
        let conversationID = try fixture.conversations.createConversation(
            title: nil, projectPath: nil, providerID: nil, modelName: nil
        )
        var changeEvents: [UUID] = []
        let observer = fixture.sender.addMessageSenderObserver { event in
            if case .pendingMessagesChanged(let id) = event { changeEvents.append(id) }
        }
        defer { observer.cancel() }

        _ = try fixture.sender.commitUserMessage("running", conversationID: conversationID)
        _ = try fixture.sender.commitUserMessage("second", conversationID: conversationID)
        _ = try fixture.sender.commitUserMessage("third", conversationID: conversationID)
        let queue = fixture.sender.pendingMessages(for: conversationID)
        #expect(queue.map(\.content) == ["second", "third"])

        fixture.sender.cancelPendingMessage(id: queue[0].id, in: conversationID)

        #expect(fixture.sender.pendingMessages(for: conversationID).map(\.content) == ["third"])
        #expect(changeEvents == [conversationID, conversationID, conversationID])
    }

    @Test("队列清空后 key 被移除，取消不存在的条目不广播")
    func cancellingLastPendingEntryRemovesQueue() throws {
        let fixture = SenderFixture()
        let conversationID = try fixture.conversations.createConversation(
            title: nil, projectPath: nil, providerID: nil, modelName: nil
        )
        var changeCount = 0
        let observer = fixture.sender.addMessageSenderObserver { event in
            if case .pendingMessagesChanged = event { changeCount += 1 }
        }
        defer { observer.cancel() }

        _ = try fixture.sender.commitUserMessage("running", conversationID: conversationID)
        _ = try fixture.sender.commitUserMessage("only", conversationID: conversationID)
        let entryID = try #require(fixture.sender.pendingMessages(for: conversationID).first?.id)
        let eventsBeforeCancel = changeCount

        fixture.sender.cancelPendingMessage(id: entryID, in: conversationID)

        #expect(fixture.sender.pendingMessages(for: conversationID).isEmpty)
        #expect(changeCount == eventsBeforeCancel + 1)

        // 队列已空时再次取消不应广播。
        fixture.sender.cancelPendingMessage(id: entryID, in: conversationID)
        #expect(changeCount == eventsBeforeCancel + 1)
    }

    // MARK: - ID 15: 会话解析

    @Test("未指定会话时落到当前选中会话")
    func nilConversationFallsBackToSelection() throws {
        let fixture = SenderFixture()
        let conversationID = try fixture.conversations.createConversation(
            title: nil, projectPath: nil, providerID: nil, modelName: nil
        )

        let result = try fixture.sender.commitUserMessage("hi", conversationID: nil)

        let commit = try #require(result)
        #expect(commit.conversationID == conversationID)
        #expect(fixture.messages.messages(for: conversationID).map(\.content) == ["hi"])
    }

    @Test("无选中会话时新建会话并自动选中，消息写入新会话")
    func nilConversationCreatesAndSelectsNewConversation() throws {
        let fixture = SenderFixture()
        #expect(fixture.conversations.selectedConversationID == nil)

        let result = try fixture.sender.commitUserMessage("hi", conversationID: nil)

        let commit = try #require(result)
        let created = commit.conversationID
        #expect(fixture.conversations.selectedConversationID == created)
        #expect(fixture.messages.messages(for: created).map(\.content) == ["hi"])
    }

    @Test("显式指定会话时不会被当前选中会话覆盖")
    func explicitConversationWins() throws {
        let fixture = SenderFixture()
        let selected = try fixture.conversations.createConversation(
            title: nil, projectPath: nil, providerID: nil, modelName: nil
        )
        let explicit = try fixture.conversations.createConversation(
            title: nil, projectPath: nil, providerID: nil, modelName: nil
        )
        fixture.conversations.selectConversation(id: selected)

        let result = try fixture.sender.commitUserMessage("hi", conversationID: explicit)

        let commit = try #require(result)
        #expect(commit.conversationID == explicit)
        #expect(fixture.messages.messages(for: explicit).map(\.content) == ["hi"])
        #expect(fixture.messages.messages(for: selected).isEmpty)
    }
}

// MARK: - Fixture

/// 提交/队列类测试共用的最小装配。
@MainActor
struct SenderFixture {
    let conversations = DefaultConversationManager()
    let messages = DefaultMessageManager()
    let agentLoop: StubAgentLoop
    let sender: MessageSender

    init() {
        let loop = StubAgentLoop(messages: messages)
        self.agentLoop = loop
        self.sender = MessageSender(
            conversations: conversations,
            messages: messages,
            agentLoop: loop
        )
    }
}
