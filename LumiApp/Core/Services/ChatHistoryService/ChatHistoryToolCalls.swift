import Foundation
import AgentToolKit
import SwiftData

extension ToolCall {
    /// 将嵌入在 ToolCall 中的结果投影为 LLM 所需的 `role: .tool` 消息。
    func projectedToolOutputMessage(conversationId: UUID) -> ChatMessage? {
        guard let result else { return nil }
        return ChatMessage(
            id: UUID(),
            role: .tool,
            conversationId: conversationId,
            content: result.content,
            timestamp: result.executedAt,
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

extension ChatHistoryService {
    private static let embeddedToolResultMigrationKey = "ChatHistory.embeddedToolResultMigrationV1"

    /// 将存储中的 assistant/toolCalls 展开为 LLM 可消费的完整消息序列。
    func expandMessagesForLLM(_ messages: [ChatMessage]) -> [ChatMessage] {
        var expanded: [ChatMessage] = []

        for message in messages {
            switch message.role {
            case .tool:
                // 迁移前遗留的独立 tool 消息
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

    /// 将历史 `role: .tool` 消息回填到 `ToolCallEntity`，并删除冗余 tool 消息行。
    func migrateEmbeddedToolResultsIfNeeded() {
        guard !UserDefaults.standard.bool(forKey: Self.embeddedToolResultMigrationKey) else { return }

        let context = getContext()
        let descriptor = FetchDescriptor<ChatMessageEntity>(
            predicate: #Predicate<ChatMessageEntity> { $0._role == "tool" }
        )

        guard let legacyToolMessages = try? context.fetch(descriptor), !legacyToolMessages.isEmpty else {
            UserDefaults.standard.set(true, forKey: Self.embeddedToolResultMigrationKey)
            return
        }

        var migratedCount = 0

        for toolMessage in legacyToolMessages {
            guard let toolCallID = toolMessage.toolCallID, !toolCallID.isEmpty else {
                context.delete(toolMessage)
                continue
            }

            var toolCallDescriptor = FetchDescriptor<ToolCallEntity>(
                predicate: #Predicate<ToolCallEntity> { $0.id == toolCallID }
            )
            toolCallDescriptor.fetchLimit = 1

            guard let toolCallEntity = try? context.fetch(toolCallDescriptor).first else {
                continue
            }

            if toolCallEntity.resultContent == nil {
                toolCallEntity.resultContent = toolMessage.content
                toolCallEntity.resultIsError = toolMessage.isError
                toolCallEntity.resultExecutedAt = toolMessage.timestamp
                toolCallEntity.resultImages = toolMessage.images
                migratedCount += 1
            }

            context.delete(toolMessage)
        }

        cleanupOrphanedImages(in: context)

        do {
            try context.save()
            UserDefaults.standard.set(true, forKey: Self.embeddedToolResultMigrationKey)
            if migratedCount > 0 {
                AppLogger.core.info("\(Self.t)✅ 已迁移 \(migratedCount) 条工具结果到 ToolCallEntity")
            }
        } catch {
            AppLogger.core.error("\(Self.t)❌ 工具结果迁移失败：\(error.localizedDescription)")
        }
    }
}
