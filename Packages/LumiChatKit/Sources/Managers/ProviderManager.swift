import Foundation
import LumiCoreKit
import LLMKit

/// Manages LLM provider registration, model selection, and routing.
@MainActor
final class ProviderManager {
    private weak var service: ChatService?

    init(service: ChatService) {
        self.service = service
    }

    // MARK: - Provider Registration

    func registerProviders(_ providers: [any LumiLLMProvider]) {
        guard let service else { return }

        let uniqueProviders = providers.reduce(into: [String: any LumiLLMProvider]()) { result, provider in
            result[type(of: provider).info.id] = provider
        }
        service.providersByID = uniqueProviders
        service.providerInfos = uniqueProviders.values
            .map { type(of: $0).info }
            .sorted { $0.displayName.localizedStandardCompare($1.displayName) == .orderedAscending }

        reconcileSelectedProvider()
        service.persistStateOnly()
    }

    func provider(byID id: String) -> (any LumiLLMProvider)? {
        service?.providersByID[id]
    }

    // MARK: - Provider Selection

    func selectProvider(id: String, model: String? = nil) {
        selectProvider(id: id, model: model, for: service?.selectedConversationID)
    }

    func selectProvider(id: String, model: String?, for conversationID: UUID?) {
        guard let service,
              let info = service.providerInfos.first(where: { $0.id == id })
        else {
            return
        }

        let normalized = normalizedModel(model, for: info)
        service.selectedProviderID = info.id
        service.selectedModel = normalized

        if let conversationID,
           let index = service.conversations.firstIndex(where: { $0.id == conversationID }) {
            service.conversations[index].providerID = info.id
            service.conversations[index].modelName = normalized
            service.conversations[index].updatedAt = Date()
            // 增量持久化：对话属性 + 状态
            service.persistConversationAndState(service.conversations[index])
        } else {
            service.persistStateOnly()
        }
    }

    // MARK: - Model Resolution

    func providerID(for conversationID: UUID?) -> String? {
        guard let conversationID,
              let conversation = service?.conversations.first(where: { $0.id == conversationID }),
              let providerID = conversation.providerID
        else {
            return service?.selectedProviderID
        }
        return providerID
    }

    func modelName(for conversationID: UUID?) -> String? {
        guard let conversationID,
              let conversation = service?.conversations.first(where: { $0.id == conversationID }),
              let modelName = conversation.modelName
        else {
            return service?.selectedModel
        }
        return modelName
    }

    func routingMode() -> LumiModelRoutingMode {
        service?.routingMode ?? .manual
    }

    func setRoutingMode(_ mode: LumiModelRoutingMode) {
        service?.routingMode = mode
        service?.persistStateOnly()
    }

    // MARK: - Resolved Provider & Model (internal)

    func resolvedProvider(for conversationID: UUID) -> (any LumiLLMProvider)? {
        guard let service else { return nil }

        if service.routingMode == .auto {
            return autoRoutedProvider(for: conversationID)
        }

        if let providerID = providerID(for: conversationID),
           let provider = service.providersByID[providerID] {
            return provider
        }
        return self.selectedProvider
    }

    func resolvedModel(for conversationID: UUID, providerInfo: LumiLLMProviderInfo) -> String {
        guard let service else { return providerInfo.defaultModel }

        if service.routingMode == .auto,
           let decision = service.modelRouter.route(
               candidates: routeCandidates(),
               signal: routeSignal(for: conversationID)
           ),
           decision.providerId == providerInfo.id {
            return normalizedModel(decision.model, for: providerInfo)
        }

        return normalizedModel(modelName(for: conversationID), for: providerInfo)
    }

    // MARK: - Auto Routing

    private func autoRoutedProvider(for conversationID: UUID) -> (any LumiLLMProvider)? {
        guard let service, !service.providersByID.isEmpty else {
            return nil
        }

        guard let decision = service.modelRouter.route(
            candidates: routeCandidates(),
            signal: routeSignal(for: conversationID)
        ),
        let provider = service.providersByID[decision.providerId]
        else {
            let fallbackID = providerID(for: conversationID) ?? ""
            return service.providersByID[fallbackID] ?? service.providersByID.values.first
        }

        return provider
    }

    private func routeCandidates() -> [RouteCandidate] {
        guard let service else { return [] }
        return service.providerInfos.flatMap { info in
            info.availableModels.map { model in
                RouteCandidate(
                    providerId: info.id,
                    providerDisplayName: info.displayName,
                    model: model,
                    availability: .available,
                    contextWindowSizes: info.contextWindowSizes
                )
            }
        }
    }

    private func routeSignal(for conversationID: UUID) -> RouteSignal {
        guard let service else {
            return RouteSignal(hasImages: false, messageLength: 0, allowsTools: false, currentProviderId: "", currentModel: "")
        }

        let latestUserMessage = service.messages(for: conversationID).last(where: { $0.role == .user })
        return RouteSignal(
            hasImages: latestUserMessage?.metadata["hasImages"] == "true",
            messageLength: latestUserMessage?.content.count ?? 0,
            allowsTools: service.automationLevel(for: conversationID).allowsTools,
            currentProviderId: providerID(for: conversationID) ?? service.selectedProviderID ?? "",
            currentModel: modelName(for: conversationID) ?? service.selectedModel ?? ""
        )
    }

    // MARK: - Helpers

    private var selectedProvider: (any LumiLLMProvider)? {
        guard let service, let selectedProviderID = service.selectedProviderID else {
            return nil
        }
        return service.providersByID[selectedProviderID]
    }

    private func reconcileSelectedProvider() {
        guard let service else { return }

        guard !service.providerInfos.isEmpty else {
            service.selectedProviderID = nil
            service.selectedModel = nil
            return
        }

        if let selectedProviderID = service.selectedProviderID,
           let info = service.providerInfos.first(where: { $0.id == selectedProviderID }) {
            service.selectedModel = normalizedModel(service.selectedModel, for: info)
            return
        }

        let info = service.providerInfos[0]
        service.selectedProviderID = info.id
        service.selectedModel = info.defaultModel
    }

    func normalizedModel(_ model: String?, for info: LumiLLMProviderInfo) -> String {
        guard let model,
              info.availableModels.contains(model)
        else {
            return info.defaultModel
        }
        return model
    }
}
