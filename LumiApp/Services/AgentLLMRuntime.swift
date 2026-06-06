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

    func makeLLMSendService() -> LLMSendService {
        LiveLLMSendService(runtime: self, container: container, windowContainer: windowContainer)
    }

    func resolveLLMConfig(
        for conversationId: UUID,
        messages: [ChatMessage],
        allowsTools: Bool
    ) -> LLMConfig {
        resolveRequestConfig(
            conversationId: conversationId,
            messages: messages,
            allowsTools: allowsTools,
            conversationVM: windowContainer.conversationVM,
            agentSessionConfig: container.agentSessionConfig,
            llmService: container.llmService
        )
    }


    func currentProviderId(for conversationId: UUID) -> String? {
        windowContainer.conversationVM.resolveModelConfig(
            for: conversationId,
            fallbackConfigProvider: container.agentSessionConfig
        ).providerId
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

}
