import Foundation
import ProviderAgentLoop
import ProviderConversation
import ProviderConversationInput
import ProviderLifecycleHooks
import ProviderMessage
import ProviderMessageSender
import Testing
@testable import PluginConversationInput

/// 折叠块随消息发送时的坐标系一致性。
///
/// 编辑器的折叠块区间以**草稿原文**为基准。发送路径若先 `trim` 再交给
/// sender，sender 就看不到前导空白，无法把区间平移到落库正文上：区间会被
/// ``CollapsedContentBlockMetadata/normalized(_:contentLength:)`` 判为越界而
/// 丢弃，chip 退化成一大段纯文本。
///
/// 本套件装配真实 `DefaultMessageSender` + `ConversationInputCapabilityAdapter`，
/// 覆盖两条生产发送路径（回车与发送按钮），并从落库消息的 metadata 读回区间。
@MainActor
@Suite("折叠块发送坐标")
struct CollapsedContentSendTests {
    @Test("折叠块前插入换行后发送，chip 区间仍指向原文本")
    func leadingNewlineBeforeChipKeepsBlock() throws {
        let chain = CollapsedContentSendChain()
        let body = String(repeating: "粘贴内容", count: 240)

        // 复现：在 chip 前插入一个换行再发送。区间以含换行的原文为基准。
        chain.adapter.text = "\n" + body
        chain.adapter.collapsedBlocks = [
            CollapsedContentBlock(start: 1, length: body.count, title: "粘贴的文本"),
        ]

        chain.enterViewModel.send()

        try chain.expectChipPersisted(body: body)
    }

    @Test("发送按钮路径同样保留 chip 区间")
    func sendButtonKeepsBlockAfterTrim() throws {
        let chain = CollapsedContentSendChain()
        let body = String(repeating: "粘贴内容", count: 240)

        chain.adapter.text = "  " + body + "\n"
        chain.adapter.collapsedBlocks = [
            CollapsedContentBlock(start: 2, length: body.count, title: "粘贴的文本"),
        ]

        chain.sendButtonViewModel.send()

        try chain.expectChipPersisted(body: body)
    }
}

// MARK: - Support

/// 真实发送链路：真实 Sender + 真实 Adapter + 两个 ViewModel。
@MainActor
private final class CollapsedContentSendChain {
    let conversations = DefaultConversationManager()
    let messages = DefaultMessageManager()
    let sender: DefaultMessageSender
    let adapter: ConversationInputCapabilityAdapter
    let enterViewModel: ConversationInputViewModel
    let sendButtonViewModel: SendActionBarViewModel

    init() {
        sender = DefaultMessageSender(
            conversations: conversations,
            messages: messages,
            agentLoop: CollapsedContentSendTestAgentLoop()
        )
        adapter = ConversationInputCapabilityAdapter(
            input: DefaultConversationInputProvider(),
            sender: sender,
            conversations: conversations,
            conversationState: nil
        )
        enterViewModel = ConversationInputViewModel(capability: adapter)
        sendButtonViewModel = SendActionBarViewModel(capability: adapter)
    }

    /// 断言落库正文已 trim，且 chip 区间仍精确指向原粘贴内容。
    func expectChipPersisted(body: String) throws {
        let conversationID = try #require(conversations.selectedConversationID)
        let message = try #require(messages.messages(for: conversationID).last)

        #expect(message.role == .user)
        #expect(message.content == body)

        let blocks = CollapsedContentBlockMetadata.normalizedBlocks(
            from: message.metadata,
            contentLength: message.content.count
        )
        #expect(blocks.count == 1)

        let block = try #require(blocks.first)
        #expect(block.start == 0)
        #expect(block.length == body.count)

        let start = message.content.index(message.content.startIndex, offsetBy: block.start)
        let end = message.content.index(start, offsetBy: block.length)
        #expect(String(message.content[start..<end]) == body)

        // 释放 beginTurn 挂起的回合跟踪，避免测试结束时留下待决任务。
        sender.handleAgentLoopEvent(.completed(conversationID: conversationID, turnID: UUID()))
    }
}

/// 只提供构造所需的最小面，发送用例不驱动真实回合。
@MainActor
private final class CollapsedContentSendTestAgentLoop: AgentLoopProviding {
    func addAgentLoopObserver(
        _ callback: @escaping (AgentLoopEvent) -> Void
    ) -> any AgentLoopObserverHandle {
        CollapsedContentSendTestObserverHandle()
    }

    func runTurn(in conversationID: UUID) async throws -> AgentLoopOutcome { .completed }

    func resumeTurn(
        in conversationID: UUID,
        request: AgentTurnResumeRequest
    ) async throws -> AgentLoopOutcome { .completed }

    func cancelTurn(in conversationID: UUID) {}
    func state(for conversationID: UUID) -> AgentLoopState { .idle }
    func suspension(for conversationID: UUID) -> AgentLoopSuspension? { nil }
    func isRunning(for conversationID: UUID) -> Bool { false }
    func currentTurnID(for conversationID: UUID) -> UUID? { nil }
    func setLifecycleHooks(_ hooks: (any LifecycleHooksProviding)?) {}
}

@MainActor
private final class CollapsedContentSendTestObserverHandle: AgentLoopObserverHandle {
    func cancel() {}
}
