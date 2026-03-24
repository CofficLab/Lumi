import Foundation
import MagicKit

@MainActor
final class LLMVM: ObservableObject, SuperLLMConfigProvider {
    @Published var selectedProviderId: String = ""
    @Published var currentModel: String = ""
    
    let llmService: LLMService

    init(llmService: LLMService) {
        self.llmService = llmService
    }

    var availableProviders: [LLMProviderInfo] {
        llmService.allProviders()
    }

    /// 获取所有已注册供应商的信息
    /// - Returns: 供应商信息数组
    var allProviders: [LLMProviderInfo] {
        llmService.allProviders()
    }

    /// 根据 ID 查找供应商类型
    /// - Parameter id: 供应商 ID
    /// - Returns: 供应商类型，如果未找到则返回 nil
    func providerType(forId id: String) -> (any SuperLLMProvider.Type)? {
        llmService.providerType(forId: id)
    }

    /// 创建供应商实例
    /// - Parameter id: 供应商 ID
    /// - Returns: 供应商实例，如果未找到则返回 nil
    func createProvider(id: String) -> (any SuperLLMProvider)? {
        llmService.createProvider(id: id)
    }

    // MARK: - 配置管理

    func getCurrentConfig() -> LLMConfig {
        guard selectedProviderId.isNotEmpty,
              let providerType = llmService.providerType(forId: selectedProviderId),
              llmService.createProvider(id: selectedProviderId) != nil else {
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
        guard let providerType = llmService.providerType(forId: providerId) else {
            return ""
        }
        return APIKeyStore.shared.string(forKey: providerType.apiKeyStorageKey) ?? ""
    }

    func setApiKey(_ apiKey: String, for providerId: String) {
        guard let providerType = llmService.providerType(forId: providerId) else {
            return
        }
        APIKeyStore.shared.set(apiKey, forKey: providerType.apiKeyStorageKey)
    }
}
