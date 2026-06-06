import Foundation
import LLMKit

public extension ChatMessage {
    /// API Key 缺失错误消息（通用占位，供无供应商自定义渲染时回退）。
    static func apiKeyMissingMessage(providerId: String, conversationId: UUID) -> ChatMessage {
        ChatMessage(
            role: .error,
            conversationId: conversationId,
            content: apiKeyMissingSystemContentKey,
            isError: true,
            providerId: providerId
        )
    }

    /// 将 ``LLMServiceError`` 映射为可落库的错误消息。
    static func from(
        llmError: LLMServiceError,
        conversationId: UUID,
        providerId: String,
        rawDetail: String? = nil
    ) -> ChatMessage {
        switch llmError {
        case .apiKeyEmpty:
            return apiKeyMissingMessage(providerId: providerId, conversationId: conversationId)

        case .modelEmpty:
            return ChatMessage(
                role: .error,
                conversationId: conversationId,
                content: llmModelEmptyContentKey,
                isError: true
            )

        case .providerIdEmpty:
            return ChatMessage(
                role: .error,
                conversationId: conversationId,
                content: llmProviderIdEmptyContentKey,
                isError: true
            )

        case let .temperatureOutOfRange(value):
            return ChatMessage(
                role: .error,
                conversationId: conversationId,
                content: llmTemperatureInvalidContentKey,
                isError: true,
                temperature: value
            )

        case let .maxTokensInvalid(value):
            return ChatMessage(
                role: .error,
                conversationId: conversationId,
                content: llmMaxTokensInvalidContentKey,
                isError: true,
                maxTokens: value
            )

        case let .providerNotFound(missingProviderId):
            return ChatMessage(
                role: .error,
                conversationId: conversationId,
                content: llmProviderNotFoundContentKey,
                isError: true,
                providerId: missingProviderId
            )

        case let .invalidBaseURL(urlString):
            return ChatMessage(
                role: .error,
                conversationId: conversationId,
                content: llmInvalidBaseURLMessageContent(baseURL: urlString),
                isError: true
            )

        case .cancelled:
            return ChatMessage(
                role: .error,
                conversationId: conversationId,
                content: "操作已取消。",
                isError: true
            )

        case let .requestFailed(message, _):
            return ChatMessage(
                role: .error,
                conversationId: conversationId,
                content: message,
                isError: true,
                providerId: providerId,
                rawErrorDetail: rawDetail ?? message
            )
        }
    }
}
