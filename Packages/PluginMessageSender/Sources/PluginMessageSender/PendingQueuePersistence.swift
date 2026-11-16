import Foundation
import os
import ProviderMessageSender

/// 把 ``MessageSender`` 的待发队列持久化到磁盘，并在启动时恢复（#596）。
///
/// 队列的每次变化（入队 / 取消 / 排空 / 会话删除）都会发布
/// ``MessageSenderEvent/pendingMessagesChanged(conversationID:)``；本类订阅该
/// 事件，每次变化即把完整快照落盘，因此退出前队列已是持久化的，重启不丢。
@MainActor
final class PendingQueuePersistence {
    private static let logger = Logger(
        subsystem: "com.coffic.lumi.plugin.message-sender",
        category: "PendingQueue"
    )

    private let store: PendingQueueStore
    private let sender: MessageSender
    private var observerHandle: (any MessageSenderObserverHandle)?

    init(store: PendingQueueStore, sender: MessageSender) {
        self.store = store
        self.sender = sender
    }

    /// 启动时把上次未排空的队列装回 sender（在订阅之前调用，避免恢复触发重复落盘）。
    func restore() {
        let persisted = store.load()
        guard !persisted.isEmpty else { return }
        sender.restorePendingQueues(persisted)
    }

    /// 订阅队列变化，每次变化即落盘。
    func startObserving() {
        observerHandle = sender.addMessageSenderObserver { [weak self] event in
            guard case .pendingMessagesChanged = event else { return }
            self?.persist()
        }
    }

    /// 立即把当前队列快照落盘；退出收尾时再调一次作为兜底。
    func persist() {
        do {
            try store.save(sender.allPendingMessages)
        } catch {
            Self.logger.error("待发队列落盘失败: \(error.localizedDescription)")
        }
    }

    func stop() {
        observerHandle?.cancel()
        observerHandle = nil
    }
}