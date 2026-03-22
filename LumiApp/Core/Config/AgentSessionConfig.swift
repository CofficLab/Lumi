import Foundation
import MagicKit

/// 窗口内 LLM 供应商/模型/API Key 等与 `ProjectVM` + `ProviderRegistry` 相关的配置（供设置类 UI 使用）。
@MainActor
final class AgentSessionConfig: ObservableObject, SuperLLMConfigProvider {
    let projectVM: ProjectVM
    let registry: LLMProviderRegistry
    let chatHistoryService: ChatHistoryService

    init(projectVM: ProjectVM, registry: LLMProviderRegistry, chatHistoryService: ChatHistoryService) {
        self.projectVM = projectVM
        self.registry = registry
        self.chatHistoryService = chatHistoryService
    }

    var selectedProviderId: String { projectVM.currentProviderId }
    var currentModel: String { projectVM.currentModel }

    var availableProviders: [LLMProviderInfo] {
        registry.allProviders()
    }

    func getCurrentConfig() -> LLMConfig {
        guard let providerType = registry.providerType(forId: selectedProviderId),
              registry.createProvider(id: selectedProviderId) != nil else {
            return LLMConfig.default
        }

        let apiKey = APIKeyStore.shared.getWithMigration(
            forKey: providerType.apiKeyStorageKey,
            legacyLoad: { PluginStateStore.shared.string(forKey: providerType.apiKeyStorageKey) },
            legacyCleanup: {
                PluginStateStore.shared.removeObject(forKey: $0)
                PluginStateStore.shared.removeLegacyValue(forKey: $0)
            }
        )

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
        return APIKeyStore.shared.getWithMigration(
            forKey: providerType.apiKeyStorageKey,
            legacyLoad: { PluginStateStore.shared.string(forKey: providerType.apiKeyStorageKey) },
            legacyCleanup: {
                PluginStateStore.shared.removeObject(forKey: $0)
                PluginStateStore.shared.removeLegacyValue(forKey: $0)
            }
        )
    }

    func setApiKey(_ apiKey: String, for providerId: String) {
        guard let providerType = registry.providerType(forId: providerId) else {
            return
        }
        APIKeyStore.shared.set(apiKey, forKey: providerType.apiKeyStorageKey)
        PluginStateStore.shared.removeObject(forKey: providerType.apiKeyStorageKey)
        PluginStateStore.shared.removeLegacyValue(forKey: providerType.apiKeyStorageKey)
    }

    func setSelectedProviderId(_ providerId: String) {
        if projectVM.isProjectSelected, !projectVM.currentProjectPath.isEmpty {
            projectVM.saveProjectConfig(
                path: projectVM.currentProjectPath,
                providerId: providerId,
                model: currentModel
            )
        } else {
            projectVM.setGlobalProviderId(providerId)
        }
    }

    func setSelectedModel(_ model: String) {
        if projectVM.isProjectSelected, !projectVM.currentProjectPath.isEmpty {
            projectVM.saveProjectConfig(
                path: projectVM.currentProjectPath,
                providerId: selectedProviderId,
                model: model
            )
        } else {
            projectVM.setGlobalModel(model)
        }
    }
}
