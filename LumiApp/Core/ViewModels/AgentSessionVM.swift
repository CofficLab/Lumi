import Foundation
import MagicKit

/// Agent 会话配置管理：负责供应商/模型/API Key 等配置的状态管理。
///
/// 注意：本类只管理内存中的配置状态，不涉及持久化存储。
/// 需要持久化时，由调用方自行决定保存到项目配置还是全局配置。
@MainActor
final class AgentSessionVM: ObservableObject, SuperLLMConfigProvider {
    @Published var selectedProviderId: String = ""
    @Published var currentModel: String = ""
    
    let registry: LLMProviderRegistry

    init(registry: LLMProviderRegistry) {
        self.registry = registry
    }

    var availableProviders: [LLMProviderInfo] {
        registry.allProviders()
    }

    func getCurrentConfig() -> LLMConfig {
        guard selectedProviderId.isNotEmpty,
              let providerType = registry.providerType(forId: selectedProviderId),
              registry.createProvider(id: selectedProviderId) != nil else {
            return LLMConfig.default
        }

        let apiKey = APIKeyStore.shared.string(forKey: providerType.apiKeyStorageKey) ?? ""

        return LLMConfig(
            apiKey: apiKey,
            model: currentModel,
            providerId: selectedProviderId
        )
    }

    func getApiKey(for providerId: String) -> String {
        guard let providerType = registry.providerType(forId: providerId) else {
            return ""
        }
        return APIKeyStore.shared.string(forKey: providerType.apiKeyStorageKey) ?? ""
    }

    func setApiKey(_ apiKey: String, for providerId: String) {
        guard let providerType = registry.providerType(forId: providerId) else {
            return
        }
        APIKeyStore.shared.set(apiKey, forKey: providerType.apiKeyStorageKey)
    }
}