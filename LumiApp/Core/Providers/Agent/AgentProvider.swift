import Combine
import MagicKit
import Foundation
import OSLog
import SwiftData

/// Agent 模式提供者，管理 Agent 模式下的核心状态和服务
@MainActor
final class AgentProvider: ObservableObject, SuperLog {
    nonisolated static let emoji = "🤖"
    nonisolated static let verbose = false

    /// 全局单例
    static let shared = AgentProvider()

    // MARK: - 服务依赖

    /// 聊天历史服务
    let chatHistoryService = ChatHistoryService.shared

    /// 提示词服务
    let promptService = PromptService.shared

    /// 供应商注册表
    let registry = ProviderRegistry.shared

    /// LLM 服务
    let llmService = LLMService.shared

    /// 工具管理器
    let toolManager = ToolManager.shared

    // MARK: - 项目信息

    /// 当前项目名称
    @Published var currentProjectName: String = ""

    /// 当前项目路径
    @Published var currentProjectPath: String = ""

    /// 是否已选择项目
    @Published var isProjectSelected: Bool = false

    // MARK: - 当前选择的文件

    /// 当前选择的文件 URL
    @Published var selectedFileURL: URL?

    /// 当前选择的文件路径
    @Published var selectedFilePath: String = ""

    /// 当前选择的文件内容
    @Published var selectedFileContent: String = ""

    /// 是否已选择文件
    @Published var isFileSelected: Bool = false

    // MARK: - 当前选择的会话

    /// 当前选择的会话 ID
    @Published var selectedConversationId: UUID? {
        didSet {
            if let id = selectedConversationId {
                UserDefaults.standard.set(id.uuidString, forKey: "Agent_SelectedConversationId")
                // 通知加载对话
                NotificationCenter.postConversationSelected(conversationId: id)
            } else {
                UserDefaults.standard.removeObject(forKey: "Agent_SelectedConversationId")
            }
        }
    }
    
    /// 设置选中会话 ID
    func setSelectedConversationId(_ id: UUID) {
        selectedConversationId = id
        UserDefaults.standard.set(id.uuidString, forKey: "Agent_SelectedConversationId")
    }

    // MARK: - 语言偏好

    @Published var languagePreference: LanguagePreference = .chinese {
        didSet {
            if let encoded = try? JSONEncoder().encode(languagePreference) {
                UserDefaults.standard.set(encoded, forKey: "Agent_LanguagePreference")
            }
        }
    }

    // MARK: - 聊天模式

    @Published var chatMode: ChatMode = .build {
        didSet {
            UserDefaults.standard.set(chatMode.rawValue, forKey: "Agent_ChatMode")
        }
    }

    // MARK: - 自动批准风险

    @Published var autoApproveRisk: Bool = {
        UserDefaults.standard.bool(forKey: "Agent_AutoApproveRisk")
    }() {
        didSet {
            UserDefaults.standard.set(autoApproveRisk, forKey: "Agent_AutoApproveRisk")
        }
    }

    // MARK: - 供应商选择

    @Published var selectedProviderId: String = "anthropic" {
        didSet {
            UserDefaults.standard.set(selectedProviderId, forKey: "Agent_SelectedProvider")
        }
    }

    /// 当前选择的模型
    @Published var selectedModel: String = "" {
        didSet {
            UserDefaults.standard.set(selectedModel, forKey: "Agent_SelectedModel")
        }
    }

    // MARK: - 对话历史管理

    /// 当前对话会话
    @Published var currentConversation: Conversation?

    /// 标记是否已生成标题
    var hasGeneratedTitle: Bool = false

    // MARK: - 初始化

    private init() {
        loadPreferences()
    }

    // MARK: - 对话管理

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

        if Self.verbose {
            os_log("\(Self.t)✅ [\(newConversation.id)] 已创建新会话")
        }

        currentConversation = newConversation
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

        currentConversation = conversation

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

    // MARK: - 会话选择

    /// 选择指定会话
    func selectConversation(_ id: UUID) {
        selectedConversationId = id
        if Self.verbose {
            os_log("\(Self.t)已选择会话：\(id)")
        }
    }

    /// 清除会话选择
    func clearConversationSelection() {
        selectedConversationId = nil
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
                selectedConversationId = uuid
                if Self.verbose {
                    os_log("\(Self.t)✅ 已恢复会话选择：\(uuid)")
                }
            } catch {
                os_log(.error, "\(Self.t)❌ 验证会话失败：\(error.localizedDescription)")
            }
        } else {
            // 没有 modelContext，直接恢复（可能在初始化阶段）
            selectedConversationId = uuid
            if Self.verbose {
                os_log("\(Self.t)ℹ️ 已恢复会话选择（未验证）: \(uuid)")
            }
        }
    }

    // MARK: - 项目管理

    /// 切换到指定项目
    func switchProject(to path: String) {
        let projectURL = URL(fileURLWithPath: path)

        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: path, isDirectory: &isDirectory),
              isDirectory.boolValue else {
            return
        }

        let projectName = projectURL.lastPathComponent

        currentProjectName = projectName
        currentProjectPath = path
        isProjectSelected = true

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
        if !config.providerId.isEmpty {
            selectedProviderId = config.providerId
        }

        if !config.model.isEmpty {
            selectedModel = config.model
        }
        
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

    // MARK: - 文件选择

    /// 选择指定文件
    func selectFile(at url: URL) {
        selectedFileURL = url
        selectedFilePath = url.path
        isFileSelected = true

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
                selectedFileContent = content
            }
        } catch {
            await MainActor.run {
                selectedFileContent = "无法加载文件内容：\(error.localizedDescription)"
            }
            os_log(.error, "\(Self.t)❌ 加载文件失败：\(error.localizedDescription)")
        }
    }

    /// 清除文件选择
    func clearFileSelection() {
        selectedFileURL = nil
        selectedFilePath = ""
        selectedFileContent = ""
        isFileSelected = false
    }

    /// 加载保存的偏好设置
    private func loadPreferences() {
        // 加载语言偏好
        if let data = UserDefaults.standard.data(forKey: "Agent_LanguagePreference"),
           let preference = try? JSONDecoder().decode(LanguagePreference.self, from: data) {
            languagePreference = preference
        }

        // 加载聊天模式
        if let modeRaw = UserDefaults.standard.string(forKey: "Agent_ChatMode"),
           let mode = ChatMode(rawValue: modeRaw) {
            chatMode = mode
        }

        // 加载自动批准风险
        autoApproveRisk = UserDefaults.standard.bool(forKey: "Agent_AutoApproveRisk")

        // 加载供应商选择
        selectedProviderId = UserDefaults.standard.string(forKey: "Agent_SelectedProvider") ?? "anthropic"

        // 加载模型选择
        selectedModel = UserDefaults.standard.string(forKey: "Agent_SelectedModel") ?? ""

        // 加载上次选择的项目
        if let savedPath = UserDefaults.standard.string(forKey: "Agent_SelectedProject") {
            switchProject(to: savedPath)
        }

        // 注意：会话选择不在此处恢复，因为需要等待 SwiftData 初始化完成
        // 应该在视图获取到 modelContext 后调用 restoreSelectedConversation
    }
}
