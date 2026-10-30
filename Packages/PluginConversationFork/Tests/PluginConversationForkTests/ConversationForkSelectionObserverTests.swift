import Foundation
import ProviderChatSection
import ProviderConversation
import SwiftUI
import Testing
@testable import PluginConversationFork

@Suite("ConversationForkSelectionObserver")
@MainActor
struct ConversationForkSelectionObserverTests {
    private let itemID = "fork.action-bar-button"

    /// 构造一个只关心「分叉按钮是否在 Action Bar 里」的最小环境。
    private func makeObserver(
        chat: DefaultChatSectionProviding,
        conversations: DefaultConversationManager
    ) -> ConversationForkSelectionObserver {
        ConversationForkSelectionObserver(
            chat: chat,
            conversations: conversations,
            itemID: itemID
        ) {
            ChatSectionBarItem(id: itemID, order: 80, placement: .actionTrailing) {
                Text("Fork")
            }
        }
    }

    @Test("未选中对话时不注册分叉按钮")
    func buttonHiddenWithoutSelectedConversation() {
        let chat = DefaultChatSectionProviding()
        let conversations = DefaultConversationManager()

        let observer = makeObserver(chat: chat, conversations: conversations)
        defer { observer.cancel() }

        #expect(chat.barItems.isEmpty)
    }

    @Test("选中对话后注册分叉按钮，取消选择后移除")
    func buttonFollowsSelectionState() throws {
        let chat = DefaultChatSectionProviding()
        let conversations = DefaultConversationManager()
        // `createConversation` 会自动选中，先取消以构造「未选中」起点。
        let id = try conversations.createConversation(title: nil, projectPath: nil, providerID: nil, modelName: nil)
        conversations.deselectConversation()

        let observer = makeObserver(chat: chat, conversations: conversations)
        defer { observer.cancel() }

        #expect(chat.barItems.isEmpty)

        conversations.selectConversation(id: id)
        #expect(chat.barItems.map(\.id) == [itemID])

        conversations.deselectConversation()
        #expect(chat.barItems.isEmpty)
    }

    @Test("重复选中同一对话不会重复注册")
    func doesNotRegisterTwice() throws {
        let chat = DefaultChatSectionProviding()
        let conversations = DefaultConversationManager()
        let id = try conversations.createConversation(title: nil, projectPath: nil, providerID: nil, modelName: nil)
        conversations.deselectConversation()

        let observer = makeObserver(chat: chat, conversations: conversations)
        defer { observer.cancel() }

        conversations.selectConversation(id: id)
        conversations.selectConversation(id: id)
        #expect(chat.barItems.count == 1)

        conversations.deselectConversation()
        conversations.selectConversation(id: id)
        #expect(chat.barItems.count == 1)
    }
}
