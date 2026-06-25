import AgentToolKit
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
        guard provider(forId: providerId) != nil else { return nil }
        return LumiCheckingProviderAdapter()
    }

    public func sendMessage(
        messages: [ChatMessage],
        config: LLMConfig,
        tools: [SuperAgentTool]?
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
        // 本地供应商始终视为有凭证
        let info = type(of: provider).info
        if info.isLocal { return true }

        // 远程供应商检查 Keychain 中是否有 API Key
        let storageKey = LumiLLMProviderKeys.apiKeyStorageKey(forProviderID: info.id) ?? "DevAssistant_ApiKey_\(info.id)"
        let key = LumiAPIKeyStore.shared.loadMigratingLegacyUserDefaults(forKey: storageKey)
        return key != nil && !(key?.isEmpty ?? true)
    }

    func getApiKey() -> String {
        let info = type(of: provider).info
        let storageKey = LumiLLMProviderKeys.apiKeyStorageKey(forProviderID: info.id) ?? "DevAssistant_ApiKey_\(info.id)"
        return LumiAPIKeyStore.shared.loadMigratingLegacyUserDefaults(forKey: storageKey) ?? ""
    }
}

// MARK: - Checking Provider Adapter

/// 默认的可用性检测策略适配器。
/// 如果供应商自身实现了 `availabilityCheckStrategy`，则委托给它；
/// 否则使用 `apiKeyOnly` 策略（仅检查 API Key 是否配置）。
private struct LumiCheckingProviderAdapter: LLMAvailabilityCheckingProvider {
    func availabilityCheckStrategy(forModel modelId: String) -> AvailabilityCheckStrategy {
        // 默认策略：仅检查 API Key 是否已配置，不发网络请求
        // 供应商可通过实现 availabilityCheckStrategy 来自定义（如 Codex/MLX）
        .apiKeyOnly
    }
}
