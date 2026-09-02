import Foundation
import ProviderChatSection
import ProviderConversation
import ProviderToolbar

/// Keeps the New Chat toolbar item in sync with chat visibility and selection.
@MainActor
final class NewChatToolbarObserver {
    private weak var toolbar: (any ToolbarProviding)?
    private weak var conversations: (any ConversationManaging)?
    private weak var chat: (any ChatSectionProviding)?
    private let itemID: String
    private let makeItem: () -> ToolbarItem
    private var selectedConversationHandle: (any SelectedConversationObserverHandle)?
    private var chatSectionHandle: (any ChatSectionProvidingObserverHandle)?

    init(
        toolbar: any ToolbarProviding,
        conversations: any ConversationManaging,
        chat: any ChatSectionProviding,
        itemID: String,
        makeItem: @escaping () -> ToolbarItem
    ) {
        self.toolbar = toolbar
        self.conversations = conversations
        self.chat = chat
        self.itemID = itemID
        self.makeItem = makeItem

        selectedConversationHandle = conversations.addSelectedConversationObserver { [weak self] _ in
            self?.sync()
        }
        chatSectionHandle = chat.addObserver { [weak self] _ in
            self?.sync()
        }
        sync()
    }

    func cancel() {
        selectedConversationHandle?.cancel()
        selectedConversationHandle = nil
        chatSectionHandle?.cancel()
        chatSectionHandle = nil
    }

    private func sync() {
        guard let toolbar, let conversations, let chat else { return }
        let shouldShow = chat.isVisible && conversations.selectedConversationID != nil
        let isShown = toolbar.toolbarItems.contains { $0.id == itemID }
        if shouldShow, !isShown {
            toolbar.addToolbarItems([makeItem()])
        } else if !shouldShow, isShown {
            toolbar.removeToolbarItems(ids: [itemID])
        }
    }
}
