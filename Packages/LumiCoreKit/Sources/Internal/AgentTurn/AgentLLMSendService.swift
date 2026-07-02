import Foundation

public struct LLMSendRequest: Sendable {
    public let conversationId: UUID
    public let messages: [AgentChatMessage]
    public let additionalSystemPrompts: [String]

    public init(
        conversationId: UUID,
        messages: [AgentChatMessage],
        additionalSystemPrompts: [String] = []
    ) {
        self.conversationId = conversationId
        self.messages = messages
        self.additionalSystemPrompts = additionalSystemPrompts
    }
}

public enum LLMRequestResult: Sendable {
    case success(AgentChatMessage)
    case failed(AgentChatMessage)
    case cancelled
}

public struct LLMResolvedConfig: Sendable {
    public let providerId: String
    public let model: String

    public init(providerId: String, model: String) {
        self.providerId = providerId
        self.model = model
    }
}

public struct AgentStreamChunk: Sendable, Equatable {
    public var content: String?
    public var isDone: Bool
    public var toolCalls: [AgentChatToolCall]?
    public var error: String?

    public init(
        content: String? = nil,
        isDone: Bool = false,
        toolCalls: [AgentChatToolCall]? = nil,
        error: String? = nil
    ) {
        self.content = content
        self.isDone = isDone
        self.toolCalls = toolCalls
        self.error = error
    }
}

public struct AgentRequestMetadata: Sendable {
    public var formattedBodySize: String
    public var duration: TimeInterval?
    public var error: Error?
    public var responseStatusCode: Int?

    public init(
        formattedBodySize: String = "",
        duration: TimeInterval? = nil,
        error: Error? = nil,
        responseStatusCode: Int? = nil
    ) {
        self.formattedBodySize = formattedBodySize
        self.duration = duration
        self.error = error
        self.responseStatusCode = responseStatusCode
    }
}

public struct StreamRetryPolicy: Sendable {
    public let maxRetries: Int
    private let baseDelaySeconds: TimeInterval

    public init(maxRetries: Int = 3, baseDelaySeconds: TimeInterval = 0.5) {
        self.maxRetries = maxRetries
        self.baseDelaySeconds = baseDelaySeconds
    }

    public func delay(for attempt: Int) -> TimeInterval {
        baseDelaySeconds * pow(2.0, Double(max(0, attempt - 1)))
    }
}

public struct StreamRetryDecision: Sendable {
    public let shouldRetry: Bool
    public let delaySeconds: TimeInterval?

    public init(shouldRetry: Bool, delaySeconds: TimeInterval? = nil) {
        self.shouldRetry = shouldRetry
        self.delaySeconds = delaySeconds
    }
}

@MainActor
public protocol AgentLLMSendService: AnyObject {
    var retryPolicy: StreamRetryPolicy { get }

    func prepareTools() -> [[String: Any]]?
    func resolveLLMConfig(
        for conversationID: UUID,
        messages: [AgentChatMessage],
        allowsTools: Bool
    ) -> LLMResolvedConfig
    func applyStreamChunk(conversationId: UUID, chunk: AgentStreamChunk)
    func setStatus(conversationId: UUID, content: String)
    func streamLLMMessage(
        messages: [AgentChatMessage],
        config: LLMResolvedConfig,
        tools: [[String: Any]]?,
        onChunk: @escaping @Sendable (AgentStreamChunk) async -> Void,
        onRequestStart: @escaping @Sendable (AgentRequestMetadata) async -> Void
    ) async throws -> AgentChatMessage
    func resolveRetryDecision(
        conversationId: UUID,
        error: Error,
        statusCode: Int?,
        attempt: Int
    ) -> StreamRetryDecision
    func runPostPipeline(
        metadata: AgentRequestMetadata,
        response: AgentChatMessage?,
        error: Error?,
        duration: TimeInterval
    ) async
    func buildErrorChatMessage(
        error: Error,
        conversationId: UUID,
        providerId: String,
        rawDetail: String
    ) -> AgentChatMessage
}

@MainActor
public final class UnavailableLLMSendService: AgentLLMSendService {
    public let retryPolicy = StreamRetryPolicy(maxRetries: 1)

    public init() {}

    public func prepareTools() -> [[String: Any]]? { nil }

    public func resolveLLMConfig(
        for conversationID: UUID,
        messages: [AgentChatMessage],
        allowsTools: Bool
    ) -> LLMResolvedConfig {
        LLMResolvedConfig(providerId: "unavailable", model: "unavailable")
    }

    public func applyStreamChunk(conversationId: UUID, chunk: AgentStreamChunk) {}

    public func setStatus(conversationId: UUID, content: String) {}

    public func streamLLMMessage(
        messages: [AgentChatMessage],
        config: LLMResolvedConfig,
        tools: [[String: Any]]?,
        onChunk: @escaping @Sendable (AgentStreamChunk) async -> Void,
        onRequestStart: @escaping @Sendable (AgentRequestMetadata) async -> Void
    ) async throws -> AgentChatMessage {
        throw NSError(domain: "AgentLLMSendService", code: 1, userInfo: [
            NSLocalizedDescriptionKey: "LLM send service is unavailable",
        ])
    }

    public func resolveRetryDecision(
        conversationId: UUID,
        error: Error,
        statusCode: Int?,
        attempt: Int
    ) -> StreamRetryDecision {
        StreamRetryDecision(shouldRetry: false)
    }

    public func runPostPipeline(
        metadata: AgentRequestMetadata,
        response: AgentChatMessage?,
        error: Error?,
        duration: TimeInterval
    ) async {}

    public func buildErrorChatMessage(
        error: Error,
        conversationId: UUID,
        providerId: String,
        rawDetail: String
    ) -> AgentChatMessage {
        AgentChatMessage(
            role: .error,
            conversationId: conversationId,
            content: error.localizedDescription,
            isError: true,
            rawErrorDetail: rawDetail,
            providerId: providerId
        )
    }
}
