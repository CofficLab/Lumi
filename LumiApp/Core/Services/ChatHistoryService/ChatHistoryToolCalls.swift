import Foundation
import AgentToolKit
import SwiftData

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

extension ChatHistoryService {
    /// 将存储中的 assistant/toolCalls 展开为 LLM 可消费的完整消息序列。
    func expandMessagesForLLM(_ messages: [ChatMessage]) -> [ChatMessage] {
        var expanded: [ChatMessage] = []

        for message in messages {
            switch message.role {
            case .tool:
                // 独立的 tool 消息（投影产生的）
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
