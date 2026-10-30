import Foundation
import ProviderChatSection
import ProviderConversation
import SwiftUI

/// 让分叉按钮跟随「当前是否选中对话」。
///
/// 分叉的前提是有对话可分叉：没有选中对话时按钮没有意义，
/// 因此此时直接把它从 Action Bar 撤掉，而不是留一个点了没反应的图标。
@MainActor
final class ConversationForkSelectionObserver {
    private weak var chat: (any ChatSectionProviding)?
    private weak var conversations: (any ConversationManaging)?
    private let itemID: String
    private let makeItem: () -> ChatSectionBarItem
    private var selectedConversationHandle: (any SelectedConversationObserverHandle)?
    /// 是否存在选中对话。
    ///
    /// 以观察者回调携带的 ID 为准，而不是每次回读 `conversations`：
    /// `ConversationManaging` 的实现可能在插件启动后被替换（见
    /// `ConversationManagerPlugin`），弱引用会指向旧实例，其选中态可能已过期。
    private var hasSelectedConversation: Bool
    /// 本 observer 是否已把按钮注册进 Action Bar。
    ///
    /// `ChatSectionProviding` 不暴露 `barItems`，而该按钮只由本 observer
    /// 注册与移除，所以注册态由这里自行维护。
    private var isRegistered = false

    init(
        chat: any ChatSectionProviding,
        conversations: any ConversationManaging,
        itemID: String,
        makeItem: @escaping () -> ChatSectionBarItem
    ) {
        self.chat = chat
        self.conversations = conversations
        self.itemID = itemID
        self.makeItem = makeItem
        self.hasSelectedConversation = conversations.selectedConversationID != nil

        selectedConversationHandle = conversations.addSelectedConversationObserver { [weak self] selectedID in
            self?.setHasSelectedConversation(selectedID != nil)
        }
        sync()
    }

    func cancel() {
        selectedConversationHandle?.cancel()
        selectedConversationHandle = nil
    }

    /// 更新选中态并同步按钮的注册状态。
    private func setHasSelectedConversation(_ hasSelection: Bool) {
        guard hasSelectedConversation != hasSelection else { return }
        hasSelectedConversation = hasSelection
        sync()
    }

    /// 同步按钮的注册状态：选中对话时注册，未选中时移除。
    private func sync() {
        guard let chat else { return }
        let shouldShow = hasSelectedConversation
        guard shouldShow != isRegistered else { return }

        if shouldShow {
            chat.addBarItems([makeItem()])
        } else {
            chat.removeBarItem(id: itemID)
        }
        isRegistered = shouldShow
    }
}
