import Foundation
import MagicKit

/// 消息发送队列 ViewModel
@MainActor
final class MessageQueueVM: ObservableObject, SuperLog {
    nonisolated static let emoji = "📤"
    nonisolated static let verbose = true

    // MARK: - 按会话隔离的队列状态

    @Published private(set) var pendingMessagesByConversation: [UUID: [ChatMessage]] = [:]
    @Published private(set) var currentProcessingIndexByConversation: [UUID: Int?] = [:]

    // MARK: - 队列管理

    /// 将消息入队
    /// - Parameter message: 要发送的消息
    func enqueueMessage(_ message: ChatMessage, in conversationId: UUID) {
        let trimmedContent = message.content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedContent.isEmpty || !message.images.isEmpty else {
            if Self.verbose {
                AppLogger.core.error("\(Self.t)❌ 消息内容和附件不能同时为空")
            }
            return
        }

        pendingMessagesByConversation[conversationId, default: []].append(message)

        if Self.verbose {
            AppLogger.core.info("\(Self.t)📝 [\(String(conversationId.uuidString.prefix(8)))] 消息入队，长度：\(self.pendingMessagesByConversation[conversationId]?.count ?? 0)")
        }
    }

    /// 清空指定会话的发送队列
    func clearQueue(for conversationId: UUID) {
        pendingMessagesByConversation[conversationId] = []
        currentProcessingIndexByConversation[conversationId] = nil

        if Self.verbose {
            AppLogger.core.info("\(Self.t)🗑️ [\(conversationId)] 已清空发送队列")
        }
    }

    /// 移除指定索引的消息（不能移除正在处理的消息）
    func removeMessage(at index: Int, in conversationId: UUID) {
        guard index != currentProcessingIndexByConversation[conversationId] ?? nil else { return }
        guard var queue = pendingMessagesByConversation[conversationId], queue.indices.contains(index) else { return }

        queue.remove(at: index)
        pendingMessagesByConversation[conversationId] = queue

        // 调整处理中索引
        if let currentIdx = currentProcessingIndexByConversation[conversationId],
           let unwrappedIdx = currentIdx,
           index < unwrappedIdx {
            currentProcessingIndexByConversation[conversationId] = unwrappedIdx - 1
        }
    }

    func setCurrentProcessingIndex(_ index: Int?, for conversationId: UUID) {
        currentProcessingIndexByConversation[conversationId] = index
    }

    func pendingMessages(for conversationId: UUID) -> [ChatMessage] {
        pendingMessagesByConversation[conversationId] ?? []
    }

    func currentProcessingIndex(for conversationId: UUID) -> Int? {
        currentProcessingIndexByConversation[conversationId] ?? nil
    }

    func removeFirstMessage(for conversationId: UUID) {
        guard var queue = pendingMessagesByConversation[conversationId], !queue.isEmpty else { return }
        queue.removeFirst()
        pendingMessagesByConversation[conversationId] = queue
    }

    // MARK: - 检查队列状态

    func queueCount(for conversationId: UUID) -> Int {
        return pendingMessagesByConversation[conversationId]?.count ?? 0
    }
}
