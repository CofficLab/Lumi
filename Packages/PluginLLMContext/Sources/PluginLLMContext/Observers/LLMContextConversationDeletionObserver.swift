import Foundation
import ProviderConversation

/// 会话被删除时清理上下文压缩数据（#350）。
///
/// `ConversationManaging.deleteConversation(id:)` 是同步接口，而块存储与账本
/// 都是 actor，清理只能挂到后台任务上；这里保留任务引用，测试可以等待清理完成。
@MainActor
final class LLMContextConversationDeletionObserver {
    private var handle: (any ConversationObserverHandle)?
    private var pendingDeletion: Task<Void, Never>?

    init(
        conversations: any ConversationManaging,
        onDelete: @escaping (UUID) async -> Void
    ) {
        handle = conversations.addConversationObserver { [weak self] event in
            guard case let .deleted(conversationID) = event else { return }
            self?.pendingDeletion = Task {
                await onDelete(conversationID)
            }
        }
    }

    /// 等待最近一次清理完成。测试用；生产路径不依赖这个时序。
    func waitForPendingDeletion() async {
        await pendingDeletion?.value
    }

    func cancel() {
        handle?.cancel()
        handle = nil
        pendingDeletion?.cancel()
        pendingDeletion = nil
    }
}