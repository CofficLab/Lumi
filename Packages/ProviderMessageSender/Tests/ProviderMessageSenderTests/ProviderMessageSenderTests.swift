import Foundation
import Testing
import ProviderLifecycleHooks
import ProviderAgentLoop
import ProviderConversation
import ProviderMessage
@testable import ProviderMessageSender

@Suite("ProviderMessageSender")
@MainActor
struct ProviderMessageSenderTests {
    @Test("折叠块随用户消息落库，区间落在正文范围内")
    func commitsCollapsedBlocksIntoMetadata() throws {
        let conversations = DefaultConversationManager()
        let messages = DefaultMessageManager()
        let loop = StubAgentLoop(messages: messages)
        let sender = DefaultMessageSender(
            conversations: conversations,
            messages: messages,
            agentLoop: loop
        )

        let content = "hello world"
        let commit = try #require(
            try sender.commitUserMessage(
                content,
                imageAttachments: [],
                fileAttachments: [],
                collapsedBlocks: [
                    CollapsedContentBlock(start: 6, length: 5, title: "粘贴的文本"),
                ],
                conversationID: nil
            )
        )
        let conversationID = try #require(conversations.selectedConversationID)
        let message = try #require(messages.messages(for: conversationID).first)

        let blocks = CollapsedContentBlockMetadata.normalizedBlocks(
            from: message.metadata,
            contentLength: message.content.count
        )
        #expect(blocks.count == 1)
        #expect(blocks.first?.start == 6)
        #expect(blocks.first?.length == 5)
        #expect(blocks.first?.title == "粘贴的文本")
        #expect(commit.userMessageID == message.id)
    }

    @Test("正文被 trim 后折叠块区间同步平移")
    func rebasesCollapsedBlocksAfterTrim() throws {
        let conversations = DefaultConversationManager()
        let messages = DefaultMessageManager()
        let loop = StubAgentLoop(messages: messages)
        let sender = DefaultMessageSender(
            conversations: conversations,
            messages: messages,
            agentLoop: loop
        )

        let content = "  hello world  "
        _ = try #require(
            try sender.commitUserMessage(
                content,
                imageAttachments: [],
                fileAttachments: [],
                collapsedBlocks: [
                    CollapsedContentBlock(start: 8, length: 5, title: "粘贴的文本"),
                ],
                conversationID: nil
            )
        )
        let conversationID = try #require(conversations.selectedConversationID)
        let message = try #require(messages.messages(for: conversationID).first)

        #expect(message.content == "hello world")
        let blocks = CollapsedContentBlockMetadata.normalizedBlocks(
            from: message.metadata,
            contentLength: message.content.count
        )
        #expect(blocks.count == 1)
        #expect(blocks.first?.start == 6)
    }

    @Test("不携带折叠块时 metadata 里没有折叠块 key")
    func omitsCollapsedBlocksKeyWhenAbsent() throws {
        let conversations = DefaultConversationManager()
        let messages = DefaultMessageManager()
        let loop = StubAgentLoop(messages: messages)
        let sender = DefaultMessageSender(
            conversations: conversations,
            messages: messages,
            agentLoop: loop
        )

        _ = try #require(try sender.commitUserMessage("plain", conversationID: nil))
        let conversationID = try #require(conversations.selectedConversationID)
        let message = try #require(messages.messages(for: conversationID).first)

        #expect(message.metadata[CollapsedContentBlockMetadata.collapsedBlocksKey] == nil)
    }

    @Test("排队中的消息在回放时保留折叠块")
    func preservesCollapsedBlocksThroughQueue() async throws {
        let conversations = DefaultConversationManager()
        let messages = DefaultMessageManager()
        let loop = StubAgentLoop(messages: messages)
        loop.responseContent = "response"
        let sender = DefaultMessageSender(
            conversations: conversations,
            messages: messages,
            agentLoop: loop
        )

        let firstCommit = try #require(
            try sender.commitUserMessage("first", conversationID: nil)
        )
        // 第二次发送发生在回合运行期间，会进入 pending 队列。
        let secondCommit = try #require(
            try sender.commitUserMessage(
                "second",
                imageAttachments: [],
                fileAttachments: [],
                collapsedBlocks: [
                    CollapsedContentBlock(start: 0, length: 6, title: "粘贴的文本"),
                ],
                conversationID: nil
            )
        )
        #expect(secondCommit.wasQueued)

        let conversationID = try #require(conversations.selectedConversationID)
        #expect(sender.pendingMessages(for: conversationID).first?.collapsedBlocks.count == 1)

        await sender.startTurn(for: firstCommit)
        let queued = try #require(
            messages.messages(for: conversationID).first { $0.content == "second" }
        )
        let blocks = CollapsedContentBlockMetadata.normalizedBlocks(
            from: queued.metadata,
            contentLength: queued.content.count
        )
        #expect(blocks.count == 1)
        #expect(blocks.first?.title == "粘贴的文本")
    }

    @Test("用户消息提交完成后即可读取，回合执行可随后启动")
    func commitsUserMessageBeforeStartingTurn() async throws {
        let conversations = DefaultConversationManager()
        let messages = DefaultMessageManager()
        let loop = StubAgentLoop(messages: messages)
        loop.responseContent = "response"
        let sender = DefaultMessageSender(
            conversations: conversations,
            messages: messages,
            agentLoop: loop
        )

        let optionalCommit = try sender.commitUserMessage("fast", conversationID: nil)
        let commit = try #require(optionalCommit)
        let conversationID = try #require(conversations.selectedConversationID)
        #expect(commit.conversationID == conversationID)
        #expect(commit.userMessageID != nil)
        #expect(messages.messages(for: conversationID).map(\.content) == ["fast"])

        await sender.startTurn(for: commit)
        #expect(messages.messages(for: conversationID).map(\.content) == ["fast", "response"])
    }

    @Test("提交后回合尚未调度时，连续发送仍进入队列")
    func preservesQueueBeforeDeferredTurnStart() async throws {
        let conversations = DefaultConversationManager()
        let messages = DefaultMessageManager()
        let loop = StubAgentLoop(messages: messages)
        loop.responseContent = "response"
        let sender = DefaultMessageSender(
            conversations: conversations,
            messages: messages,
            agentLoop: loop
        )

        let firstCommit = try sender.commitUserMessage("first", conversationID: nil)
        let first = try #require(firstCommit)
        let secondCommit = try sender.commitUserMessage("second", conversationID: nil)
        let second = try #require(secondCommit)
        let conversationID = try #require(conversations.selectedConversationID)

        #expect(second.wasQueued)
        #expect(sender.pendingMessages(for: conversationID).map(\.content) == ["second"])

        await sender.startTurn(for: first)
        #expect(messages.messages(for: conversationID).map(\.content) == ["first", "response", "second", "response"])
    }

    @Test("发送消息会创建会话、落用户消息并运行 Agent Loop")
    func sendsMessageThroughLoop() async throws {
        let conversations = DefaultConversationManager()
        let messages = DefaultMessageManager()
        let loop = StubAgentLoop(messages: messages)
        loop.responseContent = "response"
        let sender = DefaultMessageSender(
            conversations: conversations,
            messages: messages,
            agentLoop: loop
        )

        try await sender.sendMessage("hello", conversationID: nil)
        let id = try #require(conversations.selectedConversationID)
        #expect(messages.messages(for: id).map(\.content) == ["hello", "response"])
        #expect(sender.isSending == false)
    }

    @Test("发送回合通过观察者发出 started 和 completed")
    func sendsTurnEvents() async throws {
        let conversations = DefaultConversationManager()
        let messages = DefaultMessageManager()
        let loop = StubAgentLoop(messages: messages)
        loop.responseContent = "response"
        let sender = DefaultMessageSender(
            conversations: conversations,
            messages: messages,
            agentLoop: loop
        )
        var events: [String] = []
        let handle = sender.addMessageSenderObserver { event in
            switch event {
            case .started:
                events.append("started")
            case .turnCompleted:
                events.append("completed")
            case .turnFailed:
                events.append("failed")
            case .attachmentsChanged, .pendingMessagesChanged:
                break
            }
        }

        try await sender.sendMessage("hello", conversationID: nil)

        #expect(events == ["started", "completed"])
        handle.cancel()
    }

    @Test("附件挂起池随消息送出并编码进 metadata")
    func sendsAttachments() async throws {
        let conversations = DefaultConversationManager()
        let messages = DefaultMessageManager()
        let loop = StubAgentLoop(messages: messages)
        loop.responseContent = "ok"
        let sender = DefaultMessageSender(
            conversations: conversations,
            messages: messages,
            agentLoop: loop
        )

        let image = UserImageAttachment(mimeType: "image/png", base64Data: "AAAA")
        let file = UserFileAttachment(fileName: "a.txt", mimeType: "text/plain", textContent: "hello file")
        sender.addImageAttachment(image)
        sender.addFileAttachment(file)

        try await sender.sendMessage("看这个", conversationID: nil)
        let id = try #require(conversations.selectedConversationID)
        let userMessage = try #require(messages.messages(for: id).first { $0.role == .user })
        #expect(UserAttachmentMetadata.decodeImageAttachments(from: userMessage.metadata) == [image])
        #expect(UserAttachmentMetadata.decodeFileAttachments(from: userMessage.metadata) == [file])
        // 送出后挂起池清空
        #expect(sender.pendingImageAttachments.isEmpty)
        #expect(sender.pendingFileAttachments.isEmpty)
    }

    @Test("仅附件也可以发送，且正文保持为空")
    func sendsAttachmentOnlyMessage() async throws {
        let conversations = DefaultConversationManager()
        let messages = DefaultMessageManager()
        let loop = StubAgentLoop(messages: messages)
        loop.responseContent = "ok"
        let sender = DefaultMessageSender(
            conversations: conversations,
            messages: messages,
            agentLoop: loop
        )
        let file = UserFileAttachment(
            fileName: "design.txt",
            mimeType: "text/plain",
            textContent: "design notes"
        )

        try await sender.sendMessage(
            "",
            imageAttachments: [],
            fileAttachments: [file],
            conversationID: nil
        )

        let id = try #require(conversations.selectedConversationID)
        let userMessage = try #require(messages.messages(for: id).first { $0.role == .user })
        #expect(userMessage.content.isEmpty)
        #expect(UserAttachmentMetadata.decodeFileAttachments(from: userMessage.metadata) == [file])
    }

    @Test("同一会话发送中时新消息进入 pending 队列，回合结束后依次发出")
    func queuesWhileSending() async throws {
        let conversations = DefaultConversationManager()
        let messages = DefaultMessageManager()
        // onRunTurn 通过 continuation 控制回合时序
        let gate = Gate()
        let loop = StubAgentLoop(messages: messages)
        loop.onRunTurn = { _ in
            await gate.wait()
            let id = try! #require(conversations.selectedConversationID)
            messages.insertMessage(
                Message(conversationID: id, role: .assistant, content: "done"),
                to: id
            )
            return .completed
        }
        let sender = DefaultMessageSender(
            conversations: conversations,
            messages: messages,
            agentLoop: loop
        )

        // 第一轮发送开始（挂起在 gate）
        let first = Task { try await sender.sendMessage("first", conversationID: nil) }
        // 等待回合真正进入 running（onRunTurn 已开始等待 gate）
        try await Task.sleep(nanoseconds: 50_000_000)

        // 第二轮入队
        try await sender.sendMessage("second", conversationID: nil)
        let id = try #require(conversations.selectedConversationID)
        #expect(sender.pendingMessages(for: id).map(\.content) == ["second"])

        // 放行第一轮，队列随后发出
        gate.open()
        _ = try await first.value
        try await Task.sleep(nanoseconds: 100_000_000)
        #expect(sender.pendingMessages(for: id).isEmpty)
        #expect(messages.messages(for: id).map(\.content).contains("done"))
    }

    @Test("resumeTurn 转发到 AgentLoop（无匹配挂起点时抛出明确错误）")
    func resumesTurn() async throws {
        let conversations = DefaultConversationManager()
        let messages = DefaultMessageManager()
        let loop = StubAgentLoop(messages: messages)
        loop.responseContent = "resumed"
        loop.resumeError = AgentLoopError.invalidResumeRequest
        let sender = DefaultMessageSender(
            conversations: conversations,
            messages: messages,
            agentLoop: loop
        )
        let id = UUID()

        // 无匹配挂起点 → AgentLoop 抛出 invalidResumeRequest，sender 原样转发。
        do {
            _ = try await sender.resumeTurn(
                in: id,
                request: AgentTurnResumeRequest(suspensionID: "s-1", answer: "允许")
            )
            Issue.record("应抛出 invalidResumeRequest")
        } catch {
            #expect(error is AgentLoopError)
        }
        #expect(sender.isSending == false)
    }
}

