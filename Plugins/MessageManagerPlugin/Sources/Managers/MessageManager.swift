import Foundation
import LumiKernel
import os
import SuperLogKit

/// Message Manager Service
///
/// 读路径(messages/messagePage/messageCount 等)标 `nonisolated`,不触碰可变状态、
/// 不发通知,可在后台线程执行数据库读取与解码,避免阻塞主线程。
/// 写路径(insert/update/delete 等)标 `@MainActor`,因为它们通过 `EventManager`
/// 发 `messagesDidChange` 通知刷新 UI,必须在主线程执行。
///
/// **Write-behind + read-your-writes(参考 ChatGPT 策略)**:
/// `insertMessage` 把消息先写入内存 `pendingMessages` 并立即通知 UI —— UI 这一刻
/// 就能从读路径看到它,不等落盘。落盘按 role 分流:
/// - user / error:立即同步落盘(用户输入不可丢);
/// - assistant / tool:后台串行落盘(丢了可重发/重算,不阻塞 UI)。
/// 读路径会合并磁盘结果与 `pendingMessages`(read-your-writes),所以即便某条
/// assistant 消息还没落盘,UI 也照常显示。详见 `insertMessage`。
public final class MessageManager: ObservableObject, MessageManaging, SuperLog, @unchecked Sendable {
    public nonisolated static let emoji = "💬"
    public nonisolated(unsafe) static var verbose = false
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "message.manager")

    private weak var kernel: LumiKernel?

    /// 内存中的"已通知 UI、尚未落盘"消息缓冲(write-behind 的脏数据)。
    ///
    /// 读路径(nonisolated,可在后台线程)与写路径(@MainActor)都会访问它,故内部用锁
    /// 保护并暴露为 Sendable。key=conversationID,value=该会话待落盘消息(按时间升序)。
    /// 一条消息后台落盘成功后从这里移除;UI 早已显示它,移除是隐形的,无需再通知。
    private nonisolated let pending = PendingMessageBuffer()

    /// 瞬时 status 消息缓冲(每会话最多一条,永不落盘)。
    ///
    /// `role == .status` 的消息(如"正在发送…")是视图层瞬时态,不进磁盘:
    /// insert 时只入此缓冲;同会话一旦 insert 任何**非 status**消息(回合推进的标志),
    /// 本缓冲里该会话的 status 立即被清除(manager 自动清理,调用方无需关心)。
    private nonisolated let statusBuffer = StatusMessageBuffer()

    /// 后台落盘串行队列,保证同一会话内消息落盘顺序与插入顺序一致。
    private nonisolated let persistQueue = DispatchQueue(label: "com.coffic.lumi.message.persist")

    public init(kernel: LumiKernel) {
        self.kernel = kernel
        if Self.verbose {
            Self.logger.info("\(Self.t)MessageManager initialized")
        }
    }

    // MARK: - Store Access

    /// `nonisolated`:MessageStoreRuntimeBridge 自身用锁保护并发访问,
    /// 故读取 store 可在任意线程(含后台)进行。
    private nonisolated var store: MessageStore? {
        MessageStoreRuntimeBridge.shared.store
    }

    // MARK: - Pending Buffer (write-behind 脏数据,锁保护)

    /// 取某会话的待落盘消息快照(按时间升序)。
    private nonisolated func pendingSnapshot(for conversationID: UUID) -> [LumiChatMessage] {
        pending.snapshot(for: conversationID)
    }

    /// 把一条消息加入待落盘缓冲(去重:同 id 已在则替换,保持时间升序)。
    @MainActor
    private func enqueuePending(_ message: LumiChatMessage, conversationID: UUID) {
        pending.enqueue(message, conversationID: conversationID)
    }

    /// 从待落盘缓冲移除一条(后台落盘成功后调用)。
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
    private nonisolated func mergedPage(
        disk: [LumiChatMessage],
        conversationID: UUID,
        beforeMessageID: UUID?,
        includesToolMessages: Bool,
        limit: Int
    ) -> [LumiChatMessage] {
        guard beforeMessageID == nil else { return disk }

        let pending = pendingSnapshot(for: conversationID).filter {
            includesToolMessages || $0.role != .tool
        }
        // status 是"当前进行中"的瞬时态,语义上永远显示在列表最末(最新位置),
        // 不参与 pending 的 createdAt 排序。
        let status = statusBuffer.snapshot(for: conversationID)

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

    // MARK: - MessageManaging (reads — nonisolated, safe to run off-main)

    public nonisolated func messages(for conversationID: UUID) -> [LumiChatMessage] {
        let all = store?.fetchMessages(conversationId: conversationID) ?? []

        if Self.verbose {
            Self.logger.info("\(Self.t)messages(for:) conversation=\(conversationID.uuidString.prefix(8)) messages=\(all.count)")
        }

        return all
    }

    public nonisolated func messagePage(
        for conversationID: UUID,
        limit: Int,
        beforeMessageID: UUID?,
        includesToolMessages: Bool = false
    ) -> [LumiChatMessage] {
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

    public nonisolated func messageCount(for conversationID: UUID) -> Int {
        store?.messageCount(conversationId: conversationID) ?? 0
    }

    public nonisolated func conversationIDsHavingMessages() -> Set<UUID> {
        guard let store else { return [] }
        return Set(store.conversationIDsHavingMessages().compactMap { UUID(uuidString: $0) })
    }

    public nonisolated func hasEarlierMessages(
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

    @MainActor
    public func deleteMessage(id: UUID, in conversationID: UUID) {
        if Self.verbose {
            Self.logger.info("\(Self.t)deleteMessage ➡️ conversation=\(conversationID.uuidString.prefix(8))…, message=\(id.uuidString.prefix(8))…")
        }
        store?.deleteMessage(id: id)
        // Notify observers that messages changed
        kernel?.eventManager.postMessagesDidChange(object: self, conversationID: conversationID)
    }

    @MainActor
    public func insertMessage(_ message: LumiChatMessage, to conversationID: UUID) {
        if Self.verbose {
            Self.logger.info("\(Self.t)insertMessage called ➡️ messageConversation=\(message.conversationID.uuidString.prefix(8)) targetConversation=\(conversationID.uuidString.prefix(8)) role=\(message.role.rawValue) contentChars=\(message.content.count) metadataChars=\(Self.metadataCharacterCount(message.metadata)) reasoningChars=\(message.reasoningContent?.count ?? 0) toolCalls=\(message.toolCalls?.count ?? 0)")
        }

        // Ensure message has the correct conversationID
        var messageToInsert = message
        if messageToInsert.conversationID != conversationID {
            if Self.verbose {
                Self.logger.info("\(Self.t)conversationID mismatch, creating new message with target ID")
            }
            messageToInsert = LumiChatMessage(
                id: messageToInsert.id,
                conversationID: conversationID,
                role: messageToInsert.role,
                content: messageToInsert.content,
                createdAt: messageToInsert.createdAt,
                providerID: messageToInsert.providerID,
                modelName: messageToInsert.modelName,
                isError: messageToInsert.isError,
                rawErrorDetail: messageToInsert.rawErrorDetail,
                renderKind: messageToInsert.renderKind,
                metadata: messageToInsert.metadata,
                toolCalls: messageToInsert.toolCalls,
                toolCallID: messageToInsert.toolCallID,
                reasoningContent: messageToInsert.reasoningContent,
                inputTokenCount: messageToInsert.inputTokenCount,
                outputTokenCount: messageToInsert.outputTokenCount,
                latencyMs: messageToInsert.latencyMs,
                timeToFirstTokenMs: messageToInsert.timeToFirstTokenMs,
                streamingDurationMs: messageToInsert.streamingDurationMs
            )
        }

        // status 消息:纯内存瞬时态,不落盘。每会话最多一条(insert 即替换)。
        // 见 StatusMessageBuffer。回合产物(assistant/error)insert 时由下方自动清理移除。
        if messageToInsert.role == .status {
            statusBuffer.set(messageToInsert, conversationID: conversationID)
            kernel?.eventManager.postMessagesDidChange(object: self, conversationID: conversationID)
            return
        }

        // 回合产物(assistant/tool/error)到来 = 当前阶段结束,自动清除该会话的瞬时 status。
        // 注意:user 消息不清 status —— user 是发送发起点(与 status 同属一轮),
        // 清掉会让"正在发送…"瞬间消失。assistant(模型回复)/tool(工具结果)/error
        // 都是阶段产物:它们落库意味着对应阶段(生成/工具执行/出错)结束,status 退场。
        if messageToInsert.role == .assistant
            || messageToInsert.role == .tool
            || messageToInsert.role == .error {
            statusBuffer.clear(conversationID: conversationID)
        }

        // 1) 写入内存缓冲,立即通知 UI —— UI 这一刻就能从读路径看到它(read-your-writes)。
        enqueuePending(messageToInsert, conversationID: conversationID)
        kernel?.eventManager.postMessagesDidChange(object: self, conversationID: conversationID)

        // 2) 按 role 分流落盘:
        //    - user / error:立即同步落盘(用户输入与错误不可丢);
        //    - assistant / tool:后台串行落盘(丢了可重发/重算,且不阻塞 UI)。
        // status 不会走到这里(上方已 return)。
        let shouldPersistEagerly = messageToInsert.role == .user
            || messageToInsert.role == .error
        if shouldPersistEagerly {
            persistNow(messageToInsert, conversationID: conversationID)
        } else {
            persistLater(messageToInsert, conversationID: conversationID)
        }
    }

    /// 同步落盘 + 从缓冲移除。
    @MainActor
    private func persistNow(_ message: LumiChatMessage, conversationID: UUID) {
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
    private nonisolated func persistLater(_ message: LumiChatMessage, conversationID: UUID) {
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

    @MainActor
    private func postMessageSavedNotification(message: LumiChatMessage, conversationID: UUID) {
        let userInfo: [AnyHashable: Any] = [
            LumiMessageSavedNotification.conversationIDKey: conversationID,
            LumiMessageSavedNotification.messageIDKey: message.id,
            LumiMessageSavedNotification.roleKey: message.role.rawValue,
        ]
        NotificationCenter.default.post(
            name: .lumiMessageSaved,
            object: nil,
            userInfo: userInfo
        )
    }

    @MainActor
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
            store?.updateMessage(id: id, content: content)
        }
        // Notify UI to refresh
        kernel?.eventManager.postMessagesDidChange(object: self, conversationID: conversationID)
    }

    @MainActor
    public func clearMessages(in conversationID: UUID) {
        if Self.verbose {
            Self.logger.info("\(Self.t)clearMessages ➡️ conversation=\(conversationID.uuidString.prefix(8))…")
        }
        store?.deleteAllMessages(conversationId: conversationID)
        statusBuffer.clear(conversationID: conversationID)
        kernel?.eventManager.postMessagesDidChange(object: self, conversationID: conversationID)
    }

    @MainActor
    public func clearStatusMessage(in conversationID: UUID) {
        guard statusBuffer.clear(conversationID: conversationID) else { return }
        kernel?.eventManager.postMessagesDidChange(object: self, conversationID: conversationID)
    }

    // MARK: - Message Query

    public nonisolated func message(id: UUID, in conversationID: UUID) -> LumiChatMessage? {
        store?.fetchMessage(id: id)
    }

    public nonisolated func lastMessage(in conversationID: UUID) -> LumiChatMessage? {
        store?.fetchMessages(conversationId: conversationID).last
    }

    public nonisolated func fetchDailyMessageCounts(since: Date) -> [Date: Int] {
        store?.fetchDailyMessageCounts(since: since) ?? [:]
    }

    public nonisolated func fetchDailyTokenCounts(since: Date) -> [Date: Int] {
        store?.fetchDailyTokenCounts(since: since) ?? [:]
    }

    public nonisolated func fetchTokenUsage(on day: Date, providerID: String?, modelName: String?) -> MessageTokenUsage {
        guard let store else {
            return MessageTokenUsage(day: Calendar.current.startOfDay(for: day), inputTokens: 0, outputTokens: 0)
        }
        return store.fetchTokenUsage(on: day, providerID: providerID, modelName: modelName)
    }

    // MARK: - Tool Call Result Update

    @MainActor
    public func updateToolCallResult(
        _ result: LumiToolResult,
        toolCallID: String,
        assistantMessageID: UUID,
        in conversationID: UUID
    ) {
        let updatedMessage = pending.snapshot(for: conversationID)
            .first(where: { $0.id == assistantMessageID })
            ?? store?.fetchMessage(id: assistantMessageID)
        guard var message = updatedMessage,
              var toolCalls = message.toolCalls,
              let index = toolCalls.firstIndex(where: { $0.id == toolCallID })
        else {
            if Self.verbose {
                Self.logger.warning("\(Self.t)updateToolCallResult: tool call \(toolCallID) not found")
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
            store?.updateToolCalls(id: assistantMessageID, toolCalls: toolCalls)
        }

        if Self.verbose {
            Self.logger.info("\(Self.t)updateToolCallResult ➡️ conversation=\(conversationID.uuidString.prefix(8))…, message=\(assistantMessageID.uuidString.prefix(8))…, toolCall=\(toolCallID)")
        }

        // Notify UI to refresh
        kernel?.eventManager.postMessagesDidChange(object: self, conversationID: conversationID)
    }

    private nonisolated func persistUpdatedMessage(
        _ message: LumiChatMessage,
        conversationID: UUID
    ) {
        let store = self.store
        persistQueue.async {
            _ = store?.updateMessage(id: message.id, content: message.content)
            self.dequeuePending(id: message.id, conversationID: conversationID)
        }
    }

    private nonisolated func persistUpdatedToolCalls(
        _ toolCalls: [LumiToolCall],
        messageID: UUID
    ) {
        let store = self.store
        persistQueue.async {
            _ = store?.updateToolCalls(id: messageID, toolCalls: toolCalls)
        }
    }
}

private extension MessageManager {
    static func messageMetrics(_ messages: [LumiChatMessage]) -> (
        contentChars: Int,
        metadataChars: Int,
        reasoningChars: Int,
        toolCallArgumentChars: Int
    ) {
        var contentChars = 0
        var metadataChars = 0
        var reasoningChars = 0
        var toolCallArgumentChars = 0

        for message in messages {
            contentChars += message.content.count
            metadataChars += metadataCharacterCount(message.metadata)
            reasoningChars += message.reasoningContent?.count ?? 0
            toolCallArgumentChars += message.toolCalls?.reduce(0) { $0 + $1.arguments.count } ?? 0
        }

        return (contentChars, metadataChars, reasoningChars, toolCallArgumentChars)
    }

    static func metadataCharacterCount(_ metadata: [String: String]) -> Int {
        metadata.reduce(0) { $0 + $1.key.count + $1.value.count }
    }
}
