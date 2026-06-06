import Foundation

/// 流式 LLM 请求的重试策略。
public struct StreamRetryPolicy: Sendable {
    public let maxRetries: Int
    public let baseDelay: Double
    public let backoffMultiplier: Double

    public static let `default` = StreamRetryPolicy(
        maxRetries: 3,
        baseDelay: 2.0,
        backoffMultiplier: 2.0
    )

    public init(maxRetries: Int, baseDelay: Double, backoffMultiplier: Double) {
        self.maxRetries = maxRetries
        self.baseDelay = baseDelay
        self.backoffMultiplier = backoffMultiplier
    }

    public func delay(for attempt: Int) -> Double {
        let exponential = baseDelay * pow(backoffMultiplier, Double(attempt - 1))
        let jitter = Double.random(in: 0 ... 1.0)
        return exponential + jitter
    }
}

/// LLM 请求的结果：成功返回助手消息，取消或失败则返回对应信息。
public enum LLMRequestResult: Sendable {
    case success(ChatMessage)
    case cancelled
    case failed(ChatMessage)
}

/// 单次 LLM 发送请求。
public struct LLMSendRequest: Sendable {
    public let conversationId: UUID
    public let messages: [ChatMessage]
    public let additionalSystemPrompts: [String]

    public init(
        conversationId: UUID,
        messages: [ChatMessage],
        additionalSystemPrompts: [String] = []
    ) {
        self.conversationId = conversationId
        self.messages = messages
        self.additionalSystemPrompts = additionalSystemPrompts
    }
}