/// 测试用 AgentLoop 桩：最小实现，直接返回预设内容。
@MainActor
final class StubAgentLoop: AgentLoopProviding {
    private let messages: any MessageManaging
    private var messageObserver: (any MessageInsertedObserverHandle)?
    private var observers: [UUID: (AgentLoopEvent) -> Void] = [:]
    var responseContent: String = ""
    var onRunTurn: ((@MainActor (UUID) async throws -> AgentLoopOutcome))?

    // MARK: 回合状态（供守门逻辑断言）
    //
    // 「会话忙不忙」的事实来源是 AgentLoop 回合状态机，因此桩必须可配置
    // 状态、当前回合与挂起点，否则测不出「外部拉起的回合」这类场景。
    var currentState: AgentLoopState = .idle
    var activeTurnID: UUID?
    var activeSuspension: AgentLoopSuspension?
    /// `resumeTurn` 的结果；默认 `.completed`。
    var resumeOutcome: AgentLoopOutcome = .completed
    /// 非 nil 时 `resumeTurn` 抛出该错误，覆盖失败分支。
    var resumeError: (any Error)?

    init(messages: any MessageManaging) {
        self.messages = messages
        messageObserver = messages.addMessageInsertedObserver { [weak self] message, conversationID in
            guard message.role == .user else { return }
            Task { @MainActor [weak self] in
                guard let self else { return }
                let outcome = (try? await self.runTurn(in: conversationID)) ?? .cancelled
                self.notify(.completed(conversationID: conversationID, turnID: self.currentTurnID(for: conversationID) ?? UUID()))
                _ = outcome
            }
        }
    }

