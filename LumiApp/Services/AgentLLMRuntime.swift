import AgentToolKit
import Foundation
import HttpKit
import LLMKit
import LLMProviderKit
import LumiCoreKit
import ModelRouterKit

/// App 层 LLM 请求支持：供插件 runtime 注入使用。
@MainActor
final class AgentLLMRuntime {
    private let container: RootContainer
    private let windowContainer: WindowContainer

    init(container: RootContainer, windowContainer: WindowContainer) {
        self.container = container
        self.windowContainer = windowContainer
    }

    func prepareMessages(conversationId: UUID, messages: [ChatMessage]) -> [ChatMessage] {
        let llmMessages = container.chatHistoryService.expandMessagesForLLM(messages)
        let contextWindowSize = resolveContextWindowSize(for: conversationId)
        let lastInputTokens = resolveLastInputTokens(for: conversationId)
        return ContextPruner.prune(
            llmMessages,
            lastInputTokens: lastInputTokens,
            contextWindowSize: contextWindowSize
        ).messages
    }

    func makeLLMSendDependencies(conversationId: UUID) -> LLMSendDependencies {
        let llmService = container.llmService
        let statusVM = windowContainer.conversationSendStatusVM
        let pluginVM = container.pluginVM
        let toolService = container.toolService
        let projectVM = windowContainer.projectVM
        let agentSessionConfig = container.agentSessionConfig
        let conversationVM = windowContainer.conversationVM

        return LLMSendDependencies(
            retryPolicy: .default,
            resolveRequestConfig: { [weak self] convId, msgs, allowsTools in
                guard let self else { return LLMConfig.default }
                return self.resolveRequestConfig(
                    conversationId: convId,
                    messages: msgs,
                    allowsTools: allowsTools,
                    conversationVM: conversationVM,
                    agentSessionConfig: agentSessionConfig,
                    llmService: llmService
                )
            },
            prepareTools: {
                toolService.languagePreference = projectVM.languagePreference
                let availableTools = ToolAvailabilityGuard().evaluate(
                    tools: toolService.tools,
                    allowsTools: agentSessionConfig.chatMode.allowsTools,
                    isFinalStep: false
                )
                return availableTools.isEmpty ? nil : availableTools
            },
            sendStreamingMessage: { messages, config, tools, onChunk, onRequestStart in
                try await llmService.sendStreamingMessage(
                    messages: messages,
                    config: config,
                    tools: tools,
                    onChunk: onChunk,
                    onRequestStart: onRequestStart
                )
            },
            applyStreamChunk: { convId, chunk in
                statusVM.applyStreamChunk(conversationId: convId, chunk: chunk)
            },
            setStatus: { convId, content in
                statusVM.setStatus(conversationId: convId, content: content)
            },
            runPostPipeline: { metadata, response, error, duration in
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
            },
            logInfo: { message in
        if AgentSendPipelineLog.enabled {
                    AgentSendPipelineLog.logger.info("\(AgentSendPipelineLog.t)④ [MessageSender] \(message)")
                }
            },
            logError: { message in
        if AgentSendPipelineLog.enabled {
                    AgentSendPipelineLog.logger.info("\(AgentSendPipelineLog.t)④ [MessageSender] ❌ \(message)")
                }
            },
            resolveRetryDecision: { [weak self] conversationId, error, statusCode, attempt in
                guard let self else { return .doNotRetry }
                guard let providerId = self.currentProviderId(for: conversationId),
                      let provider = llmService.createProvider(id: providerId) else {
                    return ProviderRetryDecision(shouldRetry: false)
                }
                return provider.retryDecision(
                    for: error,
                    statusCode: statusCode,
                    attempt: attempt,
                    maxAttempts: StreamRetryPolicy.default.maxRetries
                )
            },
        )
    }

    func evaluateToolPermissions(for message: ChatMessage, conversationId: UUID) -> ChatMessage {
        windowContainer.toolCallExecutor.evaluatePermissions(
            for: message,
            conversationId: conversationId
        )
    }

    func currentProviderId(for conversationId: UUID) -> String? {
        windowContainer.conversationVM.resolveModelConfig(
            for: conversationId,
            fallbackConfigProvider: container.agentSessionConfig
        ).providerId
    }

    func buildLLMErrorMessage(_ error: Error, conversationId: UUID, providerId: String?) -> ChatMessage {
        let rawDetail = Self.extractRawErrorDetail(from: error)

        if let providerId,
           let provider = container.llmService.createProvider(id: providerId),
           let custom = provider.buildErrorChatMessage(
               error: error,
               conversationId: conversationId,
               rawDetail: rawDetail
           ) {
            return custom
        }

        var errorMessage: ChatMessage
        if let llmError = error as? LLMServiceError {
            errorMessage = llmError.toChatMessage(conversationId: conversationId, providerId: providerId)
            errorMessage.rawErrorDetail = rawDetail
        } else {
            errorMessage = ChatMessage(
                role: .assistant,
                conversationId: conversationId,
                content: error.localizedDescription,
                isError: true,
                rawErrorDetail: rawDetail
            )
        }
        return errorMessage
    }

