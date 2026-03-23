import Foundation
import MagicKit

/// 消息发送队列 ViewModel
@MainActor
final class MessageQueueVM: ObservableObject, SuperLog {
    nonisolated static let emoji = "📤"
    nonisolated static let verbose = true

    // MARK: - 队列状态

    @Published private(set) var pendingMessages: [ChatMessage] = []
    @Published private(set) var processingMessages: [ChatMessage] = []

    /// 将消息入队
    /// - Parameter message: 要发送的消息
    func enqueueMessage(_ message: ChatMessage) {
        guard message.hasSendableContent else {
            if Self.verbose {
                AppLogger.core.error("\(Self.t)❌ 消息内容和附件不能同时为空")
            }
            return
        }

        pendingMessages.append(message)

        if Self.verbose {
            AppLogger.core.info("\(Self.t)📝 消息入队，当前总量：\(self.pendingMessages.count)")
        }
    }

    /// 按消息 ID 移除待发送消息（不能移除正在处理的消息）
    func removeMessage(id messageId: UUID) {
        guard !processingMessages.contains(where: { $0.id == messageId }) else { return }
        pendingMessages.removeAll { $0.id == messageId }
    }

    /// 标记某条消息进入处理中
    func startProcessing(_ message: ChatMessage) {
        processingMessages.removeAll { $0.conversationId == message.conversationId }
        processingMessages.append(message)
    }

    /// 清除某个会话的处理中消息
    func finishProcessing(for conversationId: UUID) {
        processingMessages.removeAll { $0.conversationId == conversationId }
    }

    func pendingMessages(for conversationId: UUID) -> [ChatMessage] {
        pendingMessages.filter { $0.conversationId == conversationId }
    }

    func isProcessing(for conversationId: UUID) -> Bool {
        processingMessages.contains { $0.conversationId == conversationId }
    }

    /// 出队并返回指定会话的第一条消息
    func dequeueFirstMessage(for conversationId: UUID) -> ChatMessage? {
        guard let index = pendingMessages.firstIndex(where: { $0.conversationId == conversationId }) else { return nil }
        return pendingMessages.remove(at: index)
    }

    func queueCount(for conversationId: UUID) -> Int {
        pendingMessages.count(where: { $0.conversationId == conversationId })
    }
}
