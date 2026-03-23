import Foundation

/// `LLMService` 及其配置校验可能产生的唯一错误类型。
enum LLMServiceError: Error, LocalizedError, Equatable {
    // MARK: - 配置校验（`LLMConfig.validate()`）

    case apiKeyEmpty
    case modelEmpty
    case providerIdEmpty
    case temperatureOutOfRange(Double)
    case maxTokensInvalid(Int)

    // MARK: - 服务

    /// 注册表中不存在对应 `providerId` 的实现。
    case providerNotFound(providerId: String)
    /// 供应商返回的 Base URL 无法解析为 `URL`。
    case invalidBaseURL(String)
    /// 任务被取消（如 `Task` 取消）。
    case cancelled
    /// 远程 API、流式解析、本地模型加载/就绪、或构建请求体失败等（使用用户可读文案）。
    case requestFailed(String)

    var errorDescription: String? {
        switch self {
        case .apiKeyEmpty:
            return String(localized: "API Key 不能为空", table: "LLMConfig")
        case .modelEmpty:
            return String(localized: "模型名称不能为空", table: "LLMConfig")
        case .providerIdEmpty:
            return String(localized: "供应商 ID 不能为空", table: "LLMConfig")
        case let .temperatureOutOfRange(v):
            return String(localized: "温度参数应在 0～2 之间，当前为 \(v)", table: "LLMConfig")
        case let .maxTokensInvalid(v):
            return String(localized: "最大 token 数应大于 0，当前为 \(v)", table: "LLMConfig")
        case let .providerNotFound(providerId):
            return "Provider not found: \(providerId)"
        case let .invalidBaseURL(string):
            return "Invalid Base URL: \(string)"
        case .cancelled:
            return String(localized: "已取消")
        case let .requestFailed(message):
            return message
        }
    }
}

// MARK: - ChatMessage

extension LLMServiceError {
    /// 转为可落库消息：配置类多为 `role: .system` + 占位键；请求失败多为 `assistant` + 文案。
    func toChatMessage() -> ChatMessage {
        switch self {
        case .apiKeyEmpty:
            ChatMessage(role: .system, conversationId: UUID(), content: ChatMessage.apiKeyMissingSystemContentKey, isError: true)
        case .modelEmpty:
            ChatMessage(role: .system, conversationId: UUID(), content: ChatMessage.llmModelEmptyContentKey, isError: true)
        case .providerIdEmpty:
            ChatMessage(role: .system, conversationId: UUID(), content: ChatMessage.llmProviderIdEmptyContentKey, isError: true)
        case let .temperatureOutOfRange(v):
            ChatMessage(
                role: .system,
                conversationId: UUID(),
                content: ChatMessage.llmTemperatureInvalidContentKey,
                isError: true,
                temperature: v
            )
        case let .maxTokensInvalid(v):
            ChatMessage(
                role: .system,
                conversationId: UUID(),
                content: ChatMessage.llmMaxTokensInvalidContentKey,
                isError: true,
                maxTokens: v
            )
        case let .providerNotFound(providerId):
            ChatMessage(
                role: .system,
                conversationId: UUID(),
                content: ChatMessage.llmProviderNotFoundContentKey,
                isError: true,
                providerId: providerId
            )
        case let .invalidBaseURL(urlString):
            ChatMessage(
                role: .system,
                conversationId: UUID(),
                content: ChatMessage.llmInvalidBaseURLMessageContent(baseURL: urlString),
                isError: true
            )
        case .cancelled:
            ChatMessage(
                role: .assistant,
                conversationId: UUID(),
                content: String(localized: "操作已取消。"),
                isError: true
            )
        case let .requestFailed(message):
            ChatMessage(role: .assistant, conversationId: UUID(), content: message, isError: true)
        }
    }
}
