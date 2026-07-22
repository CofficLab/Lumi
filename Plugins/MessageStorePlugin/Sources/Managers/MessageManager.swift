import Foundation
import LumiKernel
import LumiKernel
import SuperLogKit
import os

/// Message Manager Service
///
/// Implements MessageManaging protocol with SwiftData persistence.
@MainActor
public final class MessageManager: ObservableObject, MessageManaging, SuperLog {
    nonisolated public static let emoji = "💬"
    nonisolated(unsafe) public static var verbose = true
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
            if Self.verbose {
                Self.logger.warning("\(Self.t)Store not available")
            }
            return
        }

        Task {
            let loaded = await store.fetchMessages(conversationId: conversationID)
            await MainActor.run {
                self.messageCache[conversationID] = loaded
                if Self.verbose {
                    Self.logger.info("\(Self.t)Loaded \(loaded.count) messages for conversation \(conversationID.uuidString.prefix(8))")
                }
                // Notify UI to refresh
                NotificationCenter.default.post(name: Self.messagesDidChangeNotification, object: self)
            }
        }
    }

    // MARK: - MessageManaging

    public func messages(for conversationID: UUID) -> [LumiChatMessage] {
        // If cache doesn't exist for this conversation, trigger async load
        if messageCache[conversationID] == nil {
            Self.logger.info("\(Self.t)Cache miss for conversationID=\(conversationID.uuidString.prefix(8)), loading from database async")
            // Start async load - UI will be updated via notification
            loadMessages(for: conversationID)
        }
        let cached = messageCache[conversationID] ?? []
        Self.logger.info("\(Self.t)messages(for:) conversationID=\(conversationID.uuidString.prefix(8)), cached count=\(cached.count), cache keys=\(self.messageCache.keys.map { $0.uuidString.prefix(8) })")
        return cached
    }

    public nonisolated func messagesAsync(for conversationID: UUID) async -> [LumiChatMessage] {
        await store?.fetchMessages(conversationId: conversationID) ?? []
    }

    public func deleteMessage(id: UUID, in conversationID: UUID) {
        // Remove from cache
        messageCache[conversationID]?.removeAll { $0.id == id }

        // Delete from store async
        Task {
            await store?.deleteMessage(id: id)
        }
    }

    public func insertMessage(_ message: LumiChatMessage, to conversationID: UUID) {
        Self.logger.info("\(Self.t)insertMessage called: message.conversationID=\(message.conversationID.uuidString.prefix(8)), target conversationID=\(conversationID.uuidString.prefix(8))")

        // Ensure message has the correct conversationID
        var messageToInsert = message
        if messageToInsert.conversationID != conversationID {
            Self.logger.info("\(Self.t)conversationID mismatch, creating new message with target ID")
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
            Self.logger.info("\(Self.t)Created new cache array for conversationID=\(conversationID.uuidString.prefix(8))")
        }
        messageCache[conversationID]?.append(messageToInsert)

        let totalCount = self.messageCache[conversationID]?.count ?? 0
        Self.logger.info("\(Self.t)Inserted message \(messageToInsert.id.uuidString.prefix(8)) to cache, total: \(totalCount), all cache keys=\(self.messageCache.keys.map { $0.uuidString.prefix(8) })")

        // Notify observers that messages changed
        NotificationCenter.default.post(name: Self.messagesDidChangeNotification, object: self)

        // Persist to store async
        Task {
            do {
                try await store?.insertMessage(messageToInsert)
            } catch {
                if Self.verbose {
                    Self.logger.error("\(Self.t)Failed to persist message: \(error)")
                }
            }
        }
    }

    public func updateMessage(id: UUID, in conversationID: UUID, content: String) {
        // Update in cache
        if let index = messageCache[conversationID]?.firstIndex(where: { $0.id == id }) {
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
        }

        // Update in store async
        Task {
            await store?.updateMessage(id: id, content: content)
        }
    }

    public func clearMessages(in conversationID: UUID) {
        messageCache[conversationID] = []

        Task {
            await store?.deleteAllMessages(conversationId: conversationID)
        }
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
            Self.logger.info("\(Self.t)updateToolCallResult: updated toolCall \(toolCallID) in message \(assistantMessageID)")
        }

        // Notify UI to refresh
        NotificationCenter.default.post(name: Self.messagesDidChangeNotification, object: self)

        // Note: Store persistence for tool call result updates can be optimized later.
        // The cache is the primary source of truth for UI rendering.
    }
}

// MARK: - Notification

public extension Notification.Name {
    static let messagesDidChange = Notification.Name("com.coffic.lumi.messagesDidChange")
}

public extension MessageManager {
    static let messagesDidChangeNotification = Notification.Name("com.coffic.lumi.messagesDidChange")
}
