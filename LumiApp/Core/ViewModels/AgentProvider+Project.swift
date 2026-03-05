import Foundation
import SwiftUI
import AppKit
import OSLog
import SwiftData
import Combine
import MagicKit

// MARK: - 项目管理（协调 ProjectViewModel）

extension AgentProvider {
    /// 切换到指定项目
    func switchProject(to path: String) {
        projectViewModel.switchProject(to: path)

        if Self.verbose {
            os_log("\(Self.t)📁 已切换项目：\(self.projectViewModel.currentProjectName)")
        }
    }

    /// 应用项目配置
    func applyProjectConfig(_ config: ProjectConfig) {
        setSelectedProviderId(config.providerId)
        setSelectedModel(config.model)

        if Self.verbose {
            os_log("\(Self.t)⚙️ 已应用项目配置")
        }
    }

    /// 保存当前项目配置
    func saveCurrentProjectConfig() {
        guard projectViewModel.isProjectSelected,
              !projectViewModel.currentProjectPath.isEmpty else { return }

        projectViewModel.saveProjectConfig(
            path: projectViewModel.currentProjectPath,
            providerId: selectedProviderId,
            model: selectedModel
        )
    }

    /// 获取最近使用的项目列表
    func getRecentProjects() -> [RecentProject] {
        projectViewModel.getRecentProjects()
    }
}

// MARK: - 文件选择（协调 ProjectViewModel）

extension AgentProvider {
    /// 选择指定文件
    func selectFile(at url: URL) {
        projectViewModel.selectFile(at: url)
    }

    /// 清除文件选择
    func clearFileSelection() {
        projectViewModel.clearFileSelection()
    }
}

// MARK: - 供应商配置

extension AgentProvider {
    /// 获取可用供应商列表
    var availableProviders: [ProviderInfo] {
        registry.allProviders()
    }

    /// 获取可用工具列表
    var tools: [AgentTool] {
        toolManager.tools
    }

    /// 获取当前供应商配置
    func getCurrentConfig() -> LLMConfig {
        guard let providerType = registry.providerType(forId: selectedProviderId),
              registry.createProvider(id: selectedProviderId) != nil else {
            return LLMConfig.default
        }

        // 从 UserDefaults 获取 API Key
        let apiKey = UserDefaults.standard.string(forKey: providerType.apiKeyStorageKey) ?? ""

        // 从 UserDefaults 获取选中的模型
        let selectedModel = UserDefaults.standard.string(forKey: providerType.modelStorageKey) ?? providerType.defaultModel

        return LLMConfig(
            apiKey: apiKey,
            model: selectedModel,
            providerId: selectedProviderId
        )
    }

    /// 获取当前选中的模型名称
    var currentModel: String {
        guard let providerType = registry.providerType(forId: selectedProviderId) else {
            return ""
        }
        return UserDefaults.standard.string(forKey: providerType.modelStorageKey) ?? providerType.defaultModel
    }

    /// 获取指定供应商的 API Key
    func getApiKey(for providerId: String) -> String {
        guard let providerType = registry.providerType(forId: providerId) else {
            return ""
        }
        return UserDefaults.standard.string(forKey: providerType.apiKeyStorageKey) ?? ""
    }

    /// 设置指定供应商的 API Key
    func setApiKey(_ apiKey: String, for providerId: String) {
        guard let providerType = registry.providerType(forId: providerId) else {
            return
        }
        UserDefaults.standard.set(apiKey, forKey: providerType.apiKeyStorageKey)
        if Self.verbose {
            os_log("\(Self.t) 已设置 \(providerType.displayName) 的 API Key")
        }
    }
}
