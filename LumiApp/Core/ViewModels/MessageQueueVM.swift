import Foundation
import MagicKit

/// 消息发送队列 ViewModel
@MainActor
final class MessageQueueVM: ObservableObject, SuperLog {
    nonisolated static let emoji = "📤"
    nonisolated static let verbose = true

    // MARK: - 队列状态

    /// 所有队列中的消息（包含 pending 和 processing 状态）
    @Published private(set) var messages: [ChatMessage] = []
    
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

        var newMessage = message
        newMessage.queueStatus = .pending
        messages.append(newMessage)
        queueVersion += 1

        if Self.verbose {
            AppLogger.core.info("\(Self.t)📝 消息入队，当前总量：\(self.messages.count)")
        }
    }

    /// 按消息 ID 移除消息（只能移除 pending 状态的消息）
    func removeMessage(id messageId: UUID) {
        guard let index = messages.firstIndex(where: { $0.id == messageId }) else { return }
        guard messages[index].queueStatus == .pending else { return }
        
        messages.remove(at: index)
        queueVersion += 1
    }

    /// 将 processing 状态的消息重新放回 pending 状态
    /// 用于处理取出消息后因故无法处理的情况
    func requeueMessage(_ message: ChatMessage) {
        guard let index = messages.firstIndex(where: { $0.id == message.id }) else { return }
        guard messages[index].queueStatus == .processing else { return }
        
        messages[index].queueStatus = .pending
        queueVersion += 1
        
        if Self.verbose {
            AppLogger.core.info("\(Self.t)🔄 消息重新入队：\(message.content.max(50))")
        }
    }

    /// 标记某条消息进入处理中状态
    func startProcessing(_ message: ChatMessage) {
        guard let index = messages.firstIndex(where: { $0.id == message.id }) else { return }
        messages[index].queueStatus = .processing
    }

    /// 清除某个会话的 processing 状态消息（处理完成后调用）
    func finishProcessing(for conversationId: UUID) {
        messages.removeAll { $0.conversationId == conversationId && $0.queueStatus == .processing }
        queueVersion += 1
    }

    /// 获取指定会话的待发送消息
    func pendingMessages(for conversationId: UUID) -> [ChatMessage] {
        messages.filter { $0.conversationId == conversationId && $0.queueStatus == .pending }
    }

    /// 判断指定会话是否有消息正在处理中
    func isProcessing(for conversationId: UUID) -> Bool {
        messages.contains { $0.conversationId == conversationId && $0.queueStatus == .processing }
    }

    /// 从队列中出队下一个可发送的消息，并将其状态从 pending 改为 processing
    /// 规则：如果某个对话已有消息在 processing 状态，则该对话的 pending 消息不能出队
    func dequeueNextEligibleMessage() -> ChatMessage? {
        // 获取所有正在处理的会话 ID
        let processingConversationIds = Set(
            messages.filter { $0.queueStatus == .processing }.map { $0.conversationId }
        )
        
        // 找到第一个不在处理中会话的 pending 消息
        guard let index = messages.firstIndex(where: { 
            $0.queueStatus == .pending && !processingConversationIds.contains($0.conversationId) 
        }) else {
            return nil
        }

        // 更新状态为 processing
        messages[index].queueStatus = .processing
        queueVersion += 1
        return messages[index]
    }

    /// 获取指定会话的队列消息数量（仅 pending 状态）
    func queueCount(for conversationId: UUID) -> Int {
        messages.count(where: { $0.conversationId == conversationId && $0.queueStatus == .pending })
    }
}
