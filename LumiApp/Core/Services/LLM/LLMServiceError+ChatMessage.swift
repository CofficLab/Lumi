import Foundation
import LLMKit

// MARK: - ChatMessage

extension LLMServiceError {
    /// 转为可落库消息：使用 `ChatMessage+Error` 中的工厂方法创建错误消息
    /// - Parameter conversationId: 会话 ID
    /// - Parameter providerId: 供应商 ID（可选，用于 API Key 缺失错误）
    func toChatMessage(conversationId: UUID, providerId: String? = nil) -> ChatMessage {
        switch self {
        case .apiKeyEmpty:
            // 如果错误中没有 providerId，尝试使用传入的 providerId
            let pid = providerId ?? ""
            return ChatMessage.apiKeyMissingMessage(providerId: pid, conversationId: conversationId)
        case .modelEmpty:
            return ChatMessage.llmModelEmptyMessage(conversationId: conversationId)
        case .providerIdEmpty:
            return ChatMessage.llmProviderIdEmptyMessage(conversationId: conversationId)
        case let .temperatureOutOfRange(v):
            return ChatMessage.llmTemperatureInvalidMessage(temperature: v, conversationId: conversationId)
        case let .maxTokensInvalid(v):
            return ChatMessage.llmMaxTokensInvalidMessage(maxTokens: v, conversationId: conversationId)
        case let .providerNotFound(providerId):
            return ChatMessage.llmProviderNotFoundMessage(providerId: providerId, conversationId: conversationId)
        case let .invalidBaseURL(urlString):
            return ChatMessage.llmInvalidBaseURLMessage(baseURL: urlString, conversationId: conversationId)
        case .cancelled:
            return ChatMessage.cancelledMessage(conversationId: conversationId)
        case let .requestFailed(message):
            return ChatMessage.llmRequestFailedMessage(message: message, conversationId: conversationId)
        }
    }
}
