import Foundation
import os
import ProviderAgentLoop
import ProviderConversation
import ProviderMessage
import KitSuperLog

/// Message Manager Service
@MainActor
public final class MessageManager: ObservableObject, MessageManaging, SuperLog {
    public nonisolated static let emoji = "💬"
    public nonisolated static let verbose = false
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "message.manager")

    /// 数据存储目录（供未来迁移/设置使用）。
    public let dataDirectory: URL

    private let store: MessageStore?
    private let conversations: (any ConversationManaging)?

    /// 内存中的"已通知 UI、尚未落盘"消息缓冲(write-behind 的脏数据)。
    private nonisolated let pending = PendingMessageBuffer()

    /// 瞬时 status 消息缓冲(每会话最多一条,永不落盘)。
    private nonisolated let statusBuffer = StatusMessageBuffer()

    /// 后台落盘串行队列,保证同一会话内消息落盘顺序与插入顺序一致。
    private nonisolated let persistQueue = DispatchQueue(label: "com.coffic.lumi.message.persist")

    // MARK: - Message Insertion Observers

    private var messageInsertedObservers: [WeakMessageInsertedObserver] = []

    public init(
        store: MessageStore?,
        dataDirectory: URL,
        conversations: (any ConversationManaging)? = nil
    ) {
        self.store = store
        self.dataDirectory = dataDirectory
        self.conversations = conversations
        if Self.verbose {
            Self.logger.info("\(Self.t)MessageManager initialized, store=\(store == nil ? "nil" : "ready")")
        }
    }

    // MARK: - Pending Buffer (write-behind 脏数据,锁保护)

    /// 把一条消息加入待落盘缓冲(去重:同 id 已在则替换,保持时间升序)。
    private func enqueuePending(_ message: Message, conversationID: UUID) {
        pending.enqueue(message, conversationID: conversationID)
    }

    /// 从待落盘缓冲移除一条(后台落盘成功后调用)。nonisolated：锁保护，可在持久化队列直接调用。
    private nonisolated func dequeuePending(id: UUID, conversationID: UUID) {
        pending.dequeue(id: id, conversationID: conversationID)
    }

    /// 合并磁盘页与待落盘消息(read-your-writes),返回按时间升序、去重、限量的结果。
    ///
    /// 策略:把 pending 中属于本会话、满足过滤(同 includesToolMessages)的消息并入磁盘页,
    /// 去重(同 id 取 pending 版本——它更新),整体按 (createdAt, id) 升序排序后取尾部 limit 条。
    ///
    /// **游标分页(`beforeMessageID` 非 nil)不合并 pending**:游标分页是"向上翻历史"场景,
    /// 翻到的都是较早消息,那时尾部的新消息早已落盘、pending 为空,合并无意义反而易错。
    /// pending 只需参与"取最近一页"(无游标)的合并 —— 那正是 UI 实时展示的路径。
    private func mergedPage(
        disk: [Message],
        conversationID: UUID,
        beforeMessageID: UUID?,
        includesToolMessages: Bool,
        limit: Int
    ) -> [Message] {
        guard beforeMessageID == nil else { return disk }

        let pending = pending.snapshot(for: conversationID).filter {
            includesToolMessages || $0.role != .tool
        }
        // status 是"当前进行中"的瞬时态,语义上永远显示在列表最末(最新位置),
        // 不参与 pending 的 createdAt 排序。
        let status = statusBuffer.snapshot(for: conversationID)

        if Self.verbose {
            let statusState = status == nil ? "none" : "present"
            let cursorState = beforeMessageID == nil ? "nil" : "set"
            Self.logger.info("\(Self.t)mergedPage conversation=\(conversationID.uuidString.prefix(8)) disk=\(disk.count) pending=\(pending.count) status=\(statusState) before=\(cursorState)")
        }

        if pending.isEmpty && status == nil { return disk }

        let diskIDs = Set(disk.map(\.id))
        var merged = disk
        for msg in pending where !diskIDs.contains(msg.id) {
            merged.append(msg)
        }
        merged.sort { lhs, rhs in
            if lhs.createdAt == rhs.createdAt { return lhs.id < rhs.id }
            return lhs.createdAt < rhs.createdAt
        }
        // status 追加在最末。
        if let status { merged.append(status) }
        return Array(merged.suffix(limit))
    }

    // MARK: - MessageManaging (reads)

    public func messages(for conversationID: UUID) -> [Message] {
        let diskMessages = store?.fetchMessages(conversationId: conversationID) ?? []
        let pendingMessages = pending.snapshot(for: conversationID)

        // AgentLoop uses this method as the durable source of truth before
        // starting the next LLM iteration. Assistant/tool messages are persisted
        // asynchronously, so reading only from disk can briefly hide a freshly
        // inserted tool result and cause the same tool call to execute again.
        // Merge pending writes here and de-duplicate by message ID so a message
        // is represented exactly once during that window.
        let diskIDs = Set(diskMessages.map(\.id))
        var all = diskMessages
        all.append(contentsOf: pendingMessages.filter { !diskIDs.contains($0.id) })
        all.sort {
            if $0.createdAt == $1.createdAt { return $0.id < $1.id }
            return $0.createdAt < $1.createdAt
        }

        if Self.verbose {
            let status = statusBuffer.snapshot(for: conversationID)
            let statusState = status == nil ? "excluded/none" : "excluded/present"
            Self.logger.info("\(Self.t)messages(for:) conversation=\(conversationID.uuidString.prefix(8)) messages=\(all.count) status=\(statusState)")
        }

        return all
    }

    /// 展示读取路径：在普通消息之外追加当前会话的瞬时 status。
    /// 普通 `messages(for:)` 保持不包含 status，避免污染 AgentLoop 的 LLM 历史。
    public func messagesForDisplay(for conversationID: UUID) -> [Message] {
        var all = messages(for: conversationID)
        let status = statusBuffer.snapshot(for: conversationID)
        if let status {
            all.append(status)
        }
        if Self.verbose {
            let statusState = status == nil ? "none" : "included"
            Self.logger.info("\(Self.t)messagesForDisplay conversation=\(conversationID.uuidString.prefix(8)) messages=\(all.count) status=\(statusState)")
        }
        return all
    }

    public func message(id: UUID, in conversationID: UUID) -> Message? {
        if let pendingMessage = pending.snapshot(for: conversationID).first(where: { $0.id == id }) {
            return pendingMessage
        }
        return store?.fetchMessage(id: id)
    }

    public func lastMessage(in conversationID: UUID) -> Message? {
        messages(for: conversationID).last
    }

    public func messageCount(for conversationID: UUID) -> Int {
        // 与旧版语义一致：只统计磁盘，不合并 pending（pending 是瞬时增量，
        // 计数场景（空对话判定等）以落盘为准）。
        store?.messageCount(conversationId: conversationID) ?? 0
    }

    public func dailyMessageCounts(since: Date) -> [Date: Int] {
        var counts = store?.dailyMessageCounts(since: since) ?? [:]
        let calendar = Calendar.current
        for message in pending.snapshotAll() where message.createdAt >= since {
            counts[calendar.startOfDay(for: message.createdAt), default: 0] += 1
        }
        return counts
    }

    public func dailyTokenCounts(since: Date) -> [Date: Int] {
        var counts = store?.dailyTokenCounts(since: since) ?? [:]
        let calendar = Calendar.current
        for message in pending.snapshotAll() where message.createdAt >= since {
            let tokens = (message.inputTokenCount ?? 0) + (message.outputTokenCount ?? 0)
            guard tokens > 0 else { continue }
            counts[calendar.startOfDay(for: message.createdAt), default: 0] += tokens
        }
        return counts
    }

    /// 分页查询（UI 滚动/历史加载）。
    public func messagePage(
        for conversationID: UUID,
        limit: Int,
        beforeMessageID: UUID?,
        includesToolMessages: Bool = false
    ) -> [Message] {
        guard let store else {
            // store 未就绪:仍尝试返回 pending(read-your-writes,哪怕磁盘不可用)。
            return mergedPage(
                disk: [], conversationID: conversationID,
                beforeMessageID: beforeMessageID,
                includesToolMessages: includesToolMessages, limit: limit
            )
        }
        let disk = store.fetchMessagePage(
            conversationId: conversationID,
            limit: limit,
            beforeMessageID: beforeMessageID,
            includesToolMessages: includesToolMessages
        )
        return mergedPage(
            disk: disk, conversationID: conversationID,
            beforeMessageID: beforeMessageID,
            includesToolMessages: includesToolMessages, limit: limit
        )
    }

    /// 是否有更早消息（UI 顶部"加载更早"按钮显隐）。
    public func hasEarlierMessages(
        for conversationID: UUID,
        beforeMessageID: UUID?,
        includesToolMessages: Bool = false
    ) -> Bool {
        store?.hasEarlierMessages(
            conversationId: conversationID,
            beforeMessageID: beforeMessageID,
            includesToolMessages: includesToolMessages
        ) ?? false
    }

    // MARK: - MessageManaging (writes)

    public func insertMessage(_ message: Message, to conversationID: UUID) {
        if Self.verbose {
            Self.logger.info("\(Self.t)insertMessage called ➡️ messageConversation=\(message.conversationID.uuidString.prefix(8)) targetConversation=\(conversationID.uuidString.prefix(8)) role=\(message.role.rawValue) contentChars=\(message.content.count) toolCalls=\(message.toolCalls?.count ?? 0)")
        }

        // Ensure message has the correct conversationID
        var messageToInsert = message
        if messageToInsert.conversationID != conversationID {
            if Self.verbose {
                Self.logger.info("\(Self.t)conversationID mismatch, creating new message with target ID")
            }
            messageToInsert = Message(
                id: messageToInsert.id,
                conversationID: conversationID,
                role: messageToInsert.role,
                content: messageToInsert.content,
                createdAt: messageToInsert.createdAt,
                turnID: messageToInsert.turnID,
                metadata: messageToInsert.metadata,
                isError: messageToInsert.isError,
                providerID: messageToInsert.providerID,
                modelName: messageToInsert.modelName,
                rawErrorDetail: messageToInsert.rawErrorDetail,
                httpStatusCode: messageToInsert.httpStatusCode,
                httpBody: messageToInsert.httpBody,
                renderKind: messageToInsert.renderKind,
                preferredRendererID: messageToInsert.preferredRendererID,
                toolCallID: messageToInsert.toolCallID,
                reasoningContent: messageToInsert.reasoningContent,
                toolCalls: messageToInsert.toolCalls,
                inputTokenCount: messageToInsert.inputTokenCount,
                outputTokenCount: messageToInsert.outputTokenCount,
                latencyMs: messageToInsert.latencyMs,
                timeToFirstTokenMs: messageToInsert.timeToFirstTokenMs,
                streamingDurationMs: messageToInsert.streamingDurationMs
            )
        }

        // status 消息:纯内存瞬时态,不落盘。每会话最多一条(insert 即替换)。
        if messageToInsert.role == .status || messageToInsert.metadata["isTransientStatus"] == "true" {
            let previous = statusBuffer.snapshot(for: conversationID)
            statusBuffer.set(messageToInsert, conversationID: conversationID)
            if Self.verbose {
                let content = messageToInsert.content.replacingOccurrences(of: "\n", with: "\\n")
                let replacedID = previous.map { String($0.id.uuidString.prefix(8)) } ?? "none"
                Self.logger.info("\(Self.t)status buffered conversation=\(conversationID.uuidString.prefix(8)) id=\(messageToInsert.id.uuidString.prefix(8)) content=\(content) replaced=\(replacedID) persisted=false")
            }
            notifyMessagesDidChange(conversationID: conversationID)
            return
        }

        // 0) 非瞬时消息:刷新会话最后消息时间,让「最近有消息的对话」在列表中置顶。
        conversations?.markConversationActive(id: conversationID, messageDate: messageToInsert.createdAt)

        // 1) 写入内存缓冲,立即通知 UI —— UI 这一刻就能从读路径看到它(read-your-writes)。
        enqueuePending(messageToInsert, conversationID: conversationID)
        notifyMessagesDidChange(conversationID: conversationID)
        notifyMessageInsertedObservers(messageToInsert, conversationID: conversationID)

        // 2) 按 role 分流落盘:
        //    - user / error:立即同步落盘(用户输入与错误不可丢);
        //    - assistant / tool:后台串行落盘(丢了可重发/重算,且不阻塞 UI)。
        let shouldPersistEagerly = messageToInsert.role == .user
            || messageToInsert.role == .error
        if shouldPersistEagerly {
            persistNow(messageToInsert, conversationID: conversationID)
        } else {
            persistLater(messageToInsert, conversationID: conversationID)
        }
    }

    /// 同步落盘 + 从缓冲移除。
    private func persistNow(_ message: Message, conversationID: UUID) {
        do {
            try store?.insertMessage(message)
            dequeuePending(id: message.id, conversationID: conversationID)
            if message.role == .user {
                postMessageSavedNotification(message: message, conversationID: conversationID)
            }
        } catch {
            if Self.verbose {
                Self.logger.error("\(Self.t)Failed to persist message eagerly: \(error)")
            }
        }
    }

    /// 后台串行落盘 + 从缓冲移除(成功后)。失败则保留在缓冲,下次启动可补救。
    private func persistLater(_ message: Message, conversationID: UUID) {
        let store = self.store
        persistQueue.async { [weak self] in
            guard let store else { return }
            do {
                try store.insertMessage(message)
                // dequeuePending 是 nonisolated + 锁保护,可在本队列直接调用。
                self?.dequeuePending(id: message.id, conversationID: conversationID)
            } catch {
                if Self.verbose {
                    Self.logger.error("\(Self.t)Failed to persist message in background: \(error)")
                }
            }
        }
    }

    private func postMessageSavedNotification(message: Message, conversationID: UUID) {
        let userInfo: [AnyHashable: Any] = [
            "conversationID": conversationID,
            "messageID": message.id,
            "role": message.role.rawValue,
        ]
        NotificationCenter.default.post(
            name: Notification.Name("com.coffic.lumi.messageSaved"),
            object: nil,
            userInfo: userInfo
        )
    }

    public func updateMessage(id: UUID, in conversationID: UUID, content: String) {
        if Self.verbose {
            Self.logger.info("\(Self.t)updateMessage ➡️ conversation=\(conversationID.uuidString.prefix(8))…, message=\(id.uuidString.prefix(8))…, newContentChars=\(content.count)")
        }
        let pendingMessage = pending.update(id: id, conversationID: conversationID) { message in
            message.content = content
        }
        if let pendingMessage {
            // Keep the update ordered after the original write-behind insert.
            persistUpdatedMessage(pendingMessage, conversationID: conversationID)
        } else {
            _ = store?.updateMessage(id: id, content: content)
        }
        notifyMessagesDidChange(conversationID: conversationID)
    }

    public func deleteMessage(id: UUID, in conversationID: UUID) {
        if Self.verbose {
            Self.logger.info("\(Self.t)deleteMessage ➡️ conversation=\(conversationID.uuidString.prefix(8))…, message=\(id.uuidString.prefix(8))…")
        }
        pending.dequeue(id: id, conversationID: conversationID)
        _ = store?.deleteMessage(id: id)
        notifyMessagesDidChange(conversationID: conversationID)
    }

    public func clearMessages(in conversationID: UUID) {
        if Self.verbose {
            Self.logger.info("\(Self.t)clearMessages ➡️ conversation=\(conversationID.uuidString.prefix(8))…")
        }
        // Drain the write-behind queue before deleting. Otherwise an older
        // assistant/tool write could land after the delete and resurrect data.
        persistQueue.sync {
            _ = store?.deleteAllMessages(conversationId: conversationID)
            pending.clear(conversationID: conversationID)
        }
        _ = statusBuffer.clear(conversationID: conversationID)
        notifyMessagesDidChange(conversationID: conversationID)
    }

    public func clearStatusMessages(in conversationID: UUID) {
        let previous = statusBuffer.snapshot(for: conversationID)
        guard statusBuffer.clear(conversationID: conversationID) else {
            if Self.verbose {
                Self.logger.info("\(Self.t)clearStatusMessages conversation=\(conversationID.uuidString.prefix(8)) status=none")
            }
            return
        }
        if Self.verbose {
            let statusID = previous.map { String($0.id.uuidString.prefix(8)) } ?? "unknown"
            Self.logger.info("\(Self.t)clearStatusMessages conversation=\(conversationID.uuidString.prefix(8)) id=\(statusID) cleared=true")
        }
        notifyMessagesDidChange(conversationID: conversationID)
    }

    // MARK: - Tool Call Result Update

    public func updateToolCallResult(
        _ result: MessageToolResult,
        toolCallID: String,
        assistantMessageID: UUID,
        in conversationID: UUID
    ) {
        if Self.verbose {
            Self.logger.info("\(Self.t)updateToolCallResult begin conversation=\(conversationID.uuidString.prefix(8))…, message=\(assistantMessageID.uuidString.prefix(8))…, toolCall=\(toolCallID), contentChars=\(result.content.count), isError=\(result.isError)")
        }
        let updatedMessage = pending.snapshot(for: conversationID)
            .first(where: { $0.id == assistantMessageID })
            ?? store?.fetchMessage(id: assistantMessageID)
        guard var message = updatedMessage,
              var toolCalls = message.toolCalls,
              let index = toolCalls.firstIndex(where: { $0.id == toolCallID })
        else {
            if Self.verbose {
                let snapshot = pending.snapshot(for: conversationID)
                let stored = store?.fetchMessage(id: assistantMessageID)
                Self.logger.warning("\(Self.t)updateToolCallResult miss toolCall=\(toolCallID), pendingCount=\(snapshot.count), pendingHasMessage=\(snapshot.contains(where: { $0.id == assistantMessageID })), storedHasMessage=\(stored != nil), storedToolCalls=\(stored?.toolCalls?.map(\.id) ?? [])")
            }
            return
        }

        toolCalls[index].result = result
        message.toolCalls = toolCalls
        if pending.update(id: assistantMessageID, conversationID: conversationID) { pendingMessage in
            pendingMessage.toolCalls = toolCalls
        } != nil {
            persistUpdatedToolCalls(toolCalls, messageID: assistantMessageID)
        } else {
            _ = store?.updateToolCalls(id: assistantMessageID, toolCalls: toolCalls)
        }

        if Self.verbose {
            Self.logger.info("\(Self.t)updateToolCallResult ➡️ conversation=\(conversationID.uuidString.prefix(8))…, message=\(assistantMessageID.uuidString.prefix(8))…, toolCall=\(toolCallID)")
        }

        notifyMessagesDidChange(conversationID: conversationID)
    }

    private func persistUpdatedMessage(
        _ message: Message,
        conversationID: UUID
    ) {
        let store = self.store
        persistQueue.async {
            _ = store?.updateMessage(id: message.id, content: message.content)
            self.dequeuePending(id: message.id, conversationID: conversationID)
        }
    }

    private func persistUpdatedToolCalls(
        _ toolCalls: [MessageToolCall],
        messageID: UUID
    ) {
        let store = self.store
        persistQueue.async {
            _ = store?.updateToolCalls(id: messageID, toolCalls: toolCalls)
        }
    }

    // MARK: - Notification

    /// 通知订阅方消息已变化（`MessageManaging.objectWillChange`，消费方 PluginMessageList
    /// 等窄播订阅）。对齐旧版 `eventManager.postMessagesDidChange` 的语义。
    private func notifyMessagesDidChange(conversationID: UUID) {
        objectWillChange.send()
    }

    // MARK: - Message Insertion Observation

    @discardableResult
    public func addMessageInsertedObserver(
        _ callback: @escaping (Message, UUID) -> Void
    ) -> any MessageInsertedObserverHandle {
        let handle = MessageInsertedObserverHandleImpl(owner: self, callback: callback)
        self.messageInsertedObservers.append(WeakMessageInsertedObserver(handle))
        if Self.verbose {
            Self.logger.info("\(self.t)message inserted observer added, total=\(self.messageInsertedObservers.count)")
        }
        return handle
    }

    fileprivate func removeMessageInsertedObserver(_ handle: MessageInsertedObserverHandleImpl) {
        self.messageInsertedObservers.removeAll { $0.handle === handle }
        if Self.verbose {
            Self.logger.info("\(self.t)message inserted observer removed, remaining=\(self.messageInsertedObservers.count)")
        }
    }

    private func notifyMessageInsertedObservers(_ message: Message, conversationID: UUID) {
        messageInsertedObservers.removeAll { $0.handle == nil }
        let observers = messageInsertedObservers
        for observer in observers {
            observer.handle?.invoke(message, conversationID)
        }
    }
}

// MARK: - Message Inserted Observer Handle

@MainActor
private final class MessageInsertedObserverHandleImpl: MessageInsertedObserverHandle {
    private weak var owner: MessageManager?
    private let callback: (Message, UUID) -> Void
    private var isCancelled = false

    init(owner: MessageManager, callback: @escaping (Message, UUID) -> Void) {
        self.owner = owner
        self.callback = callback
    }

    func cancel() {
        guard !isCancelled else { return }
        isCancelled = true
        owner?.removeMessageInsertedObserver(self)
    }

    fileprivate func invoke(_ message: Message, _ conversationID: UUID) {
        guard !isCancelled else { return }
        callback(message, conversationID)
    }
}

@MainActor
private final class WeakMessageInsertedObserver {
    fileprivate weak var handle: MessageInsertedObserverHandleImpl?
    init(_ handle: MessageInsertedObserverHandleImpl) { self.handle = handle }
}
