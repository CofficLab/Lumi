import AgentToolKit
import Foundation
import HttpKit
import LLMKit
import LLMProviderKit
import LumiCoreKit

/// 桥接 ``LLMSendService`` 与 App 层 LLM / 路由 / 状态服务。
@MainActor
final class LiveLLMSendService: LLMSendService, Sendable {
    let retryPolicy: StreamRetryPolicy = .default

    private let runtime: AgentLLMRuntime
    private let llmService: LLMService
    private let statusVM: WindowConversationStatusVM
    private let pluginVM: AppPluginVM
    private let toolService: ToolService
    private let projectVM: WindowProjectVM
    private let agentSessionConfig: AppLLMVM

    init(runtime: AgentLLMRuntime, container: RootContainer, windowContainer: WindowContainer) {
        self.runtime = runtime
        self.llmService = container.llmService
        self.statusVM = windowContainer.conversationSendStatusVM
        self.pluginVM = container.pluginVM
        self.toolService = container.toolService
        self.projectVM = windowContainer.projectVM
        self.agentSessionConfig = container.agentSessionConfig
    }

    func resolveLLMConfig(
        for conversationId: UUID,
        messages: [ChatMessage],
        allowsTools: Bool
    ) -> LLMConfig {
        runtime.resolveLLMConfig(
            for: conversationId,
            messages: messages,
            allowsTools: allowsTools
        )
    }

    func prepareTools() -> [SuperAgentTool]? {
        toolService.languagePreference = projectVM.languagePreference
        let availableTools = ToolAvailabilityGuard().evaluate(
            tools: toolService.tools,
            allowsTools: agentSessionConfig.chatMode.allowsTools,
            isFinalStep: false
        )
        return availableTools.isEmpty ? nil : availableTools
    }

    func streamLLMMessage(
        messages: [ChatMessage],
        config: LLMConfig,
        tools: [SuperAgentTool]?,
        onChunk: @escaping @Sendable (StreamChunk) async -> Void,
        onRequestStart: @escaping @Sendable (HTTPRequestMetadata) async -> Void
    ) async throws -> ChatMessage {
        try await llmService.sendStreamingMessage(
            messages: messages,
            config: config,
            tools: tools,
            onChunk: onChunk,
            onRequestStart: onRequestStart
        )
    }

    func applyStreamChunk(conversationId: UUID, chunk: StreamChunk) {
        statusVM.applyStreamChunk(conversationId: conversationId, chunk: chunk)
    }

    func setStatus(conversationId: UUID, content: String) {
        statusVM.setStatus(conversationId: conversationId, content: content)
    }

    func runPostPipeline(
        metadata: HTTPRequestMetadata,
        response: ChatMessage?,
        error: Error?,
        duration: TimeInterval
    ) async {
        var mutableMetadata = metadata
        mutableMetadata.duration = duration
        if let error {
            mutableMetadata.error = error
            if let llmError = error as? LLMServiceError,
               case let .requestFailed(_, statusCode) = llmError {
                mutableMetadata.responseStatusCode = statusCode
            } else if let apiError = error as? HTTPClientError,
                      case let .httpError(statusCode, _) = apiError {
                mutableMetadata.responseStatusCode = statusCode
            }
        } else {
            mutableMetadata.responseStatusCode = 200
        }
        let pipeline = SendPipeline(middlewares: pluginVM.getSuperSendMiddlewares())
        await pipeline.runPost(metadata: mutableMetadata, response: response)
    }

    func resolveRetryDecision(
        conversationId: UUID,
        error: Error,
        statusCode: Int?,
        attempt: Int
    ) -> ProviderRetryDecision {
        guard let providerId = runtime.currentProviderId(for: conversationId),
              let provider = llmService.createProvider(id: providerId) else {
            return ProviderRetryDecision(shouldRetry: false)
        }
        return provider.retryDecision(
            for: error,
            statusCode: statusCode,
            attempt: attempt,
            maxAttempts: retryPolicy.maxRetries
        )
    }

    func buildErrorChatMessage(
        error: Error,
        conversationId: UUID,
        providerId: String,
        rawDetail: String?
    ) -> ChatMessage {
        let detail = rawDetail ?? error.localizedDescription
        if let provider = llmService.createProvider(id: providerId),
           let custom = provider.buildErrorChatMessage(
               error: error,
               conversationId: conversationId,
               rawDetail: detail
           ) {
            return custom
        }
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
