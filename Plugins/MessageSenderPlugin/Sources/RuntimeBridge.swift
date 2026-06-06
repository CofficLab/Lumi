import Foundation
import HttpKit
import LLMKit
import LumiCoreKit

/// MessageSender 插件运行时桥接。
@MainActor
enum RuntimeBridge {
    static var loadMessages: (UUID) -> [ChatMessage] = { _ in [] }
    static var saveMessage: (ChatMessage, UUID) -> Void = { _, _ in }
    static var loadTurnPhase: (UUID) -> AgentTurnPhase = { _ in .idle }
    static var setTurnPhase: (AgentTurnPhase, UUID) -> Void = { _, _ in }
    static var tryAcquireConversationLock: (UUID) -> Bool = { _ in false }
    static var releaseConversationLock: (UUID) -> Void = { _ in }
    static var isConversationCancelled: (UUID) -> Bool = { _ in false }
    static var prepareMessagesForLLM: (UUID, [ChatMessage]) -> [ChatMessage] = { _, messages in messages }
    static var makeLLMSendDependencies: (UUID) -> LLMSendDependencies = { _ in LLMSendDependencies() }
    static var evaluateToolPermissions: (ChatMessage, UUID) -> ChatMessage = { message, _ in message }
    static var consumeTransientSystemPrompts: (UUID) -> [String] = { _ in [] }
    static var buildLLMErrorMessage: (Error, UUID, String?) -> ChatMessage = { error, conversationId, _ in
        ChatMessage(role: .assistant, conversationId: conversationId, content: error.localizedDescription, isError: true)
    }
    static var currentProviderId: (UUID) -> String? = { _ in nil }
    static var finishAgentTurn: (UUID, TurnEndReason) -> Void = { _, _ in }

    /// 正在发送中的会话，防止流式更新重复触发。
    static var inFlightConversationIds = Set<UUID>()
}
