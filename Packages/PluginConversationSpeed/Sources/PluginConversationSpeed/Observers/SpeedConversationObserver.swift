import Foundation
import KitSuperLog
import os
import ProviderConversation
import ProviderMessage

/// 监听选中会话变化，并为速度 ViewModel 提供当前会话的消息快照。
@MainActor
final class SpeedConversationObserver: SuperLog {
    nonisolated static let logger = Logger(
        subsystem: "com.coffic.lumi.plugin.conversation-speed",
        category: "SpeedConversationObserver"
    )

    private let conversations: any ConversationManaging
    private let messages: any MessageManaging
    private let viewModel: ConversationSpeedViewModel
    private var observer: (any SelectedConversationObserverHandle)?
    private var refreshTask: Task<Void, Never>?

    init(
        conversations: any ConversationManaging,
        messages: any MessageManaging,
        viewModel: ConversationSpeedViewModel
    ) {
        self.conversations = conversations
        self.messages = messages
        self.viewModel = viewModel

        scheduleRefresh(for: conversations.selectedConversationID)
        observer = conversations.addSelectedConversationObserver { [weak self] conversationID in
            self?.selectedConversationDidChange(to: conversationID)
        }
    }

    func cancel() {
        refreshTask?.cancel()
        refreshTask = nil
        observer?.cancel()
        observer = nil
    }

    private func selectedConversationDidChange(to conversationID: UUID?) {
        if conversationID == nil {
            refreshTask?.cancel()
            viewModel.selectConversation(nil, messages: [])
            return
        }
        scheduleRefresh(for: conversationID)
    }

    /// 速度只用于工具栏展示，不能阻塞会话切换时 MessageList 的首屏读取。
    /// `messages(for:)` 目前仍是 MainActor API，因此这里采用低优先级 + 让出一拍，
    /// 并在执行前确认目标会话仍然有效。
    private func scheduleRefresh(for conversationID: UUID?) {
        refreshTask?.cancel()
        guard let conversationID else {
            viewModel.selectConversation(nil, messages: [])
            return
        }

        refreshTask = Task(priority: .utility) { @MainActor [weak self] in
            await Task.yield()
            guard !Task.isCancelled,
                  let self,
                  self.conversations.selectedConversationID == conversationID else { return }
            self.refresh(conversationID: conversationID)
        }
    }

    private func refresh(conversationID: UUID?) {
        guard let conversationID else {
            viewModel.selectConversation(nil, messages: [])
            return
        }

        var snapshot = messages.messages(for: conversationID)
        if snapshot.isEmpty, let lastMessage = messages.lastMessage(in: conversationID) {
            snapshot = [lastMessage]
        }
        viewModel.selectConversation(conversationID, messages: snapshot)
    }
}
