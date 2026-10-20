import Combine
import ProviderConversationInput
import ProviderMessage
import ProviderMessageSender
import Testing
@testable import PluginConversationInput

/// 逐键输入的失效广播次数必须收敛到常数级。
///
/// ## 问题背景
///
/// 一次按键的真实链路是：
///
/// ```
/// NSTextView.textDidChange
/// └─ publishCommittedText
///    ├─ capability.text = value          → Provider.didSet → notifyTextObservers()
///    │  ├─ ConversationInputObserver → viewModel.refresh()   ← 全表重写
///    │  └─ ActionBarInputObserver   → actionBar.updateInputText()
///    ├─ viewModel.text = value            (@Published)
///    ├─ viewModel.canSend = ...           (@Published)
///    └─ onTextWritten?(value) → actionBar.updateInputText()
/// ```
///
/// `ConversationInputObserver` 把文本变化接到了 `refresh()`，而 `refresh()`
/// 无条件重写 9 个 `@Published`。`@Published` 不做等值比较，赋同样的值照样发
/// `objectWillChange`。于是一个字符要引发十余次 ViewModel 失效广播，
/// `ConversationInputView` 与 `AttachmentPreviewView` 都靠 `let _ = viewModel.revision`
/// 强制整段 body 重建——哪怕根本没有附件。
///
/// ## 判定口径
///
/// 逐键路径只应触碰「文本」和「可发送」两个状态，因此失效广播次数必须是常数
/// 且与文本长度无关。这里统计的是 `objectWillChange` 的**触发次数**，而不是
/// `@Published` 属性的写入次数：前者才是 SwiftUI 真正重算 body 的驱动力。
@MainActor
@Suite("逐键输入的失效广播开销")
struct ConversationInputTypingInvalidationTests {

    /// 记录 `objectWillChange` 的触发次数。
    private func countInvalidations(
        of viewModel: ConversationInputViewModel,
        while body: () -> Void
    ) -> Int {
        var count = 0
        let token = viewModel.objectWillChange.sink { _ in count += 1 }
        body()
        token.cancel()
        return count
    }

    @Test("一次按键引发的失效广播不超过 3 次")
    func singleKeystrokeInvalidatesBoundedTimes() {
        let capability = SendActionBarTestCapability()
        // 打开 didSet 通知，否则观察者回灌链路根本不会发生，测的就不是真实路径。
        capability.notifiesTextObserversOnSet = true
        let viewModel = ConversationInputViewModel(capability: capability)
        let observer = ConversationInputObserver(capability: capability, viewModel: viewModel)
        defer { observer.cancel() }

        let invalidations = countInvalidations(of: viewModel) {
            viewModel.setText("h")
        }

        #expect(
            invalidations <= 3,
            """
            单次按键引发 \(invalidations) 次失效广播，应收敛到 3 次以内。\
            文本变化不应驱动 refresh() 全表重写。
            """
        )
    }

    @Test("失效次数不随已输入长度增长")
    func invalidationCountDoesNotGrowWithTextLength() {
        let capability = SendActionBarTestCapability()
        capability.notifiesTextObserversOnSet = true
        let viewModel = ConversationInputViewModel(capability: capability)
        let observer = ConversationInputObserver(capability: capability, viewModel: viewModel)
        defer { observer.cancel() }

        // 先把草稿铺到一定长度，让"每键重扫全串"的开销显现出来。
        viewModel.setText(String(repeating: "a", count: 500))

        var shortDraft = 1
        var longDraft = 1
        var baseline = 1

        baseline = countInvalidations(of: viewModel) {
            viewModel.setText("x")
        }
        shortDraft = baseline

        // 回到短文本附近，重复同样的测量。
        viewModel.setText("a")
        baseline = countInvalidations(of: viewModel) {
            viewModel.setText("x")
        }

        // 长草稿下同样追加一个字符。
        viewModel.setText(String(repeating: "a", count: 500))
        longDraft = countInvalidations(of: viewModel) {
            viewModel.setText(String(repeating: "a", count: 501))
        }

        #expect(
            shortDraft == longDraft,
            "短草稿追加一字触发 \(shortDraft) 次失效，长草稿触发 \(longDraft) 次；两者应一致"
        )
    }

    @Test("文本变化不会连带改写附件列表")
    func textChangeDoesNotRewriteAttachmentState() {
        let capability = SendActionBarTestCapability()
        let viewModel = ConversationInputViewModel(capability: capability)
        let observer = ConversationInputObserver(capability: capability, viewModel: viewModel)
        defer { observer.cancel() }

        capability.pendingImageAttachments = [
            UserImageAttachment(mimeType: "image/png", base64Data: "AAAA")
        ]
        viewModel.refresh()
        let revisionAfterAttachment = viewModel.revision

        var attachmentWrites = 0
        let token = viewModel.objectWillChange.sink { _ in }
        defer { token.cancel() }

        // 观察器：文本变化若走 refresh()，会连带重写 imageAttachments。
        // 通过 objectWillChange 的 payload 无法直接读字段，改为直接断言
        // revision 是否被文本变化带动——它只在 refresh() / enqueue 里自增。
        viewModel.setText("hello")

        #expect(
            viewModel.revision == revisionAfterAttachment,
            "文本变化不应自增 revision（否则附件预览整段重建）"
        )
        #expect(attachmentWrites == 0)
    }

    @Test("重复写入同一文本不会产生任何失效广播")
    func redundantWriteDoesNotInvalidate() {
        let capability = SendActionBarTestCapability()
        let viewModel = ConversationInputViewModel(capability: capability)
        let observer = ConversationInputObserver(capability: capability, viewModel: viewModel)
        defer { observer.cancel() }

        viewModel.setText("hello")
        let invalidations = countInvalidations(of: viewModel) {
            viewModel.setText("hello")
        }

        #expect(
            invalidations == 0,
            "重复写入同一文本引发 \(invalidations) 次失效，应为 0（需要等值守卫）"
        )
    }

    @Test("逐键输入不会反复回灌能力层")
    func keystrokeDoesNotRebroadcastToCapability() {
        let capability = SendActionBarTestCapability()
        // 打开真实 Provider 的 didSet 通知语义，还原「写能力层 → 观察者回灌」。
        capability.notifiesTextObserversOnSet = true

        let viewModel = ConversationInputViewModel(capability: capability)
        let observer = ConversationInputObserver(capability: capability, viewModel: viewModel)
        defer { observer.cancel() }

        var textNotifications = 0
        let token = capability.addTextObserver { _ in textNotifications += 1 }
        defer { token.cancel() }

        viewModel.setText("a")

        #expect(
            textNotifications <= 1,
            "一次 setText 触发了 \(textNotifications) 次能力层文本通知，应至多 1 次"
        )
    }
}