    func addAgentLoopObserver(
        _ callback: @escaping (AgentLoopEvent) -> Void
    ) -> any AgentLoopObserverHandle {
        let id = UUID()
        observers[id] = callback
        return StubAgentLoopObserverHandle { [weak self] in
            self?.observers.removeValue(forKey: id)
        }
    }

    private func notify(_ event: AgentLoopEvent) {
        for callback in observers.values { callback(event) }
    }

    func runTurn(in conversationID: UUID) async throws -> AgentLoopOutcome {
        if let onRunTurn { return try await onRunTurn(conversationID) }
        messages.insertMessage(
            Message(conversationID: conversationID, role: .assistant, content: responseContent),
            to: conversationID
        )
        return .completed
    }

    func resumeTurn(in conversationID: UUID, request: AgentTurnResumeRequest) async throws -> AgentLoopOutcome {
        if let resumeError { throw resumeError }
        return resumeOutcome
    }

    func cancelTurn(in conversationID: UUID) {}
    func state(for conversationID: UUID) -> AgentLoopState { currentState }
    func suspension(for conversationID: UUID) -> AgentLoopSuspension? { activeSuspension }
    func isRunning(for conversationID: UUID) -> Bool { currentState == .running }
    func currentTurnID(for conversationID: UUID) -> UUID? { activeTurnID }
    func setLifecycleHooks(_ hooks: (any LifecycleHooksProviding)?) {}
}

@MainActor
private final class StubAgentLoopObserverHandle: AgentLoopObserverHandle {
    private var cancellation: (() -> Void)?

    init(cancellation: @escaping () -> Void) {
        self.cancellation = cancellation
    }

    func cancel() {
        cancellation?()
        cancellation = nil
    }
}

/// 测试用门闩：控制回合时序。
@MainActor
private final class Gate {
    private var continuation: CheckedContinuation<Void, Never>?
    private var isOpen = false

    func wait() async {
        if isOpen { return }
        await withCheckedContinuation { continuation = $0 }
    }

    func open() {
        isOpen = true
        continuation?.resume()
        continuation = nil
    }
}
