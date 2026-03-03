import Foundation
import SwiftUI
import AppKit
import OSLog
import SwiftData

// MARK: - 会话选择

extension AgentProvider {
    /// 选择指定会话
    func selectConversation(_ id: UUID) {
        setSelectedConversationId(id)
        if Self.verbose {
            os_log("\(Self.t) 已选择会话：\(id)")
        }
    }

    /// 清除会话选择
    func clearConversationSelection() {
        clearSelectedConversationId()
    }

    /// 恢复上次选择的会话（需要验证会话是否存在）
    func restoreSelectedConversation(modelContext: ModelContext?) {
        guard let savedId = UserDefaults.standard.string(forKey: "Agent_SelectedConversationId"),
              let uuid = UUID(uuidString: savedId) else {
            return
        }

        // 如果有 modelContext，验证会话是否存在
        if let context = modelContext {
            let descriptor = FetchDescriptor<Conversation>(
                predicate: #Predicate { $0.id == uuid }
            )

            do {
                let conversations = try context.fetch(descriptor)
                if conversations.isEmpty {
                    // 会话已不存在，清除保存的 ID
                    if Self.verbose {
                        os_log("\(Self.t)⚠️ 上次选择的会话已不存在，清除保存状态")
                    }
                    UserDefaults.standard.removeObject(forKey: "Agent_SelectedConversationId")
                    return
                }
                // 会话存在，恢复选择
                setSelectedConversationId(uuid)
                if Self.verbose {
                    os_log("\(Self.t)✅ 已恢复会话选择：\(uuid)")
                }
            } catch {
                os_log(.error, "\(Self.t)❌ 验证会话失败：\(error.localizedDescription)")
            }
        } else {
            // 没有 modelContext，直接恢复（可能在初始化阶段）
            setSelectedConversationId(uuid)
            if Self.verbose {
                os_log("\(Self.t)ℹ️ 已恢复会话选择（未验证）: \(uuid)")
            }
        }
    }
}

// MARK: - 项目管理

extension AgentProvider {
    /// 切换到指定项目
    func switchProject(to path: String) {
        let projectURL = URL(fileURLWithPath: path)

        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: path, isDirectory: &isDirectory),
              isDirectory.boolValue else {
            return
        }

        let projectName = projectURL.lastPathComponent

        setCurrentProjectInfo(name: projectName, path: path, selected: true)

        UserDefaults.standard.set(path, forKey: "Agent_SelectedProject")
        saveRecentProject(name: projectName, path: path)

        let config = ProjectConfigStore.shared.getOrCreateConfig(for: path)
        applyProjectConfig(config)

        Task {
            await ContextService.shared.setProjectRoot(projectURL)
        }

        if Self.verbose {
            os_log("\(Self.t)📁 已切换项目：\(projectName)")
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

    /// 保存项目配置
    func saveCurrentProjectConfig() {
        guard isProjectSelected, !currentProjectPath.isEmpty else { return }

        let config = ProjectConfig(
            projectPath: currentProjectPath,
            providerId: selectedProviderId,
            model: selectedModel
        )
        ProjectConfigStore.shared.saveConfig(config)

        if Self.verbose {
            os_log("\(Self.t)💾 已保存项目配置")
        }
    }

    /// 保存最近使用的项目
    private func saveRecentProject(name: String, path: String) {
        var projects = getRecentProjects()
        projects.removeAll { $0.path == path }

        let newProject = RecentProject(name: name, path: path, lastUsed: Date())
        projects.insert(newProject, at: 0)
        projects = Array(projects.prefix(5))

        if let data = try? JSONEncoder().encode(projects) {
            UserDefaults.standard.set(data, forKey: "Agent_RecentProjects")
        }

        if Self.verbose {
            os_log("\(Self.t)📋 已保存最近项目：\(name)")
        }
    }

    /// 获取最近使用的项目列表
    func getRecentProjects() -> [RecentProject] {
        guard let data = UserDefaults.standard.data(forKey: "Agent_RecentProjects"),
              let projects = try? JSONDecoder().decode([RecentProject].self, from: data) else {
            return []
        }
        return projects
    }
}

// MARK: - 文件选择

extension AgentProvider {
    /// 选择指定文件
    func selectFile(at url: URL) {
        setSelectedFileInfo(url: url, path: url.path, content: "", selected: true)

        Task {
            await loadFileContent(from: url)
        }

        if Self.verbose {
            os_log("\(Self.t)📄 已选择文件：\(url.lastPathComponent)")
        }
    }

    /// 加载文件内容
    private func loadFileContent(from url: URL) async {
        do {
            let content = try String(contentsOf: url, encoding: .utf8)
            await MainActor.run {
                setSelectedFileContent(content)
            }
        } catch {
            await MainActor.run {
                setSelectedFileContent("无法加载文件内容：\(error.localizedDescription)")
            }
            os_log(.error, "\(Self.t)❌ 加载文件失败：\(error.localizedDescription)")
        }
    }

    /// 清除文件选择
    func clearFileSelection() {
        setSelectedFileInfo(url: nil, path: "", content: "", selected: false)
    }
}

// MARK: - 对话管理

extension AgentProvider {
    /// 创建新对话
    func createNewConversation() async {
        if Self.verbose {
            os_log("\(Self.t)🚀 开始创建新会话")
        }

        // 首先创建会话
        let projectId = isProjectSelected ? currentProjectPath : nil
        let formatter = DateFormatter()
        formatter.dateFormat = "MM-dd HH:mm"
        let newConversation = chatHistoryService.createConversation(
            projectId: projectId,
            title: "新会话 " + formatter.string(from: Date())
        )
        hasGeneratedTitle = false // 重置标题生成标记

        setCurrentConversationInternal(newConversation)
        setSelectedConversationId(newConversation.id)

        if Self.verbose {
            os_log("\(Self.t)✅ [\(newConversation.id)] 新会话创建完成")
        }
    }

    /// 保存消息到存储
    func saveMessage(_ message: ChatMessage) {
        guard let conversation = currentConversation else {
            if Self.verbose {
                os_log("\(Self.t)⚠️ 当前没有活动对话，跳过保存")
            }
            return
        }

        chatHistoryService.saveMessage(message, to: conversation)
    }

    /// 加载指定对话的消息
    func loadConversation(_ conversationId: UUID) async {
        if Self.verbose {
            os_log("\(Self.t)📥 [\(conversationId)] 开始加载对话")
        }

        // 从数据库获取对话
        guard let conversation = chatHistoryService.fetchConversation(id: conversationId) else {
            return
        }

        setCurrentConversationInternal(conversation)

        if Self.verbose {
            os_log("\(Self.t)✅ [\(conversation.id)] 对话加载完成")
        }
    }

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
