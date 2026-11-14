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

    @Test("读取失败时等待返回 false，发送入口据此中止（#1174）")
    func waitReturnsFalseWhenAttachmentReadFails() async {
        let sender = SenderFixture().sender

        sender.beginAttachmentRead()
        let waiter = Task { await sender.waitForAttachmentReads() }
        try? await Task.sleep(for: .milliseconds(50))

        sender.recordAttachmentReadFailure()
        sender.endAttachmentRead()

        #expect(await waiter.value == false)
    }

    @Test("失败标记在新读取窗口开始时复位，干净读取仍返回 true（#1174）")
    func readFailureFlagResetsOnNextReadWindow() async {
        let sender = SenderFixture().sender

        // 第一个窗口读取失败。
        sender.beginAttachmentRead()
        let failed = Task { await sender.waitForAttachmentReads() }
        try? await Task.sleep(for: .milliseconds(50))
        sender.recordAttachmentReadFailure()
        sender.endAttachmentRead()
        #expect(await failed.value == false)

        // 新窗口开始即复位失败标记：这一次没有失败，必须报告成功，
        // 否则上一次失败会永久毒化后续所有发送。
        sender.beginAttachmentRead()
        let succeeded = Task { await sender.waitForAttachmentReads() }
        try? await Task.sleep(for: .milliseconds(50))
        sender.endAttachmentRead()
        #expect(await succeeded.value == true)
    }
}

@MainActor
private final class CompletionFlag {
    private(set) var value = false
    func set() { value = true }
}
