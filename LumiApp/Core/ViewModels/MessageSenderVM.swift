import Foundation
import MagicKit
/// 消息发送事件
/// 用于向外部报告队列处理状态
@MainActor
enum MessageSendEvent: Sendable {
    /// 开始处理队列
    case processingStarted(conversationId: UUID)
    /// 队列处理完成
    case processingFinished(conversationId: UUID)
    /// 需要发送消息
    /// - Parameters:
    ///   - message: 待发送的消息
    ///   - conversationId: 所属会话 ID
    case sendMessage(ChatMessage, conversationId: UUID)
}

/// 消息发送队列 ViewModel
/// 负责管理待发送消息队列，按会话隔离发送
@MainActor
final class MessageSenderVM: ObservableObject, SuperLog {
    nonisolated static let emoji = "📤"
    nonisolated static let verbose = false

    // MARK: - 事件流

    var events: AsyncStream<MessageSendEvent> {
        AsyncStream { continuation in
            self.eventContinuation = continuation
        }
    }

    private var eventContinuation: AsyncStream<MessageSendEvent>.Continuation?

    // MARK: - 当前会话 UI 状态

    @Published public fileprivate(set) var currentConversationId: UUID?
    @Published public fileprivate(set) var pendingMessages: [ChatMessage] = []
    @Published public fileprivate(set) var currentProcessingIndex: Int?
    @Published public fileprivate(set) var isSending: Bool = false

    // MARK: - 按会话隔离的队列状态

    private var pendingMessagesByConversation: [UUID: [ChatMessage]] = [:]
    private var currentProcessingIndexByConversation: [UUID: Int?] = [:]
    private var isSendingByConversation: [UUID: Bool] = [:]
    private var cancelledConversations = Set<UUID>()
    private var sendTasksByConversation: [UUID: Task<Void, Never>] = [:]

    init() {}

    // MARK: - 会话管理

    @discardableResult
    func switchToConversation(_ conversationId: UUID) -> Int {
        currentConversationId = conversationId

        if pendingMessagesByConversation[conversationId] == nil {
            pendingMessagesByConversation[conversationId] = []
        }
        if currentProcessingIndexByConversation[conversationId] == nil {
            currentProcessingIndexByConversation[conversationId] = nil
        }
        if isSendingByConversation[conversationId] == nil {
            isSendingByConversation[conversationId] = false
        }

        syncCurrentConversationState()

        if Self.verbose {
            AppLogger.core.info("\(Self.t)🔄 [\(conversationId.uuidString)] 切换会话，队列长度：\(self.pendingMessages.count)")
        }

        return pendingMessages.count
    }

    func clearCurrentConversationQueue() {
        guard let conversationId = currentConversationId else { return }
        pendingMessagesByConversation[conversationId] = []
        currentProcessingIndexByConversation[conversationId] = nil
        syncCurrentConversationState()

        if Self.verbose {
            AppLogger.core.info("\(Self.t)🗑️ [\(conversationId.uuidString)] 已清空发送队列")
        }
    }

    func getQueueCount(for conversationId: UUID) -> Int {
        pendingMessagesByConversation[conversationId]?.count ?? 0
    }

    // MARK: - 发送

    func sendMessage(
        content: String,
        images: [ImageAttachment] = [],
        onComplete: (() -> Void)? = nil
    ) {
        guard !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return
        }

        guard let conversationId = currentConversationId else {
            AppLogger.core.error("\(Self.t)❌ 当前没有活动对话，请先调用 switchToConversation")
            return
        }

        let userMessage = ChatMessage(role: .user, content: content, images: images)
        let previousQueueCount = pendingMessagesByConversation[conversationId]?.count ?? 0
        pendingMessagesByConversation[conversationId, default: []].append(userMessage)

        // 对于可立即发送的首条消息，提前标记为正在处理，避免 UI 瞬间误显示“等待发送”队列。
        if previousQueueCount == 0, isSendingByConversation[conversationId] != true {
            currentProcessingIndexByConversation[conversationId] = 0
        }

        if currentConversationId == conversationId {
            syncCurrentConversationState()
        }

        if Self.verbose {
            AppLogger.core.info("\(Self.t)📝 [\(conversationId.uuidString.prefix(8))] 消息入队，长度：\(self.pendingMessagesByConversation[conversationId]?.count ?? 0)")
        }

