import Foundation
import SuperLogKit
import LumiCoreKit

/// 延时消息状态存储
///
/// 作为 @MainActor 单例，存储从 Environment 同步来的 VM 引用。
/// 工具和 Overlay 都在 MainActor 上访问，无需跨 Actor 隔离。
@MainActor
public final class DelayMessageState: ObservableObject, SuperLog {
    public static let shared = DelayMessageState()
    
    private init() {}
    
    // MARK: - Cached State
    
    /// 当前选中的会话 ID，由 DelayMessageOverlay 同步
    private(set) var cachedConversationId: UUID?
    
    private var enqueueHandler: (@MainActor (UUID, String) -> Void)?
    
    // MARK: - Sync Methods
    
    /// 同步当前会话 ID
    public func syncConversationId(_ id: UUID?) {
        cachedConversationId = id
    }
    
    public func syncEnqueueHandler(_ handler: @escaping @MainActor (UUID, String) -> Void) {
        enqueueHandler = handler
    }
    
    // MARK: - Tool Access
    
    /// 获取当前会话 ID
    public func getCurrentConversationId() -> UUID? {
        cachedConversationId
    }
    
    /// 入队延时消息
    public func enqueueDelayedMessage(conversationId: UUID, content: String) {
        guard let enqueueHandler else {
            DelayMessagePlugin.logger.error("\(Self.t)⏳ DelayMessageState: enqueueHandler 不可用")
            return
        }

        enqueueHandler(conversationId, content)

        DelayMessagePlugin.logger.info("\(Self.t)⏳ 已入队延时消息到会话 \(conversationId.uuidString.prefix(8))")
    }
}
