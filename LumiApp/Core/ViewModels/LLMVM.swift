import Foundation
import MagicKit

/// Agent 会话配置管理：负责供应商/模型/API Key 等配置的状态管理。
///
/// 注意：本类只管理内存中的配置状态，不涉及持久化存储。
/// 需要持久化时，由调用方自行决定保存到项目配置还是全局配置。
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

    // MARK: - LLMProviderRegistry 功能暴露

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