        startOrContinueProcessing(for: conversationId)
        onComplete?()
    }

    private func startOrContinueProcessing(for conversationId: UUID) {
        if isSendingByConversation[conversationId] == true {
            return
        }

        guard let queue = pendingMessagesByConversation[conversationId], !queue.isEmpty else {
            return
        }

        cancelledConversations.remove(conversationId)

        sendTasksByConversation[conversationId]?.cancel()
        sendTasksByConversation[conversationId] = Task.detached(priority: .userInitiated) { [weak self] in
            await self?.processQueue(for: conversationId)
        }
    }

    private func processQueue(for conversationId: UUID) async {
        await MainActor.run {
            self.isSendingByConversation[conversationId] = true
            if self.currentConversationId == conversationId {
                self.syncCurrentConversationState()
            }
            self.eventContinuation?.yield(.processingStarted(conversationId: conversationId))
        }

        while true {
            let shouldStop = await MainActor.run { self.cancelledConversations.contains(conversationId) }
            if shouldStop { break }

            let nextMessage: ChatMessage? = await MainActor.run {
                guard let queue = self.pendingMessagesByConversation[conversationId], !queue.isEmpty else {
                    return nil
                }
                self.currentProcessingIndexByConversation[conversationId] = 0
                if self.currentConversationId == conversationId {
                    self.syncCurrentConversationState()
                }
                return queue.first
            }

            guard let message = nextMessage else { break }

            _ = await MainActor.run {
                self.eventContinuation?.yield(.sendMessage(message, conversationId: conversationId))
            }

            await MainActor.run {
                guard var queue = self.pendingMessagesByConversation[conversationId], !queue.isEmpty else {
                    self.currentProcessingIndexByConversation[conversationId] = nil
                    if self.currentConversationId == conversationId {
                        self.syncCurrentConversationState()
                    }
                    return
                }

                queue.removeFirst()
                self.pendingMessagesByConversation[conversationId] = queue
                self.currentProcessingIndexByConversation[conversationId] = nil

                if self.currentConversationId == conversationId {
                    self.syncCurrentConversationState()
                }
            }
        }

        await MainActor.run {
            self.isSendingByConversation[conversationId] = false
            self.currentProcessingIndexByConversation[conversationId] = nil
            self.sendTasksByConversation[conversationId] = nil
            if self.currentConversationId == conversationId {
                self.syncCurrentConversationState()
            }
            self.eventContinuation?.yield(.processingFinished(conversationId: conversationId))
        }
    }

    func cancelAll() {
        guard let conversationId = currentConversationId else { return }
        cancelProcessing(for: conversationId, clearQueue: true)
    }

    func cancelProcessing(for conversationId: UUID, clearQueue: Bool) {
        cancelledConversations.insert(conversationId)

        if clearQueue {
            pendingMessagesByConversation[conversationId] = []
        }

        currentProcessingIndexByConversation[conversationId] = nil
        isSendingByConversation[conversationId] = false

        sendTasksByConversation[conversationId]?.cancel()
        sendTasksByConversation[conversationId] = nil

        if currentConversationId == conversationId {
            syncCurrentConversationState()
        }
    }

    func clearQueue() {
        guard let conversationId = currentConversationId else { return }

        if currentProcessingIndexByConversation[conversationId] != nil,
           let queue = pendingMessagesByConversation[conversationId],
           queue.count > 1 {
            pendingMessagesByConversation[conversationId] = Array(queue.prefix(1))
        } else {
            pendingMessagesByConversation[conversationId] = []
        }

        syncCurrentConversationState()
    }

    func queueCount() -> Int {
        pendingMessages.count
    }

    func isQueueEmpty() -> Bool {
        pendingMessages.isEmpty
    }

    func removeMessage(at index: Int) {
        guard index != currentProcessingIndex else { return }
        guard let conversationId = currentConversationId else { return }
        guard var queue = pendingMessagesByConversation[conversationId], queue.indices.contains(index) else { return }

        queue.remove(at: index)
        pendingMessagesByConversation[conversationId] = queue

        if let currentIdx = currentProcessingIndexByConversation[conversationId] ?? nil,
           index < currentIdx {
            currentProcessingIndexByConversation[conversationId] = currentIdx - 1
        }

        syncCurrentConversationState()
    }

    func clearAllQueues() {
        for (_, task) in sendTasksByConversation {
            task.cancel()
        }

        pendingMessagesByConversation.removeAll()
        currentProcessingIndexByConversation.removeAll()
        isSendingByConversation.removeAll()
        cancelledConversations.removeAll()
        sendTasksByConversation.removeAll()

        currentProcessingIndex = nil
        isSending = false
        pendingMessages = []
    }

    func removeConversationQueue(_ conversationId: UUID) {
        cancelProcessing(for: conversationId, clearQueue: true)
        pendingMessagesByConversation.removeValue(forKey: conversationId)
        currentProcessingIndexByConversation.removeValue(forKey: conversationId)
        isSendingByConversation.removeValue(forKey: conversationId)
        cancelledConversations.remove(conversationId)

        if currentConversationId == conversationId {
            pendingMessages = []
            currentProcessingIndex = nil
            isSending = false
        }

        if Self.verbose {
            AppLogger.core.info("\(Self.t)🗑️ 已删除会话 [\(conversationId.uuidString.prefix(8))] 的发送队列")
        }
    }

    // MARK: - Private

    private func syncCurrentConversationState() {
        guard let conversationId = currentConversationId else {
            pendingMessages = []
            currentProcessingIndex = nil
            isSending = false
            return
        }

        objectWillChange.send()
        pendingMessages = pendingMessagesByConversation[conversationId] ?? []
        currentProcessingIndex = currentProcessingIndexByConversation[conversationId] ?? nil
        isSending = isSendingByConversation[conversationId] ?? false
    }
}
