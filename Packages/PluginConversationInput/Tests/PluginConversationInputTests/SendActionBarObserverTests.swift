import Foundation
import ProviderConversationState
import ProviderMessage
import ProviderMessageSender
import Testing
@testable import PluginConversationInput

@MainActor
@Suite("SendActionBar Observers")
struct SendActionBarObserverTests {
    // MARK: - ActionBarInputObserver

    @Test("输入文本变化后同步可发送状态")
    func inputObserverTracksTextChanges() {
        let capability = SendActionBarTestCapability()
        let viewModel = SendActionBarViewModel(capability: capability)
        let observer = ActionBarInputObserver(capability: capability, viewModel: viewModel)

        #expect(!viewModel.state.canSend)

        capability.emitText("hello")

        #expect(viewModel.state.canSend)

        capability.emitText("   ")

        #expect(!viewModel.state.canSend)
        observer.cancel()
    }

    @Test("附件变化事件同步可发送状态")
    func inputObserverTracksAttachmentChanges() {
        let capability = SendActionBarTestCapability()
        let viewModel = SendActionBarViewModel(capability: capability)
        let observer = ActionBarInputObserver(capability: capability, viewModel: viewModel)

        #expect(!viewModel.state.canSend)

        capability.pendingFileAttachments = [
            UserFileAttachment(fileName: "notes.txt", mimeType: "text/plain", textContent: "notes")
        ]
        capability.emitAttachmentsChanged()

        #expect(viewModel.state.canSend)

        capability.pendingFileAttachments = []
        capability.emitAttachmentsChanged()

        #expect(!viewModel.state.canSend)
        observer.cancel()
    }

    @Test("Observer 初始化时立即同步一次当前快照")
    func inputObserverSeedsInitialSnapshot() {
        let capability = SendActionBarTestCapability()
        capability.text = "draft"
        let viewModel = SendActionBarViewModel(capability: capability)

        // 初始化时读到的快照已经足以判定可发送，无需等待任何事件。
        #expect(viewModel.state.canSend)

        let observer = ActionBarInputObserver(capability: capability, viewModel: viewModel)
        #expect(viewModel.state.canSend)

        // 文本清空后应立即回到不可发送。
        capability.emitText("")
        #expect(!viewModel.state.canSend)
        observer.cancel()
    }

    @Test("取消后不再接收文本变化")
    func inputObserverStopsAfterCancel() {
        let capability = SendActionBarTestCapability()
        let viewModel = SendActionBarViewModel(capability: capability)
        let observer = ActionBarInputObserver(capability: capability, viewModel: viewModel)

        observer.cancel()
        capability.emitText("ignored")

        #expect(!viewModel.state.canSend)
    }

    // MARK: - SendActionBarConversationObserver

    @Test("回合开始事件切换到停止按钮")
    func conversationObserverSwitchesToStopButton() {
        let conversationID = UUID()
        let capability = SendActionBarTestCapability()
        capability.selectedConversationID = conversationID
        let viewModel = SendActionBarViewModel(capability: capability)
        let observer = SendActionBarConversationObserver(
            capability: capability,
            viewModel: viewModel
        )

        #expect(viewModel.state.showsSendButton)

        capability.sendingConversationIDs = [conversationID]
        capability.emitConversationState(.updated(conversationID))

        #expect(viewModel.state.showsStopButton)
        #expect(!viewModel.state.showsSendButton)
        observer.cancel()
    }

    @Test("回合结束事件切回发送按钮")
    func conversationObserverSwitchesBackToSendButton() {
        let conversationID = UUID()
        let capability = SendActionBarTestCapability()
        capability.selectedConversationID = conversationID
        capability.sendingConversationIDs = [conversationID]
        let viewModel = SendActionBarViewModel(capability: capability)
        let observer = SendActionBarConversationObserver(
            capability: capability,
            viewModel: viewModel
        )

        #expect(viewModel.state.showsStopButton)

        capability.sendingConversationIDs = []
        capability.emitConversationState(.updated(conversationID))

        #expect(viewModel.state.showsSendButton)
        observer.cancel()
    }

    @Test("切换会话时按新会话重新判断发送状态")
    func conversationObserverFollowsSelectedConversation() {
        let first = UUID()
        let second = UUID()
        let capability = SendActionBarTestCapability()
        capability.selectedConversationID = first
        let viewModel = SendActionBarViewModel(capability: capability)
        let observer = SendActionBarConversationObserver(
            capability: capability,
            viewModel: viewModel
        )

        #expect(viewModel.state.showsSendButton)

        // 切到一个正在发送的会话：应立即显示停止按钮。
        capability.sendingConversationIDs = [second]
        capability.emitSelectedConversation(second)

        #expect(viewModel.state.showsStopButton)

        // 切回空闲会话：回到发送按钮。
        capability.emitSelectedConversation(first)

        #expect(viewModel.state.showsSendButton)
        observer.cancel()
    }

    @Test("取消后不再接收会话事件")
    func conversationObserverStopsAfterCancel() {
        let conversationID = UUID()
        let capability = SendActionBarTestCapability()
        capability.selectedConversationID = conversationID
        let viewModel = SendActionBarViewModel(capability: capability)
        let observer = SendActionBarConversationObserver(
            capability: capability,
            viewModel: viewModel
        )

        observer.cancel()
        capability.sendingConversationIDs = [conversationID]
        capability.emitConversationState(.updated(conversationID))

        #expect(viewModel.state.showsSendButton)
    }

    @Test("会话被移除时复位发送状态")
    func conversationObserverHandlesRemovedConversation() {
        let conversationID = UUID()
        let capability = SendActionBarTestCapability()
        capability.selectedConversationID = conversationID
        capability.sendingConversationIDs = [conversationID]
        let viewModel = SendActionBarViewModel(capability: capability)
        let observer = SendActionBarConversationObserver(
            capability: capability,
            viewModel: viewModel
        )

        #expect(viewModel.state.showsStopButton)

        capability.sendingConversationIDs = []
        capability.emitConversationState(.removed(conversationID))

        #expect(viewModel.state.showsSendButton)
        observer.cancel()
    }
}
