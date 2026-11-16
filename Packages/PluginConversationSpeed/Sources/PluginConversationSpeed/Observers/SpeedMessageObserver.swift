import Foundation
import ProviderMessage

/// 监听消息插入，并刷新当前选中会话的速度状态。
@MainActor
final class SpeedMessageObserver {
    private let messages: any MessageManaging
    private let viewModel: ConversationSpeedViewModel
    private var observer: (any MessageInsertedObserverHandle)?
    private var refreshTask: Task<Void, Never>?

    init(messages: any MessageManaging, viewModel: ConversationSpeedViewModel) {
        self.messages = messages
        self.viewModel = viewModel
        observer = messages.addMessageInsertedObserver { [weak self] _, conversationID in
            self?.messageDidInsert(in: conversationID)
        }
    }

    func cancel() {
        refreshTask?.cancel()
        refreshTask = nil
        observer?.cancel()
        observer = nil
    }

    private func messageDidInsert(in conversationID: UUID) {
        guard viewModel.selectedConversationID == conversationID else { return }

        refreshTask?.cancel()
        // 事件发生时同步记录代次：此后任何选择 / 插入事件都会使本次快照过时（#1156）。
        let generation = viewModel.beginRefresh()
        refreshTask = Task(priority: .utility) { @MainActor [weak self] in
            try? await Task.sleep(for: .milliseconds(150))
            guard !Task.isCancelled, let self,
                  self.viewModel.selectedConversationID == conversationID,
                  self.viewModel.refreshGeneration == generation else { return }

            let snapshot = await self.messages.messagesSnapshot(in: conversationID)
            // 快照读取期间可能又发生了选择 / 插入事件，写回前必须再次比对。
            guard !Task.isCancelled,
                  self.viewModel.selectedConversationID == conversationID,
                  self.viewModel.refreshGeneration == generation else { return }
            self.viewModel.refresh(conversationID: conversationID, messages: snapshot)
        }
    }
}
