import Foundation
import ProviderConversation
import ProviderMessage
import Testing
@testable import PluginMessageList

@MainActor
@Suite("Message list change events")
struct MessageListChangeEventTests {
    @Test("当前会话插入消息后直接更新展示行")
    func appliesInsertedMessageWithoutReload() async {
        let conversations = DefaultConversationManager()
        let messages = DefaultMessageManager()
        let conversationID = UUID()
        conversations.selectConversation(id: conversationID)

        let services = MessageListServices(
            conversations: conversations,
            conversationState: nil,
            messages: messages,
            rendering: nil,
            streaming: nil,
            toolManager: nil,
            agentTurn: nil,
            promptSuggestions: nil,
            promptSuggestionExecutor: nil,
            project: nil,
            toolbar: nil,
            chat: nil
        )
        let viewModel = ListV2ViewModel(services: services)
        let detailedViewModel = ListV3ViewModel(services: services)
        let briefViewModel = ListV1ViewModel(services: services)
        let messageObserver = messages.addMessageChangeObserver { change in
            viewModel.handleMessageChange(change)
            detailedViewModel.handleMessageChange(change)
            briefViewModel.handleMessageChange(change)
        }
        defer { messageObserver.cancel() }

        await viewModel.activate(conversationID: conversationID)
        await detailedViewModel.activate(conversationID: conversationID)
        await briefViewModel.activate(conversationID: conversationID)
        let message = Message(
            conversationID: conversationID,
            role: .user,
            content: "直接显示"
        )
        messages.insertMessage(message, to: conversationID)

        #expect(viewModel.historyRows.contains { $0.id == message.id })
        #expect(viewModel.historyRows.last?.content == message.content)
        #expect(detailedViewModel.historyRows.contains { $0.id == message.id })
        #expect(detailedViewModel.historyRows.last?.content == message.content)
        #expect(briefViewModel.pendingUserMessages.contains { $0.id == message.id })
        #expect(briefViewModel.agentTurns.contains { $0.pendingAnchorMessageID == message.id })

        // 更新事件同样由插件注册的类型化观察器转发。
        messages.updateMessage(id: message.id, in: conversationID, content: "更新后的内容")
        for _ in 0..<100 {
            if viewModel.historyRows.last?.content == "更新后的内容",
               detailedViewModel.historyRows.last?.content == "更新后的内容" { break }
            try? await Task.sleep(nanoseconds: 1_000_000)
        }
        #expect(viewModel.historyRows.last?.content == "更新后的内容")
        #expect(detailedViewModel.historyRows.last?.content == "更新后的内容")
    }
}
