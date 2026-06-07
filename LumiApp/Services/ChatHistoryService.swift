import AgentToolKit
import Foundation
import LumiCoreKit
import SwiftData

// MARK: - ToolCall / ChatMessage 便捷扩展

extension ToolCall {
    /// 将嵌入在 ToolCall 中的结果投影为 LLM 所需的 `role: .tool` 消息。
    func projectedToolOutputMessage(conversationId: UUID) -> ChatMessage? {
        guard let result else { return nil }
        return ChatMessage(
            role: .tool,
            conversationId: conversationId,
            content: result.content,
            isError: result.isError,
            toolCallID: id,
            images: result.images
        )
    }
}

extension ChatMessage {
    /// 发送给 LLM 时使用的 assistant 消息副本（不包含嵌入的工具结果）。
    func forLLMAssistantMessage() -> ChatMessage {
        var message = self
        if let toolCalls {
            message.toolCalls = toolCalls.map {
                ToolCall(
                    id: $0.id,
                    name: $0.name,
                    arguments: $0.arguments,
                    authorizationState: $0.authorizationState
                )
            }
        }
        return message
    }
}

// MARK: - ChatHistoryService

/// 聊天历史服务 — 组合消息持久化与 LLM 上下文变换。
///
/// 消息相关的 SwiftData 读写委托给 ``MessageService``；
/// 本服务保留 LLM 消息展开等上层逻辑。
@MainActor
final class ChatHistoryService: SuperLog, Sendable {
    nonisolated static let emoji = "💾"
    nonisolated static let verbose: Bool = true

    let messageService: MessageService
    let conversationService: ConversationService
    typealias ConversationTimelineSummary = MessageService.ConversationTimelineSummary

    init(
        messageService: MessageService,
        conversationService: ConversationService,
        reason: String
    ) {
        self.messageService = messageService
        self.conversationService = conversationService
        if Self.verbose {
            AppLogger.core.info("\(Self.t)✅ (\(reason)) 聊天历史服务已初始化")
        }
    }

    func getContext() -> ModelContext {
        messageService.getContext()
    }

    func getModelContainer() -> ModelContainer {
        messageService.getModelContainer()
    }
}

// MARK: - 消息持久化（委托给 MessageService）

extension ChatHistoryService {

    @discardableResult
    func saveMessage(_ message: ChatMessage, to conversation: Conversation) -> ChatMessage? {
        messageService.saveMessage(message, to: conversation)
    }

    @discardableResult
    func saveMessage(_ message: ChatMessage, toConversationId conversationId: UUID) -> ChatMessage? {
        messageService.saveMessage(message, toConversationId: conversationId)
    }

    func updateMessageAsync(_ message: ChatMessage, conversationId: UUID) async -> ChatMessage? {
        await messageService.updateMessageAsync(message, conversationId: conversationId)
    }

    func deleteMessagesAsync(messageIds: [UUID], conversationId: UUID) async -> Int {
        await messageService.deleteMessagesAsync(messageIds: messageIds, conversationId: conversationId)
    }

    func loadMessages(forConversationId conversationId: UUID) -> [ChatMessage]? {
        messageService.loadMessages(forConversationId: conversationId)
    }

    func loadMessages(for conversation: Conversation) -> [ChatMessage] {
        messageService.loadMessages(for: conversation)
    }

    func getConversationTimelineSummary(forConversationId conversationId: UUID) -> ConversationTimelineSummary {
        messageService.getConversationTimelineSummary(forConversationId: conversationId)
    }

    func loadMessagesPage(
        forConversationId conversationId: UUID,
        limit: Int,
        beforeTimestamp: Date? = nil
    ) async -> (messages: [ChatMessage], hasMore: Bool) {
        await messageService.loadMessagesPage(
            forConversationId: conversationId,
            limit: limit,
            beforeTimestamp: beforeTimestamp
        )
    }

    func getMessageCount(forConversationId conversationId: UUID) async -> Int {
        await messageService.getMessageCount(forConversationId: conversationId)
    }

    @discardableResult
    func updateMessage(_ message: ChatMessage, conversationId: UUID) -> ChatMessage? {
        messageService.updateMessage(message, conversationId: conversationId)
    }

    func pendingMessages(forConversationId conversationId: UUID) -> [ChatMessage] {
        messageService.pendingMessages(forConversationId: conversationId)
    }

    @discardableResult
    func dequeueNextPendingMessage(forConversationId conversationId: UUID) -> ChatMessage? {
        messageService.dequeueNextPendingMessage(forConversationId: conversationId)
    }

    func clearQueueStatus(forConversationId conversationId: UUID) {
        messageService.clearQueueStatus(forConversationId: conversationId)
    }

    @discardableResult
    func removePendingMessage(id messageId: UUID, conversationId: UUID) -> Bool {
        messageService.removePendingMessage(id: messageId, conversationId: conversationId)
    }
}

// MARK: - 消息展开（LLM 上下文）

extension ChatHistoryService {
    /// 将存储中的 assistant/toolCalls 展开为 LLM 可消费的完整消息序列。
    func expandMessagesForLLM(_ messages: [ChatMessage]) -> [ChatMessage] {
        var expanded: [ChatMessage] = []

        for message in messages {
            switch message.role {
            case .tool:
                if message.shouldSendToLLM {
                    expanded.append(message)
                }
            case .assistant:
                expanded.append(message.forLLMAssistantMessage())
                if let toolCalls = message.toolCalls {
                    for toolCall in toolCalls {
                        if let projected = toolCall.projectedToolOutputMessage(conversationId: message.conversationId) {
                            expanded.append(projected)
                        }
                    }
                }
            default:
                if message.shouldSendToLLM {
                    expanded.append(message)
                }
            }
        }

        return expanded
    }

    /// 加载会话消息并展开为 LLM 上下文。
    func loadMessagesExpandedForLLM(forConversationId conversationId: UUID) -> [ChatMessage]? {
        guard let messages = loadMessages(forConversationId: conversationId) else { return nil }
        return expandMessagesForLLM(messages)
    }
}
