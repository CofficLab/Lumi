import Foundation
import MagicKit

/// 消息发送队列 ViewModel
/// 负责管理待发送消息队列，按会话隔离队列状态
@MainActor
final class MessageQueueVM: ObservableObject, SuperLog {
    nonisolated static let emoji = "📤"
    nonisolated static let verbose = true

    // MARK: - 当前会话队列状态（只读）

    @Published public var pendingMessages: [ChatMessage] = [] {
        willSet {
            // 确保在值变化前发送通知
            objectWillChange.send()
        }
    }
    @Published public var currentProcessingIndex: Int?

    // MARK: - 按会话隔离的队列状态

    @Published var pendingMessagesByConversation: [UUID: [ChatMessage]] = [:]
    private var currentProcessingIndexByConversation: [UUID: Int?] = [:]
    private var cancelledConversations = Set<UUID>()

    private var currentConversationId: UUID?

    init() {}

    // MARK: - 会话切换

    /// 切换到指定会话，返回该会话当前队列长度
    @discardableResult
    func switchToConversation(_ conversationId: UUID) -> Int {
        currentConversationId = conversationId

        // 确保该会话的状态容器存在
        if pendingMessagesByConversation[conversationId] == nil {
            pendingMessagesByConversation[conversationId] = []
        }
        if currentProcessingIndexByConversation[conversationId] == nil {
            currentProcessingIndexByConversation[conversationId] = nil
        }

        syncCurrentConversationState()

        if Self.verbose {
            AppLogger.core.info("\(Self.t)🔄 [\(conversationId.uuidString.prefix(8))] 切换会话，队列长度：\(self.pendingMessages.count)")
        }

        return pendingMessages.count
    }

    // MARK: - 队列管理

    /// 将消息入队
    /// - Parameter message: 要发送的消息
    func enqueueMessage(_ message: ChatMessage) {
        guard let conversationId = currentConversationId else {
            if Self.verbose {
                AppLogger.core.error("\(Self.t)❌ 当前没有活动对话，请先调用 switchToConversation")
            }
            return
        }

        let trimmedContent = message.content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedContent.isEmpty || !message.images.isEmpty else {
            if Self.verbose {
                AppLogger.core.error("\(Self.t)❌ 消息内容和附件不能同时为空")
            }
            return
        }

        // 添加到队列
        pendingMessagesByConversation[conversationId, default: []].append(message)
        syncCurrentConversationState()

        if Self.verbose {
            AppLogger.core.info("\(Self.t)📝 [\(String(conversationId.uuidString.prefix(8)))] 消息入队，长度：\(self.pendingMessagesByConversation[conversationId]?.count ?? 0)")
        }
    }

    /// 清空当前会话的发送队列
    func clearCurrentConversationQueue() {
        guard let conversationId = currentConversationId else { return }
        pendingMessagesByConversation[conversationId] = []
        currentProcessingIndexByConversation[conversationId] = nil
        syncCurrentConversationState()

        if Self.verbose {
            AppLogger.core.info("\(Self.t)🗑️ [\(conversationId)] 已清空发送队列")
        }
    }

    /// 移除指定索引的消息（不能移除正在处理的消息）
    func removeMessage(at index: Int) {
        guard index != currentProcessingIndex else { return }
        guard let conversationId = currentConversationId else { return }
        guard var queue = pendingMessagesByConversation[conversationId], queue.indices.contains(index) else { return }

        queue.remove(at: index)
        pendingMessagesByConversation[conversationId] = queue

        // 调整处理中索引
        if let currentIdx = currentProcessingIndexByConversation[conversationId],
           let unwrappedIdx = currentIdx,
           index < unwrappedIdx {
            currentProcessingIndexByConversation[conversationId] = unwrappedIdx - 1
        }

        syncCurrentConversationState()
    }

    /// 删除指定会话的队列
    func removeConversationQueue(_ conversationId: UUID) {
        // 标记为已取消
        cancelledConversations.insert(conversationId)

        // 移除状态
        pendingMessagesByConversation.removeValue(forKey: conversationId)
        currentProcessingIndexByConversation.removeValue(forKey: conversationId)

        // 如果是当前会话，同步状态
        if currentConversationId == conversationId {
            pendingMessages = []
            currentProcessingIndex = nil
        }

        if Self.verbose {
            AppLogger.core.info("\(Self.t)🗑️ 已删除会话 [\(String(conversationId.uuidString.prefix(8)))] 的发送队列")
        }
    }

    /// 取消当前会话的处理
    func cancelCurrentProcessing() {
        guard let conversationId = currentConversationId else { return }
        cancelledConversations.insert(conversationId)
        currentProcessingIndexByConversation[conversationId] = nil

        if currentConversationId == conversationId {
            syncCurrentConversationState()
        }
    }

    /// 取消指定会话的处理（兼容旧 API）
    func cancelProcessing(for conversationId: UUID, clearQueue: Bool) {
        cancelledConversations.insert(conversationId)

        if clearQueue {
            pendingMessagesByConversation[conversationId] = []
        }

        currentProcessingIndexByConversation[conversationId] = nil

        if currentConversationId == conversationId {
            syncCurrentConversationState()
        }
    }

    // MARK: - 检查队列状态

    /// 检查队列是否为空
    var isQueueEmpty: Bool {
        guard let conversationId = currentConversationId else { return true }
        return pendingMessagesByConversation[conversationId]?.isEmpty ?? true
    }

    /// 获取队列长度
    var queueCount: Int {
        guard let conversationId = currentConversationId else { return 0 }
        return pendingMessagesByConversation[conversationId]?.count ?? 0
    }

    // MARK: - Private

    /// 同步当前会话的状态到 Published 属性
    private func syncCurrentConversationState() {
        guard let conversationId = currentConversationId else {
            pendingMessages = []
            currentProcessingIndex = nil
            return
        }

        let oldCount = pendingMessages.count
        pendingMessages = pendingMessagesByConversation[conversationId] ?? []
        currentProcessingIndex = currentProcessingIndexByConversation[conversationId] ?? nil
    }
}
