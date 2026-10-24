import Foundation
import ProviderConversation
import ProviderConversationInput
import ProviderConversationInputBlock
import ProviderConversationState
import ProviderMessage
import ProviderMessageSender
import Testing
@testable import PluginConversationInput

/// `ConversationInputViewModel.setText` 必须同步刷新 `canSend`。
///
/// ## 回归背景
///
/// `canSend` 原本只在 `refresh()` 里重算，而 `refresh()` 由
/// `ConversationInputObserver` 驱动；`setText()` 仅写能力层、不动界面状态。
/// 于是任何**不经过逐键文本变更通知**的写入路径都会让发送按钮停留在
/// `disabled`——表现是「输入框里有字，但发送按钮一直是灰的」。
///
/// 已确认的受影响路径：
/// - UI 测试的 `typeText`（一次性合成整段文本，见 `LumiAskUserUITests`）
/// - 粘贴、语音输入等非逐键写入
///
/// 真实用户逐字打字时每键都触发 observer 回读，因此该缺陷在人工使用下
/// 很难察觉，却让整批聊天类 UI 测试长期失败。
@MainActor
@Suite("ConversationInputViewModel 输入同步")
struct ConversationInputViewModelInputSyncTests {

    @Test("setText 非空白文本后立即可发送，不等 Observer 回读")
    func setTextEnablesSendImmediately() {
        let capability = SendActionBarTestCapability()
        let viewModel = ConversationInputViewModel(capability: capability)

        #expect(!viewModel.canSend, "初始无内容时不可发送")

        viewModel.setText("hello")

        #expect(viewModel.canSend, "写入非空文本后应立即可发送")
        #expect(viewModel.text == "hello", "本地 text 应与写入值一致")
        #expect(capability.text == "hello", "能力层应收到同一份文本")
    }

    @Test("setText 写入纯空白时仍不可发送")
    func setTextWhitespaceRemainsNotSendable() {
        let capability = SendActionBarTestCapability()
        let viewModel = ConversationInputViewModel(capability: capability)

        viewModel.setText("   \n\t ")

        #expect(!viewModel.canSend, "纯空白不应被判为可发送")
    }

    @Test("setText 清空文本后回到不可发送")
    func setTextClearingResetsSendable() {
        let capability = SendActionBarTestCapability()
        let viewModel = ConversationInputViewModel(capability: capability)

        viewModel.setText("hello")
        #expect(viewModel.canSend)

        viewModel.setText("")

        #expect(!viewModel.canSend, "清空后应回到不可发送")
    }

    @Test("setText 与 refresh 的 canSend 判定一致")
    func setTextAgreesWithRefresh() {
        let capability = SendActionBarTestCapability()
        let viewModel = ConversationInputViewModel(capability: capability)

        for value in ["", "  ", "a", "hello", "\n", "多字节文本 ✅"] {
            viewModel.setText(value)
            let afterSet = viewModel.canSend

            // Observer 回读走 refresh()，结论必须与同步路径一致，
            // 否则会出现「按钮先亮后灭」或反之的抖动。
            viewModel.refresh()

            #expect(
                afterSet == viewModel.canSend,
                "setText 与 refresh 对「\(value)」的 canSend 判定不一致"
            )
        }
    }

    @Test("仅有附件时，即使文本为空也可发送")
    func attachmentsAloneEnableSend() throws {
        let capability = SendActionBarTestCapability()
        let viewModel = ConversationInputViewModel(capability: capability)
        viewModel.refresh()

        #expect(!viewModel.canSend)

        capability.pendingFileAttachments = [Self.makeAttachment()]
        viewModel.refresh()

        #expect(viewModel.canSend, "存在待发送附件时应当可发送")
    }

    @Test("send 在 setText 之后立即可用，无需等待回读")
    func sendWorksRightAfterSetText() throws {
        let capability = SendActionBarTestCapability()
        capability.commit = MessageSendCommit(conversationID: UUID(), userMessageID: UUID())
        let viewModel = ConversationInputViewModel(capability: capability)

        viewModel.setText("hi")
        viewModel.send()

        #expect(capability.commits.count == 1, "setText 后应能立即发送")
        #expect(capability.commits.first?.content == "hi")
    }

    @Test("纯空白输入时 send 不提交")
    func sendIgnoresWhitespaceOnlyText() {
        let capability = SendActionBarTestCapability()
        capability.commit = MessageSendCommit(conversationID: UUID(), userMessageID: UUID())
        let viewModel = ConversationInputViewModel(capability: capability)

        viewModel.setText("   \n  ")
        viewModel.send()

        #expect(capability.commits.isEmpty, "纯空白不应产生提交")
    }

    @Test("setText 会把文本旁路通知到派生的发送按钮")
    func setTextNotifiesActionBar() {
        let capability = SendActionBarTestCapability()
        let viewModel = ConversationInputViewModel(capability: capability)

        // 模拟插件装配：发送按钮由独立 ViewModel 驱动，经 onTextWritten 同步。
        let actionBar = SendActionBarViewModel(capability: capability)
        var notified: [String] = []
        viewModel.onTextWritten = { text in
            notified.append(text)
            actionBar.updateInputText(text)
        }

        viewModel.setText("hello")

        #expect(notified == ["hello"], "每次写入都应通知按钮一次")
        #expect(
            actionBar.state.canSend,
            "直接写入后按钮应立即可用，否则输入框有内容而按钮仍是灰的"
        )

        actionBar.updateInputText("")
        #expect(!actionBar.state.canSend)
    }

    // MARK: - Helper

    private static func makeAttachment() -> UserFileAttachment {
        UserFileAttachment(
            fileName: "a.txt",
            mimeType: "text/plain",
            textContent: "x"
        )
    }
}
