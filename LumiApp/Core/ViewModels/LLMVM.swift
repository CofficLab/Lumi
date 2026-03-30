import Foundation
import MagicKit

@MainActor
final class LLMVM: ObservableObject, SuperLLMConfigProvider {
    @Published var selectedProviderId: String = "" {
        didSet {
            guard selectedProviderId != oldValue else { return }
            ensureProviderAndModelSelection()
        }
    }
    @Published var currentModel: String = "" {
        didSet {
            guard currentModel != oldValue else { return }
            if currentModel.isEmpty {
                ensureProviderAndModelSelection()
            }
        }
    }

    /// 聊天模式
    @Published var chatMode: ChatMode = .build

    let llmService: LLMService
    private var isAutoSelecting = false

    init(llmService: LLMService) {
        self.llmService = llmService
        ensureProviderAndModelSelection()
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

    // MARK: - Chat Mode

    func setChatMode(_ mode: ChatMode) {
        chatMode = mode
    }

    // MARK: - Selection Guard

    /// 确保始终存在有效的「供应商 + 模型」组合：
    /// 1) 当前供应商有效且模型为空/无效时，为该供应商自动挑一个模型
    /// 2) 当前供应商无效或为空时，自动挑选第一个有模型的供应商及模型
    func ensureProviderAndModelSelection() {
        guard !isAutoSelecting else { return }
        isAutoSelecting = true
        defer { isAutoSelecting = false }

        let providers = llmService.allProviders()
        guard !providers.isEmpty else { return }

        if let selectedProvider = providers.first(where: { $0.id == selectedProviderId }),
           let resolvedModel = resolveModel(for: selectedProvider, preferredModel: currentModel) {
            if currentModel != resolvedModel {
                currentModel = resolvedModel
            }
            return
        }

        guard let fallbackProvider = providers.first(where: { resolveModel(for: $0, preferredModel: nil) != nil }),
              let fallbackModel = resolveModel(for: fallbackProvider, preferredModel: nil) else {
            return
        }

        if selectedProviderId != fallbackProvider.id {
            selectedProviderId = fallbackProvider.id
        }
        if currentModel != fallbackModel {
            currentModel = fallbackModel
        }
    }

    private func resolveModel(for provider: LLMProviderInfo, preferredModel: String?) -> String? {
        let models = provider.availableModels
        guard !models.isEmpty else { return nil }

        if let preferredModel, !preferredModel.isEmpty, models.contains(preferredModel) {
            return preferredModel
        }
        if models.contains(provider.defaultModel) {
            return provider.defaultModel
        }
        return models.first
    }
}
