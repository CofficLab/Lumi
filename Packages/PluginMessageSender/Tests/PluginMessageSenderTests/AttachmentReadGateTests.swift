import Foundation
import Testing
@testable import PluginMessageSender

/// 插件发送器的在途附件读取门禁（#1023）。
///
/// 该实现与 `ProviderMessageSender.DefaultMessageSender` 是两份独立代码，
/// 需要各自锁定「读取窗口内发送必须等待」的行为。
@Suite("MessageSender 附件读取门禁")
@MainActor
struct AttachmentReadGateTests {
    @Test("附件读取计数随 begin / end 增减，多余的 end 不会变负")
    func attachmentReadCountTracksBeginAndEnd() {
        let sender = SenderFixture().sender

        sender.beginAttachmentRead()
        sender.beginAttachmentRead()
        #expect(sender.pendingAttachmentReadCount == 2)

        sender.endAttachmentRead()
        sender.endAttachmentRead()
        sender.endAttachmentRead()
        #expect(sender.pendingAttachmentReadCount == 0)
    }

    @Test("最后一个附件读取结束时唤醒等待中的发送入口")
    func waitResumesWhenLastReadEnds() async {
        let sender = SenderFixture().sender
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
}

@MainActor
private final class CompletionFlag {
    private(set) var value = false
    func set() { value = true }
}
