import Foundation
import ProviderAgentLoop
import ProviderConversation
import ProviderMessage
import Testing
@testable import ProviderMessageSender

/// 在途附件读取的计数与等待（#1023）。
///
/// 发送入口依赖发送器把「选文件 → 附件入池」这段异步窗口暴露出来，否则
/// 窗口内发出的消息会漏掉刚选中的附件。
@Suite("DefaultMessageSender 附件读取门禁")
@MainActor
struct AttachmentReadGateTests {
    @Test("附件读取计数随 begin / end 增减，多余的 end 不会变负")
    func attachmentReadCountTracksBeginAndEnd() {
        let sender = makeSender()

        sender.beginAttachmentRead()
        sender.beginAttachmentRead()
        #expect(sender.pendingAttachmentReadCount == 2)

        sender.endAttachmentRead()
        #expect(sender.pendingAttachmentReadCount == 1)

        sender.endAttachmentRead()
        #expect(sender.pendingAttachmentReadCount == 0)

        sender.endAttachmentRead()
        #expect(sender.pendingAttachmentReadCount == 0)
    }

    @Test("最后一个附件读取结束时唤醒等待中的发送入口")
    func waitResumesWhenLastReadEnds() async {
        let sender = makeSender()
        let finished = CompletionFlag()

        sender.beginAttachmentRead()
        let waiter = Task {
            await sender.waitForAttachmentReads()
            finished.set()
        }

        try? await Task.sleep(for: .milliseconds(50))
        #expect(!finished.value)

        sender.endAttachmentRead()
        await waiter.value
        #expect(finished.value)
    }

    @Test("没有在途读取时等待立即返回")
    func waitReturnsImmediatelyWhenIdle() async {
        let sender = makeSender()

        await sender.waitForAttachmentReads()

        #expect(sender.pendingAttachmentReadCount == 0)
    }

    private func makeSender() -> DefaultMessageSender {
        let messages = DefaultMessageManager()
        return DefaultMessageSender(
            conversations: DefaultConversationManager(),
            messages: messages,
            agentLoop: StubAgentLoop(messages: messages)
        )
    }
}

@MainActor
private final class CompletionFlag {
    private(set) var value = false
    func set() { value = true }
}
