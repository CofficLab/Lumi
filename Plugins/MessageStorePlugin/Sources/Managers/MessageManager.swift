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
public final class MessageManager: ObservableObject, MessageManaging, SuperLog, @unchecked Sendable {
    public nonisolated static let emoji = "💬"
    public nonisolated(unsafe) static var verbose = true
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "message.manager")

    private weak var kernel: LumiKernel?

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
        guard let store else { return [] }
        return store.fetchMessagePage(
            conversationId: conversationID,
            limit: limit,
            beforeMessageID: beforeMessageID,
            includesToolMessages: includesToolMessages
        )
    }

    public nonisolated func messageCount(for conversationID: UUID) -> Int {
        store?.messageCount(conversationId: conversationID) ?? 0
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

        // Persist synchronously
        do {
            try store?.insertMessage(messageToInsert)
        } catch {
            if Self.verbose {
                Self.logger.error("\(Self.t)Failed to persist message: \(error)")
            }
        }

        // Notify observers that messages changed
        kernel?.eventManager.postMessagesDidChange(object: self, conversationID: conversationID)
    }

    @MainActor
    public func updateMessage(id: UUID, in conversationID: UUID, content: String) {
        if Self.verbose {
            Self.logger.info("\(Self.t)updateMessage ➡️ conversation=\(conversationID.uuidString.prefix(8))…, message=\(id.uuidString.prefix(8))…, newContentChars=\(content.count)")
        }
        store?.updateMessage(id: id, content: content)
        // Notify UI to refresh
        kernel?.eventManager.postMessagesDidChange(object: self, conversationID: conversationID)
    }

    @MainActor
    public func clearMessages(in conversationID: UUID) {
        if Self.verbose {
            Self.logger.info("\(Self.t)clearMessages ➡️ conversation=\(conversationID.uuidString.prefix(8))…")
        }
        store?.deleteAllMessages(conversationId: conversationID)
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
        guard let old = store?.fetchMessage(id: assistantMessageID) else {
            if Self.verbose {
                Self.logger.warning("\(Self.t)updateToolCallResult: message \(assistantMessageID) not found")
            }
            return
        }

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

        // Persist the rebuilt tool calls (incl. nested tool-result images)
        store?.updateToolCalls(id: old.id, toolCalls: toolCalls)

        if Self.verbose {
            Self.logger.info("\(Self.t)updateToolCallResult ➡️ conversation=\(conversationID.uuidString.prefix(8))…, message=\(assistantMessageID.uuidString.prefix(8))…, toolCall=\(toolCallID)")
        }

        // Notify UI to refresh
        kernel?.eventManager.postMessagesDidChange(object: self, conversationID: conversationID)
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
