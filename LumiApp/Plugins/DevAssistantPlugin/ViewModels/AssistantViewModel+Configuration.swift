import Foundation
import MagicKit
import OSLog

// MARK: - 配置管理（API Key、模型、供应商）

extension AssistantViewModel {
    // MARK: - 配置管理

    /// 获取当前供应商的配置
    func getCurrentConfig() -> LLMConfig {
        AgentProvider.shared.getCurrentConfig()
    }

    /// 获取当前选中的模型名称
    var currentModel: String {
        AgentProvider.shared.currentModel
    }

    /// 更新选中供应商的模型
    func updateSelectedModel(_ model: String) {
        guard let providerType = AgentProvider.shared.registry.providerType(forId: selectedProviderId) else {
            return
        }
        UserDefaults.standard.set(model, forKey: providerType.modelStorageKey)
        if Self.verbose {
            os_log("\(self.t) 更新模型：\(providerType.displayName) -> \(model)")
        }
    }

    /// 保存当前模型到项目配置
    func saveCurrentModelToProjectConfig() {
        guard isProjectSelected, !currentProjectPath.isEmpty else {
            return
        }

        // 获取或创建项目配置
        let config = ProjectConfigStore.shared.getOrCreateConfig(for: currentProjectPath)

        // 更新配置
        var updatedConfig = config
        updatedConfig.providerId = selectedProviderId
        updatedConfig.model = currentModel

        // 保存
        ProjectConfigStore.shared.saveConfig(updatedConfig)

        if Self.verbose {
            os_log("\(self.t) 保存模型到项目配置：\(self.currentProjectName) -> \(self.currentModel)")
        }
    }

    /// 获取指定供应商的 API Key
    func getApiKey(for providerId: String) -> String {
        AgentProvider.shared.getApiKey(for: providerId)
    }

    /// 设置指定供应商的 API Key
    func setApiKey(_ apiKey: String, for providerId: String) {
        AgentProvider.shared.setApiKey(apiKey, for: providerId)
    }
}
