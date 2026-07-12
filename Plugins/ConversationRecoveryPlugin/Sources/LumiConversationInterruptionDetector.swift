import Foundation
import LumiCoreKit

/// 对话中断原因类型
public enum LumiConversationInterruptionKind: String, Codable, Sendable {
    /// 流式生成中断（最后是 user 消息，无 assistant 回复）
    case streamingInterrupted
    /// 错误状态（最后是 error 消息）
    case errorState
    /// 工具执行未完成（assistant 消息有未完成的 toolCall）
    case toolExecutionIncomplete
    /// 等待用户回答（ask_user 工具等待中）
    case awaitingUserResponse
    /// Turn 未正常完成（没有 turn-completed 标记）
    case turnNotCompleted
}

/// 对话中断信息
public struct LumiConversationInterruption: Codable, Sendable {
    /// 中断的对话 ID
    public let conversationID: UUID
    /// 中断原因
    public let kind: LumiConversationInterruptionKind
    /// 最后一条消息的 ID（用于恢复）
    public let lastMessageID: UUID?
    /// 最后一条用户消息的 ID（用于重新发送）
    public let lastUserMessageID: UUID?
    /// 中断时间
    public let interruptedAt: Date
    /// 未完成工具调用的 assistant 消息 ID
    public let incompleteToolCallMessageID: UUID?
    /// 未完成工具调用的 ID
    public let incompleteToolCallID: String?

    public init(
        conversationID: UUID,
        kind: LumiConversationInterruptionKind,
        lastMessageID: UUID? = nil,
        lastUserMessageID: UUID? = nil,
        interruptedAt: Date = Date(),
        incompleteToolCallMessageID: UUID? = nil,
        incompleteToolCallID: String? = nil
    ) {
        self.conversationID = conversationID
        self.kind = kind
        self.lastMessageID = lastMessageID
        self.lastUserMessageID = lastUserMessageID
        self.interruptedAt = interruptedAt
        self.incompleteToolCallMessageID = incompleteToolCallMessageID
        self.incompleteToolCallID = incompleteToolCallID
    }
}

/// 对话中断检测器
public enum LumiConversationInterruptionDetector {
    /// 检测被中断的对话
    /// - Parameter messagesByConversation: 所有对话的消息字典
    /// - Returns: 被中断的对话信息数组
    public static func detectInterruptedConversations(
        in messagesByConversation: [UUID: [LumiChatMessage]]
    ) -> [LumiConversationInterruption] {
        var interrupted: [LumiConversationInterruption] = []

        for (conversationID, messages) in messagesByConversation {
            if let interruption = detectInterruption(conversationID: conversationID, messages: messages) {
                interrupted.append(interruption)
            }
        }

        return interrupted
    }

    /// 检测单个对话的中断情况
    public static func detectInterruption(
        conversationID: UUID,
        messages: [LumiChatMessage]
    ) -> LumiConversationInterruption? {
        // 过滤掉 status 消息（除了 turn-completed）
        let meaningfulMessages = messages.filter {
            $0.role != .status || $0.renderKind == "turn-completed"
        }

        guard !meaningfulMessages.isEmpty else {
            return nil
        }

        // 检查是否有 turn-completed 标记
        let hasTurnCompleted = messages.contains { $0.renderKind == "turn-completed" }

        // 获取最后一条有意义的消息
        guard let lastMessage = meaningfulMessages.last else {
            return nil
        }

        // 查找最后一条用户消息
        let lastUserMessageID = meaningfulMessages.lastIndex(where: { $0.role == .user })
            .map { meaningfulMessages[$0].id }

        // 情况1：等待用户回答（ask_user）
        if let askUserInterruption = detectAskUserInterruption(
            conversationID: conversationID,
            messages: meaningfulMessages,
            lastUserMessageID: lastUserMessageID
        ) {
            return askUserInterruption
        }

        // 情况2：工具执行未完成
        if let toolInterruption = detectToolExecutionInterruption(
            conversationID: conversationID,
            messages: meaningfulMessages,
            lastUserMessageID: lastUserMessageID
        ) {
            return toolInterruption
        }

        // 情况3：最后是 user 消息，没有 assistant 回复
        if lastMessage.role == .user {
            return LumiConversationInterruption(
                conversationID: conversationID,
                kind: .streamingInterrupted,
                lastMessageID: lastMessage.id,
                lastUserMessageID: lastMessage.id,
                interruptedAt: lastMessage.createdAt
            )
        }

        // 情况4：最后是 error 消息
        if lastMessage.role == .error || lastMessage.isError {
            return LumiConversationInterruption(
                conversationID: conversationID,
                kind: .errorState,
                lastMessageID: lastMessage.id,
                lastUserMessageID: lastUserMessageID,
                interruptedAt: lastMessage.createdAt
            )
        }

        // 情况5：有消息但没有 turn-completed 标记，且最后不是用户消息
        // 这说明 turn 没有正常完成
        if !hasTurnCompleted && meaningfulMessages.count > 1 {
            // 排除只有系统消息的情况
            let hasUserOrAssistantMessage = meaningfulMessages.contains {
                $0.role == .user || $0.role == .assistant
            }
            if hasUserOrAssistantMessage {
                return LumiConversationInterruption(
                    conversationID: conversationID,
                    kind: .turnNotCompleted,
                    lastMessageID: lastMessage.id,
                    lastUserMessageID: lastUserMessageID,
                    interruptedAt: lastMessage.createdAt
                )
            }
        }

        return nil
    }

    /// 检测 ask_user 等待状态
    private static func detectAskUserInterruption(
        conversationID: UUID,
        messages: [LumiChatMessage],
        lastUserMessageID: UUID?
    ) -> LumiConversationInterruption? {
        // 从后往前找最近的 assistant 消息
        for message in messages.reversed() {
            guard message.role == .assistant,
                  let toolCalls = message.toolCalls else {
                continue
            }

            // 检查是否有未完成的 ask_user 工具调用
            for toolCall in toolCalls {
                guard let result = toolCall.result,
                      LumiAskUserMarkers.isPendingResponse(result.content) else {
                    continue
                }

                return LumiConversationInterruption(
                    conversationID: conversationID,
                    kind: .awaitingUserResponse,
                    lastMessageID: message.id,
                    lastUserMessageID: lastUserMessageID,
                    interruptedAt: message.createdAt,
                    incompleteToolCallMessageID: message.id,
                    incompleteToolCallID: toolCall.id
                )
            }
        }

        return nil
    }

    /// 检测工具执行未完成
    private static func detectToolExecutionInterruption(
        conversationID: UUID,
        messages: [LumiChatMessage],
        lastUserMessageID: UUID?
    ) -> LumiConversationInterruption? {
        // 从后往前找最近的 assistant 消息
        for message in messages.reversed() {
            guard message.role == .assistant,
                  let toolCalls = message.toolCalls else {
                continue
            }

            // 检查是否有未完成的工具调用（result 为 nil）
            for toolCall in toolCalls {
                if toolCall.result == nil {
                    return LumiConversationInterruption(
                        conversationID: conversationID,
                        kind: .toolExecutionIncomplete,
                        lastMessageID: message.id,
                        lastUserMessageID: lastUserMessageID,
                        interruptedAt: message.createdAt,
                        incompleteToolCallMessageID: message.id,
                        incompleteToolCallID: toolCall.id
                    )
                }
            }
        }

        return nil
    }
}
