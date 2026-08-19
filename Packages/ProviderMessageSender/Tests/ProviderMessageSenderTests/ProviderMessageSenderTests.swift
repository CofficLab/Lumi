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

    @Test("同一会话发送中时新消息进入 pending 队列，回合结束后依次发出")
    func queuesWhileSending() async throws {
        let conversations = DefaultConversationManager()
        let messages = DefaultMessageManager()
        // onRunTurn 通过 continuation 控制回合时序
        let gate = Gate()
        let loop = StubAgentLoop(messages: messages)
        loop.onRunTurn = { _ in
            await gate.wait()
            return "done"
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
private final class StubAgentLoop: AgentLoopProviding {
    private let messages: any MessageManaging
    var responseContent: String = ""
    var onRunTurn: ((@MainActor (UUID) async throws -> AgentLoopOutcome))?

    init(messages: any MessageManaging) {
        self.messages = messages
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
        throw AgentLoopError.invalidResumeRequest
    }

    func cancelTurn(in conversationID: UUID) {}
    func state(for conversationID: UUID) -> AgentLoopState { .idle }
    func suspension(for conversationID: UUID) -> AgentLoopSuspension? { nil }
    func isRunning(for conversationID: UUID) -> Bool { false }
    func currentTurnID(for conversationID: UUID) -> UUID? { nil }
    func setLifecycleHooks(_ hooks: (any LifecycleHooksProviding)?) {}

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