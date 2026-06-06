import AgentToolKit
import Foundation
import HttpKit
import LLMKit
import LLMProviderKit

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
    case failed(Error)
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

/// App 层注入的运行时依赖，供 MessageSender 插件执行 LLM 发送。
public struct LLMSendDependencies {
    public var retryPolicy: StreamRetryPolicy
    public var resolveRequestConfig: @MainActor (UUID, [ChatMessage], Bool) -> LLMConfig
    public var prepareTools: @MainActor () -> [SuperAgentTool]?
    public var sendStreamingMessage: @MainActor (
        _ messages: [ChatMessage],
        _ config: LLMConfig,
        _ tools: [SuperAgentTool]?,
        _ onChunk: @escaping @Sendable (StreamChunk) async -> Void,
        _ onRequestStart: @escaping @Sendable (HTTPRequestMetadata) async -> Void
    ) async throws -> ChatMessage
    public var applyStreamChunk: @MainActor (UUID, StreamChunk) -> Void
    public var setStatus: @MainActor (UUID, String) -> Void
    public var runPostPipeline: @MainActor (
        _ metadata: HTTPRequestMetadata,
        _ response: ChatMessage?,
        _ error: Error?,
        _ duration: TimeInterval
    ) async -> Void
    public var logInfo: @MainActor (String) -> Void
    public var logError: @MainActor (String) -> Void
    public var resolveRetryDecision: @MainActor (UUID, Error, Int?, Int) -> ProviderRetryDecision

    public init(
        retryPolicy: StreamRetryPolicy = .default,
        resolveRequestConfig: @escaping @MainActor (UUID, [ChatMessage], Bool) -> LLMConfig = { _, _, _ in LLMConfig.default },
        prepareTools: @escaping @MainActor () -> [SuperAgentTool]? = { nil },
        sendStreamingMessage: @escaping @MainActor (
            [ChatMessage],
            LLMConfig,
            [SuperAgentTool]?,
            @escaping @Sendable (StreamChunk) async -> Void,
            @escaping @Sendable (HTTPRequestMetadata) async -> Void
        ) async throws -> ChatMessage = { _, _, _, _, _ in
            throw AgentLLMSenderError.notConfigured
        },
        applyStreamChunk: @escaping @MainActor (UUID, StreamChunk) -> Void = { _, _ in },
        setStatus: @escaping @MainActor (UUID, String) -> Void = { _, _ in },
        runPostPipeline: @escaping @MainActor (HTTPRequestMetadata, ChatMessage?, Error?, TimeInterval) async -> Void = { _, _, _, _ in },
        logInfo: @escaping @MainActor (String) -> Void = { _ in },
        logError: @escaping @MainActor (String) -> Void = { _ in },
        resolveRetryDecision: @escaping @MainActor (UUID, Error, Int?, Int) -> ProviderRetryDecision = { _, _, _, _ in .doNotRetry }
    ) {
        self.retryPolicy = retryPolicy
        self.resolveRequestConfig = resolveRequestConfig
        self.prepareTools = prepareTools
        self.sendStreamingMessage = sendStreamingMessage
        self.applyStreamChunk = applyStreamChunk
        self.setStatus = setStatus
        self.runPostPipeline = runPostPipeline
        self.logInfo = logInfo
        self.logError = logError
        self.resolveRetryDecision = resolveRetryDecision
    }
}

public enum AgentLLMSenderError: Error, LocalizedError {
    case notConfigured

    public var errorDescription: String? {
        switch self {
        case .notConfigured:
            return "MessageSender plugin is not configured"
        }
    }
}

/// Agent 向 LLM 供应商发送消息的桥接入口。
///
/// 由 ``MessageSenderPlugin`` 在 ``SuperPlugin/configureRuntime(context:)`` 中注册实现；
/// ``AgentTurnService`` 通过此入口委托发送，而不直接持有 HTTP/重试细节。
@MainActor
public enum AgentLLMSender {
    nonisolated(unsafe) public static var send: @MainActor (LLMSendRequest, LLMSendDependencies) async -> LLMRequestResult = { _, _ in
        .failed(AgentLLMSenderError.notConfigured)
    }
}
