import Foundation
import MagicKit

/// 延时消息状态存储
///
/// 作为 @MainActor 单例，存储从 Environment 同步来的 VM 引用。
/// 工具和 Overlay 都在 MainActor 上访问，无需跨 Actor 隔离。
@MainActor
final class DelayMessageState: ObservableObject {
    static let shared = DelayMessageState()
    
    private init() {}
    
    // MARK: - Cached State
    
    /// 当前选中的会话 ID，由 DelayMessageOverlay 同步
    private(set) var cachedConversationId: UUID?
    
    /// 消息队列 VM 引用，由 DelayMessageOverlay 同步
    private(set) var messageQueueVM: MessageQueueVM?
    
    // MARK: - Sync Methods
    
    /// 同步当前会话 ID
    func syncConversationId(_ id: UUID?) {
        cachedConversationId = id
    }
    
    /// 同步消息队列 VM
    func syncMessageQueueVM(_ vm: MessageQueueVM) {
        messageQueueVM = vm
    }
    
    // MARK: - Tool Access
    
    /// 获取当前会话 ID
    func getCurrentConversationId() -> UUID? {
        cachedConversationId
    }
    
    /// 入队延时消息
    func enqueueDelayedMessage(conversationId: UUID, content: String) {
        guard let vm = messageQueueVM else {
            AppLogger.core.error("⏳ DelayMessageState: messageQueueVM 不可用")
            return
        }
        
        let message = ChatMessage(
            role: .user,
            conversationId: conversationId,
            content: content
        )
        vm.enqueueMessage(message)
        
        AppLogger.core.info("⏳ 已入队延时消息到会话 \(conversationId.uuidString.prefix(8))")
    }
}