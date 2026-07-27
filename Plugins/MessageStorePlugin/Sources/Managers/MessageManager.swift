import Foundation
import LumiKernel
import os
import SuperLogKit

/// Message Manager Service
///
/// Implements MessageManaging protocol with SwiftData persistence.
@MainActor
public final class MessageManager: ObservableObject, MessageManaging, SuperLog {
    public nonisolated static let emoji = "💬"
    public nonisolated(unsafe) static var verbose = false
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "message.manager")

    private weak var kernel: LumiKernel?

    /// In-memory cache of messages per conversation
    private var messageCache: [UUID: [LumiChatMessage]] = [:]

    public init(kernel: LumiKernel) {
        self.kernel = kernel
        if Self.verbose {
            Self.logger.info("\(Self.t)MessageManager initialized")
        }
    }

    // MARK: - Store Access

    private var store: MessageStore? {
        MessageStoreRuntimeBridge.shared.store
    }

    // MARK: - Load

    /// Load messages for a conversation from store
    public func loadMessages(for conversationID: UUID) {
        guard let store else {
            Self.logger.error("\(Self.t)Store not available")
            return
        }

        if Self.verbose {
            Self.logger.info("\(Self.t)loadMessages(for:) ➡️ conversation=\(conversationID.uuidString.prefix(8))…, cacheBefore=\(self.messageCache[conversationID]?.count ?? 0)")
        }

        Task {
            let loaded = await store.fetchMessages(conversationId: conversationID)
            await MainActor.run {
                self.messageCache[conversationID] = loaded
                if Self.verbose {
                    let metrics = Self.messageMetrics(loaded)
                    Self.logger.info("\(Self.t)loadMessages(for:) 完成 ➡️ conversation=\(conversationID.uuidString.prefix(8))…, messages=\(loaded.count), first=\(loaded.first?.id.uuidString.prefix(8) ?? "nil"), last=\(loaded.last?.id.uuidString.prefix(8) ?? "nil"), contentChars=\(metrics.contentChars) metadataChars=\(metrics.metadataChars) reasoningChars=\(metrics.reasoningChars) toolCallArgumentChars=\(metrics.toolCallArgumentChars)")
                }
                // Notify UI to refresh
                self.kernel?.eventManager.postMessagesDidChange(object: self)
            }
        }
    }

    // MARK: - MessageManaging

    public func messages(for conversationID: UUID) -> [LumiChatMessage] {
        // If cache doesn't exist for this conversation, trigger async load
        if messageCache[conversationID] == nil {
            if Self.verbose {
                Self.logger.info("\(Self.t)Full-history cache miss conversation=\(conversationID.uuidString.prefix(8)), loading from database async")
            }
            // Start async load - UI will be updated via notification
            loadMessages(for: conversationID)
        }
        let cached = messageCache[conversationID] ?? []

        if Self.verbose {
            let metrics = Self.messageMetrics(cached)
            Self.logger.info("\(Self.t)messages(for:) conversation=\(conversationID.uuidString.prefix(8)) cachedMessages=\(cached.count) cacheConversations=\(self.messageCache.keys.count) contentChars=\(metrics.contentChars) metadataChars=\(metrics.metadataChars) reasoningChars=\(metrics.reasoningChars)")
        }

        return cached
    }

    public func displayMessages(for conversationID: UUID) -> [LumiChatMessage] {
        let all = messages(for: conversationID)
        // 低于「详细」(V3) 级别时,隐藏工具调用结果消息（role == .tool）,
        // 让上层 UI 无需自行判断详细程度。
        let verbosity = kernel?.conversations?.verbosity(for: conversationID) ?? .defaultVerbosity
        guard verbosity == .detailed else {
            return all.filter { $0.role != .tool }
        }
        return all
    }

    public func visibleMessages(for conversationID: UUID, limit: Int, beforeMessageID: UUID?) async -> [LumiChatMessage] {
        guard let store else { return [] }

        if Self.verbose {
            Self.logger.info("\(Self.t)visibleMessages 开始 ➡️ conversation=\(conversationID.uuidString.prefix(8))…, limit=\(limit), before=\(beforeMessageID?.uuidString.prefix(8) ?? "nil")")
        }

        let page = await store.fetchMessagePage(
            conversationId: conversationID,
            limit: limit,
            beforeMessageID: beforeMessageID
        )

        let verbosity = kernel?.conversations?.verbosity(for: conversationID) ?? .defaultVerbosity
        let filtered = page.filter {
            if verbosity == .detailed {
                return $0.role != .status || $0.renderKind == "turn-completed"
            }
            return $0.role != .tool && ($0.role != .status || $0.renderKind == "turn-completed")
        }

        if Self.verbose {
            Self.logger.info("\(Self.t)visibleMessages 完成 ➡️ conversation=\(conversationID.uuidString.prefix(8))…, raw=\(page.count), filtered=\(filtered.count), first=\(filtered.first?.id.uuidString.prefix(8) ?? "nil"), last=\(filtered.last?.id.uuidString.prefix(8) ?? "nil"), roles=\(filtered.map { $0.role.rawValue }.joined(separator: ",")), verbosity=\(verbosity.rawValue)")
        }

        return filtered
    }

    public func messageCount(for conversationID: UUID) async -> Int {
        if let cached = messageCache[conversationID] {
            if Self.verbose {
                Self.logger.info("\(Self.t)messageCount cache-hit conversation=\(conversationID.uuidString.prefix(8)) count=\(cached.count)")
            }
            return cached.count
        }
        guard let store else { return 0 }
        let count = await store.messageCount(conversationId: conversationID)
        if Self.verbose {
            Self.logger.info("\(Self.t)messageCount store-count conversation=\(conversationID.uuidString.prefix(8)) count=\(count) fullHistoryLoaded=false")
        }
        return count
    }

    public func hasEarlierMessages(for conversationID: UUID, beforeMessageID: UUID?) async -> Bool {
        guard let store else { return false }
        return await store.hasEarlierMessages(conversationId: conversationID, beforeMessageID: beforeMessageID)
    }

    public nonisolated func messagesAsync(for conversationID: UUID) async -> [LumiChatMessage] {
        await store?.fetchMessages(conversationId: conversationID) ?? []
    }

    public func deleteMessage(id: UUID, in conversationID: UUID) {
        // Remove from cache
        if Self.verbose {
            Self.logger.info("\(Self.t)deleteMessage ➡️ conversation=\(conversationID.uuidString.prefix(8))…, message=\(id.uuidString.prefix(8))…, cacheBefore=\(self.messageCache[conversationID]?.count ?? 0)")
        }
        messageCache[conversationID]?.removeAll { $0.id == id }

        // Notify observers that messages changed
        kernel?.eventManager.postMessagesDidChange(object: self)

        // Delete from store async
        Task {
            await store?.deleteMessage(id: id)
        }
    }

    public func insertMessage(_ message: LumiChatMessage, to conversationID: UUID) {
        if Self.verbose {
            Self.logger.info("\(Self.t)insertMessage called ➡️ messageConversation=\(message.conversationID.uuidString.prefix(8)) targetConversation=\(conversationID.uuidString.prefix(8)) role=\(message.role.rawValue) contentChars=\(message.content.count) metadataChars=\(Self.metadataCharacterCount(message.metadata)) reasoningChars=\(message.reasoningContent?.count ?? 0) toolCalls=\(message.toolCalls?.count ?? 0) cacheBefore=\(self.messageCache[conversationID]?.count ?? 0)")
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

        // Add to cache immediately
        if messageCache[conversationID] == nil {
            messageCache[conversationID] = []
            if Self.verbose {
                Self.logger.info("\(Self.t)Created new cache array conversation=\(conversationID.uuidString.prefix(8))")
            }
        }
        messageCache[conversationID]?.append(messageToInsert)

        let totalCount = self.messageCache[conversationID]?.count ?? 0
        if Self.verbose {
            Self.logger.info("\(Self.t)Inserted message to cache ➡️ message=\(messageToInsert.id.uuidString.prefix(8)) conversation=\(conversationID.uuidString.prefix(8)) cachedMessages=\(totalCount) cacheConversations=\(self.messageCache.keys.count)")
        }

        // Notify observers that messages changed
        if Self.verbose {
            Self.logger.info("\(Self.t)准备发布 messagesDidChange ➡️ conversation=\(conversationID.uuidString.prefix(8))…, message=\(messageToInsert.id.uuidString.prefix(8))…, cacheContainsMessage=\(self.messageCache[conversationID]?.contains(where: { $0.id == messageToInsert.id }) ?? false)")
        }
        kernel?.eventManager.postMessagesDidChange(object: self)

        // Persist to store async
        Task {
            do {
                if Self.verbose {
                    Self.logger.info("\(Self.t)开始异步写入 store ➡️ conversation=\(conversationID.uuidString.prefix(8))…, message=\(messageToInsert.id.uuidString.prefix(8))…")
                }
                try await store?.insertMessage(messageToInsert)
                if Self.verbose {
                    Self.logger.info("\(Self.t)异步写入 store 完成 ➡️ conversation=\(conversationID.uuidString.prefix(8))…, message=\(messageToInsert.id.uuidString.prefix(8))…")
                }
            } catch {
                if Self.verbose {
                    Self.logger.error("\(Self.t)Failed to persist message: \(error)")
                }
            }
        }
    }

    public func updateMessage(id: UUID, in conversationID: UUID, content: String) {
        // Update in cache
        guard let index = messageCache[conversationID]?.firstIndex(where: { $0.id == id }) else {
            if Self.verbose {
                Self.logger.warning("\(Self.t)updateMessage: message \(id) not found")
            }
            return
        }

        let old = messageCache[conversationID]![index]
        messageCache[conversationID]![index] = LumiChatMessage(
            id: old.id,
            conversationID: old.conversationID,
            role: old.role,
            content: content,
            createdAt: old.createdAt,
            providerID: old.providerID,
            modelName: old.modelName,
            isError: old.isError,
            rawErrorDetail: old.rawErrorDetail,
            renderKind: old.renderKind,
            metadata: old.metadata,
            toolCalls: old.toolCalls,
            toolCallID: old.toolCallID,
            reasoningContent: old.reasoningContent,
            inputTokenCount: old.inputTokenCount,
            outputTokenCount: old.outputTokenCount,
            latencyMs: old.latencyMs,
            timeToFirstTokenMs: old.timeToFirstTokenMs,
            streamingDurationMs: old.streamingDurationMs
        )

        // Notify UI to refresh (previously missing — content updates did not trigger re-render)
        if Self.verbose {
            Self.logger.info("\(Self.t)updateMessage ➡️ conversation=\(conversationID.uuidString.prefix(8))…, message=\(id.uuidString.prefix(8))…, newContentChars=\(content.count)")
        }
        kernel?.eventManager.postMessagesDidChange(object: self)

        // Update in store async
        Task {
            await store?.updateMessage(id: id, content: content)
        }
    }

    public func clearMessages(in conversationID: UUID) {
        if Self.verbose {
            Self.logger.info("\(Self.t)clearMessages ➡️ conversation=\(conversationID.uuidString.prefix(8))…, cacheBefore=\(self.messageCache[conversationID]?.count ?? 0)")
        }
        messageCache[conversationID] = []

        Task {
            await store?.deleteAllMessages(conversationId: conversationID)
        }
    }

    // MARK: - Message Query

    public func message(id: UUID, in conversationID: UUID) -> LumiChatMessage? {
        messageCache[conversationID]?.first { $0.id == id }
    }

    public func lastMessage(in conversationID: UUID) -> LumiChatMessage? {
        messageCache[conversationID]?.last
    }

    public func fetchDailyMessageCounts(since: Date) async -> [Date: Int] {
        guard let store else { return [:] }
        return await store.fetchDailyMessageCounts(since: since)
    }

    public func fetchDailyTokenCounts(since: Date) async -> [Date: Int] {
        guard let store else { return [:] }
        return await store.fetchDailyTokenCounts(since: since)
    }

    // MARK: - Tool Call Result Update

    public func updateToolCallResult(
        _ result: LumiToolResult,
        toolCallID: String,
        assistantMessageID: UUID,
        in conversationID: UUID
    ) {
        guard let index = messageCache[conversationID]?.firstIndex(where: { $0.id == assistantMessageID }) else {
            if Self.verbose {
                Self.logger.warning("\(Self.t)updateToolCallResult: message \(assistantMessageID) not found")
            }
            return
        }

        let old = messageCache[conversationID]![index]
        guard var toolCalls = old.toolCalls else {
            if Self.verbose {
                Self.logger.warning("\(Self.t)updateToolCallResult: message has no toolCalls")
            }
            return
        }

        // Update the specific tool call's result
        for i in toolCalls.indices {
            if toolCalls[i].id == toolCallID {
                toolCalls[i].result = result
                break
            }
        }

        // Rebuild the message with updated toolCalls
        let updatedMessage = LumiChatMessage(
            id: old.id,
            conversationID: old.conversationID,
            role: old.role,
            content: old.content,
            createdAt: old.createdAt,
            providerID: old.providerID,
            modelName: old.modelName,
            isError: old.isError,
            rawErrorDetail: old.rawErrorDetail,
            renderKind: old.renderKind,
            metadata: old.metadata,
            toolCalls: toolCalls,
            toolCallID: old.toolCallID,
            reasoningContent: old.reasoningContent,
            inputTokenCount: old.inputTokenCount,
            outputTokenCount: old.outputTokenCount,
            latencyMs: old.latencyMs,
            timeToFirstTokenMs: old.timeToFirstTokenMs,
            streamingDurationMs: old.streamingDurationMs
        )

        messageCache[conversationID]![index] = updatedMessage

        if Self.verbose {
            Self.logger.info("\(Self.t)updateToolCallResult ➡️ conversation=\(conversationID.uuidString.prefix(8))…, message=\(assistantMessageID.uuidString.prefix(8))…, toolCall=\(toolCallID)")
        }

        // Notify UI to refresh
        kernel?.eventManager.postMessagesDidChange(object: self)

        // Persist the rebuilt tool calls (incl. nested tool-result images) so they
        // survive a restart. Previously only the in-memory cache was updated.
        Task {
            await store?.updateToolCalls(id: old.id, toolCalls: toolCalls)
        }
    }
}

public extension MessageManager {
    static let messagesDidChangeNotification = Notification.Name.lumiMessagesDidChange
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
