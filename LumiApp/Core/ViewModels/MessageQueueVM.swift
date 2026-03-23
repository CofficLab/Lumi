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
    
    /// 队列版本号，每次队列变化时递增，用于外部监听
    @Published private(set) var queueVersion: Int = 0

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
        queueVersion += 1

        if Self.verbose {
            AppLogger.core.info("\(Self.t)📝 消息入队，当前总量：\(self.pendingMessages.count)")
        }
    }

    /// 按消息 ID 移除待发送消息（不能移除正在处理的消息）
    func removeMessage(id messageId: UUID) {
        guard !processingMessages.contains(where: { $0.id == messageId }) else { return }
        let originalCount = pendingMessages.count
        pendingMessages.removeAll { $0.id == messageId }
        if pendingMessages.count < originalCount {
            queueVersion += 1
        }
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

    /// 从 `pendingMessages` 出队并移动到 `processingMessages`，返回被选中的消息。
    /// 规则：如果某个对话在 `processingMessages` 中已有消息在处理，则该对话的待发送消息不能出队。
    func dequeueNextEligibleMessage() -> ChatMessage? {
        let processingConversationIds = Set(processingMessages.map { $0.conversationId })
        guard let index = pendingMessages.firstIndex(where: { !processingConversationIds.contains($0.conversationId) }) else {
            return nil
        }

        // 先从 pending 移除，再放入 processing，避免短暂状态不一致
        let message = pendingMessages.remove(at: index)
        processingMessages.append(message)
        queueVersion += 1
        return message
    }

    func queueCount(for conversationId: UUID) -> Int {
        pendingMessages.count(where: { $0.conversationId == conversationId })
    }
}