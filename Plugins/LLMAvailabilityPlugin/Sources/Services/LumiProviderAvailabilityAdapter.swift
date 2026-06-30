import Foundation
import LLMKit
import LLMProviderKit
import LumiCoreKit
import LumiLLMProviderSupport

// MARK: - 适配器：将 [any LumiLLMProvider] 适配为 LLMAvailabilityLLMServicing

/// 将新架构的 `[any LumiLLMProvider]` 列表适配为 `LLMAvailabilityLLMServicing`，
/// 让 `LLMAvailabilityChecker` 能直接检测新架构供应商。
public struct LumiProviderAvailabilityAdapter: LLMAvailabilityLLMServicing {
    private let providers: [any LumiLLMProvider]

    public init(providers: [any LumiLLMProvider]) {
        self.providers = providers
    }

    // MARK: - LLMAvailabilityLLMServicing

    public func allProviders() -> [LLMProviderInfo] {
        providers.map { provider in
            let info = type(of: provider).info
            return LLMProviderInfo(
                id: info.id,
                displayName: info.displayName,
                shortName: info.displayName,
                description: info.description,
                websiteURL: info.websiteURL.absoluteString,
                availableModels: info.availableModels,
                defaultModel: info.defaultModel,
                isLocal: info.isLocal,
                isEnabled: true,
                contextWindowSizes: info.contextWindowSizes
            )
        }
    }

    public func providerType(forId providerId: String) -> (any LLMAvailabilityProviderType)? {
        guard let provider = provider(forId: providerId) else { return nil }
        return LumiProviderTypeAdapter(provider: provider)
    }

    public func createProvider(id providerId: String) -> (any LLMAvailabilityCheckingProvider)? {
        guard let provider = provider(forId: providerId) else { return nil }
        return LumiCheckingProviderAdapter(provider: provider)
    }

    public func sendMessage(
        messages: [ChatMessage],
        config: LLMConfig
    ) async throws -> ChatMessage {
        guard let provider = provider(forId: config.providerId) else {
            throw LLMServiceError.providerNotFound(providerId: config.providerId)
        }

        // 将 LLMKit 的 ChatMessage 转换为 LumiCoreKit 的 LumiChatMessage
        let lumiMessages = messages.map { msg in
            LumiChatMessage(
                conversationID: UUID(),
                role: msg.role == .user ? .user : .assistant,
                content: msg.content
            )
        }

        let request = LumiLLMRequest(
            messages: lumiMessages,
            model: config.model,
            tools: []
        )

        let response = try await provider.send(request)

        return ChatMessage(
            role: .assistant,
            content: response.content
        )
    }

    // MARK: - Private

    private func provider(forId id: String) -> (any LumiLLMProvider)? {
        providers.first { type(of: $0).info.id == id }
    }
}

// MARK: - Provider Type Adapter

/// 适配单个供应商的 API Key 状态。
private struct LumiProviderTypeAdapter: LLMAvailabilityProviderType {
    let provider: any LumiLLMProvider

    var hasApiKey: Bool {
        let info = type(of: provider).info
        if info.isLocal { return true }

        guard let storageKey = info.apiKeyStorageKey else { return false }
        let key = LumiAPIKeyStore.shared.loadMigratingLegacyUserDefaults(forKey: storageKey)
        return key != nil && !(key?.isEmpty ?? true)
    }

    func getApiKey() -> String {
        let info = type(of: provider).info
        let storageKey = info.apiKeyStorageKey ?? ""
        return LumiAPIKeyStore.shared.loadMigratingLegacyUserDefaults(forKey: storageKey) ?? ""
    }
}

// MARK: - Checking Provider Adapter

/// 将 `LumiLLMProvider.checkAvailability` 桥接到可用性检测策略。
private struct LumiCheckingProviderAdapter: LLMAvailabilityCheckingProvider {
    let provider: any LumiLLMProvider

    func availabilityCheckStrategy(forModel modelId: String) -> AvailabilityCheckStrategy {
        .custom { _, model in
            switch await provider.checkAvailability(model: model) {
            case .available:
                return (true, nil)
            case .unavailable(let failure):
                return (false, failure)
            }
        }
    }
}