    private func resolveContextWindowSize(for conversationId: UUID) -> Int? {
        let config = windowContainer.conversationVM.resolveModelConfig(
            for: conversationId,
            fallbackConfigProvider: container.agentSessionConfig
        )
        return container.llmService.allProviders()
            .first(where: { $0.id == config.providerId })?
            .contextWindowSizes[config.model]
    }

    private func resolveLastInputTokens(for conversationId: UUID) -> Int? {
        guard let messages = container.chatHistoryService.loadMessages(forConversationId: conversationId) else {
            return nil
        }
        return messages.last(where: { $0.role == .assistant })?.inputTokens
    }

    private func resolveRequestConfig(
        conversationId: UUID,
        messages: [ChatMessage],
        allowsTools: Bool,
        conversationVM: WindowConversationVM,
        agentSessionConfig: AppLLMVM,
        llmService: LLMService
    ) -> LLMConfig {
        let fallback = conversationVM.resolveModelConfig(
            for: conversationId,
            fallbackConfigProvider: agentSessionConfig
        )

        let config: LLMConfig
        if conversationVM.getModelPreference(for: conversationId) != nil {
            agentSessionConfig.lastAutoRouteSummary = nil
            config = fallback
        } else if agentSessionConfig.isAutoMode {
            let signal = RouteSignal(
                hasImages: messages.contains { !$0.images.isEmpty },
                messageLength: messages.reduce(0) { $0 + $1.content.count },
                allowsTools: allowsTools,
                currentProviderId: fallback.providerId,
                currentModel: fallback.model
            )

            let candidates = collectRouteCandidates(
                signal: signal,
                allowsTools: allowsTools,
                llmService: llmService
            )

            let router = ModelRouter()
            if let decision = router.route(candidates: candidates, signal: signal) {
                config = LLMConfig(model: decision.model, providerId: decision.providerId)
                agentSessionConfig.lastAutoRouteSummary =
                    "\(decision.providerDisplayName) · \(decision.model)（\(decision.reason)）"
            } else {
                agentSessionConfig.lastAutoRouteSummary = "Auto 未找到可用候选，已使用当前选择"
                config = fallback
            }
        } else {
            agentSessionConfig.lastAutoRouteSummary = nil
            config = fallback
        }

        if AgentSendPipelineLog.enabled {
            AgentSendPipelineLog.logger.info("\(AgentSendPipelineLog.t)[\(AgentSendPipelineLog.conv(conversationId))] 🎯 [RouteConfig] auto=\(agentSessionConfig.isAutoMode) fallback=\(fallback.providerId)/\(fallback.model) → \(config.providerId)/\(config.model)")
        }
        return config
    }

    private func collectRouteCandidates(
        signal: RouteSignal,
        allowsTools: Bool,
        llmService: LLMService
    ) -> [RouteCandidate] {
        let availabilityStore = LLMModelAvailabilityStore.shared

        return llmService.allProviders().flatMap { provider -> [RouteCandidate] in
            guard provider.isEnabled else { return [] }

            if !provider.isLocal,
               llmService.providerType(forId: provider.id)?.hasApiKey != true {
                return []
            }

            return provider.availableModels.compactMap { model -> RouteCandidate? in
                guard Self.passesCapabilities(
                    provider: provider,
                    model: model,
                    hasImages: signal.hasImages,
                    allowsTools: allowsTools,
                    llmService: llmService
                ) else {
                    return nil
                }

                let status = availabilityStore.status(providerId: provider.id, modelId: model)
                if case .unavailable = status { return nil }

                let candidateAvailability: CandidateAvailability
                switch status {
                case .available: candidateAvailability = .available
                case .checking: candidateAvailability = .checking
                case .unknown, nil: candidateAvailability = .unknown
                case .unavailable: return nil
                }

                return RouteCandidate(
                    providerId: provider.id,
                    providerDisplayName: provider.displayName,
                    model: model,
                    availability: candidateAvailability,
                    contextWindowSizes: provider.contextWindowSizes
                )
            }
        }
    }

    private static func passesCapabilities(
        provider: LLMProviderInfo,
        model: String,
        hasImages: Bool,
        allowsTools: Bool,
        llmService: LLMService
    ) -> Bool {
        if provider.isLocal { return true }
        guard let caps = llmService.providerType(forId: provider.id)?.modelCapabilities[model] else {
            return !hasImages && !allowsTools
        }
        if hasImages && !caps.supportsVision { return false }
        if allowsTools && !caps.supportsTools { return false }
        return true
    }


    private static func extractRawErrorDetail(from error: Error) -> String? {
        if let llmError = error as? LLMServiceError,
           case let .requestFailed(_, statusCode) = llmError,
           let statusCode {
            return "HTTP \(statusCode)"
        }
        if let apiError = error as? HTTPClientError,
           case let .httpError(statusCode, message) = apiError {
            return "HTTP \(statusCode)\n\(message)"
        }
        return nil
    }
}
