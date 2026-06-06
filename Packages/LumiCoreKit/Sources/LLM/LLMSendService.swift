import AgentToolKit
import Foundation
import HttpKit
import LLMKit
import LLMProviderKit

public enum LLMSendServiceError: Error, LocalizedError {
    case notConfigured

    public var errorDescription: String? {
        switch self {
        case .notConfigured:
            return "LLMSendService is not configured"
        }
    }
}

/// MessageSender 插件向 LLM 供应商发送消息所需的能力。
///
/// 由 App 层注入实现；插件在 ``configureRuntime`` 时绑定并调用。
@MainActor
public protocol LLMSendService: Sendable {
    var retryPolicy: StreamRetryPolicy { get }

    /// 解析本次请求使用的供应商与模型（含 Auto Route 等 App 层策略）。
    func resolveLLMConfig(
        for conversationId: UUID,
        messages: [ChatMessage],
        allowsTools: Bool
    ) -> LLMConfig

    /// 准备本次请求可用的 Agent 工具列表。
    func prepareTools() -> [SuperAgentTool]?

    /// 流式调用 LLM 供应商并返回完整助手消息。
    func streamLLMMessage(
        messages: [ChatMessage],
        config: LLMConfig,
        tools: [SuperAgentTool]?,
        onChunk: @escaping @Sendable (StreamChunk) async -> Void,
        onRequestStart: @escaping @Sendable (HTTPRequestMetadata) async -> Void
    ) async throws -> ChatMessage

    func applyStreamChunk(conversationId: UUID, chunk: StreamChunk)
    func setStatus(conversationId: UUID, content: String)
    func runPostPipeline(
        metadata: HTTPRequestMetadata,
        response: ChatMessage?,
        error: Error?,
        duration: TimeInterval
    ) async
    func resolveRetryDecision(
        conversationId: UUID,
        error: Error,
        statusCode: Int?,
        attempt: Int
    ) -> ProviderRetryDecision

    /// 将发送失败映射为可落库的错误消息；优先使用供应商 ``SuperLLMProvider/buildErrorChatMessage``。
    func buildErrorChatMessage(
        error: Error,
        conversationId: UUID,
        providerId: String,
        rawDetail: String?
    ) -> ChatMessage
}

/// 未注入实现时的空操作占位。
public struct UnavailableLLMSendService: LLMSendService {
    public let retryPolicy: StreamRetryPolicy = .default

    public init() {}

    public func resolveLLMConfig(
        for conversationId: UUID,
        messages: [ChatMessage],
        allowsTools: Bool
    ) -> LLMConfig {
        LLMConfig.default
    }

    public func prepareTools() -> [SuperAgentTool]? { nil }

    public func streamLLMMessage(
        messages: [ChatMessage],
        config: LLMConfig,
        tools: [SuperAgentTool]?,
        onChunk: @escaping @Sendable (StreamChunk) async -> Void,
        onRequestStart: @escaping @Sendable (HTTPRequestMetadata) async -> Void
    ) async throws -> ChatMessage {
        throw LLMSendServiceError.notConfigured
    }

    public func applyStreamChunk(conversationId: UUID, chunk: StreamChunk) {}
    public func setStatus(conversationId: UUID, content: String) {}

    public func runPostPipeline(
        metadata: HTTPRequestMetadata,
        response: ChatMessage?,
        error: Error?,
        duration: TimeInterval
    ) async {}

    public func resolveRetryDecision(
        conversationId: UUID,
        error: Error,
        statusCode: Int?,
        attempt: Int
    ) -> ProviderRetryDecision {
        .doNotRetry
    }

    public func buildErrorChatMessage(
        error: Error,
        conversationId: UUID,
        providerId: String,
        rawDetail: String?
    ) -> ChatMessage {
        let detail = rawDetail ?? error.localizedDescription
        if let llmError = error as? LLMServiceError {
            return ChatMessage.from(
                llmError: llmError,
                conversationId: conversationId,
                providerId: providerId,
                rawDetail: detail
            )
        }
        return ChatMessage(
            role: .error,
            conversationId: conversationId,
            content: detail,
            isError: true,
            providerId: providerId,
            rawErrorDetail: detail
        )
    }
}
