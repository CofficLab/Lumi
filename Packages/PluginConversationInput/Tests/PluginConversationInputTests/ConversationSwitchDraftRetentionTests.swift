import Foundation
import ProviderMessage
import ProviderMessageSender
import Testing
@testable import PluginConversationInput

/// 回归 #781：`create_new_conversation` 在同一主 actor 连续段里做
/// 「创建即选中 B → 恢复 A」的瞬时选中往返，发出两次切换通知。
/// 输入插件不得据此清空当前对话的未发送草稿与附件；只有选中态
/// 真正落定到别的对话时才清空。
@Suite("对话切换草稿保留（#781）")
@MainActor
struct ConversationSwitchDraftRetentionTests {

    /// 装配：能力层带草稿文本与两类附件，ViewModel + 生产同款观察者。
    private func makeFixture(
        selected: UUID?
    ) -> (capability: SendActionBarTestCapability, viewModel: ConversationInputViewModel, observer: ActionBarConversationObserver) {
        let capability = SendActionBarTestCapability()
        capability.selectedConversationID = selected
        capability.text = "do not lose this draft"
        capability.addImageAttachment(UserImageAttachment(mimeType: "image/png", base64Data: "AAAA"))
        capability.addFileAttachment(
            UserFileAttachment(fileName: "notes.txt", mimeType: "text/plain", textContent: "notes")
        )
        let viewModel = ConversationInputViewModel(capability: capability)
        let observer = ActionBarConversationObserver(capability: capability, viewModel: viewModel)
        return (capability, viewModel, observer)
    }

    @Test("瞬时选中往返 A→B→A 不得清空草稿与附件")
    func transientRoundTripPreservesDraft() async throws {
        let a = UUID()
        let b = UUID()
        let (capability, viewModel, observer) = makeFixture(selected: a)
        defer { observer.cancel() }

        // 复刻工具链路：两次通知在同一主 actor 连续段内发出，中间无挂起。
        capability.emitSelectedConversation(b)
        capability.emitSelectedConversation(a)
        await awaitSettle()

        #expect(capability.text == "do not lose this draft")
        #expect(capability.pendingImageAttachments.count == 1)
        #expect(capability.pendingFileAttachments.count == 1)
        #expect(capability.clearInputCount == 0)
        #expect(viewModel.text == "do not lose this draft")
        #expect(viewModel.hasAttachments)
    }

    @Test("真实切换到另一对话仍要清空草稿与附件")
    func realSwitchStillClearsDraft() async throws {
        let a = UUID()
        let b = UUID()
        let (capability, viewModel, observer) = makeFixture(selected: a)
        defer { observer.cancel() }

        capability.emitSelectedConversation(b)
        await awaitSettle()

        #expect(capability.text.isEmpty)
        #expect(capability.pendingImageAttachments.isEmpty)
        #expect(capability.pendingFileAttachments.isEmpty)
        #expect(viewModel.text.isEmpty)
        #expect(!viewModel.hasAttachments)
    }

    @Test("新建会话未选中态的瞬时往返 nil→B→nil 保留草稿")
    func transientRoundTripFromNilPreservesDraft() async throws {
        let b = UUID()
        let (capability, viewModel, observer) = makeFixture(selected: nil)
        defer { observer.cancel() }

        capability.emitSelectedConversation(b)
        capability.emitSelectedConversation(nil)
        await awaitSettle()

        #expect(capability.text == "do not lose this draft")
        #expect(capability.pendingImageAttachments.count == 1)
        #expect(capability.pendingFileAttachments.count == 1)
        #expect(capability.clearInputCount == 0)
        #expect(viewModel.text == "do not lose this draft")
    }

    @Test("往返保留草稿后，再真实切走仍要清空")
    func laterRealSwitchAfterRoundTripClears() async throws {
        let a = UUID()
        let b = UUID()
        let c = UUID()
        let (capability, viewModel, observer) = makeFixture(selected: a)
        defer { observer.cancel() }

        capability.emitSelectedConversation(b)
        capability.emitSelectedConversation(a)
        await awaitSettle()
        #expect(capability.text == "do not lose this draft")

        capability.emitSelectedConversation(c)
        await awaitSettle()
        #expect(capability.text.isEmpty)
        #expect(capability.pendingImageAttachments.isEmpty)
        #expect(capability.pendingFileAttachments.isEmpty)
        #expect(viewModel.text.isEmpty)
    }
}