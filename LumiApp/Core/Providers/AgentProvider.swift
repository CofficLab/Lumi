import Combine
import Foundation
import OSLog

/// Agent 模式提供者，管理 Agent 模式下的核心状态和服务
@MainActor
final class AgentProvider: ObservableObject {
    /// 全局单例
    static let shared = AgentProvider()

    // MARK: - 项目信息

    /// 当前项目名称
    @Published var currentProjectName: String = ""

    /// 当前项目路径
    @Published var currentProjectPath: String = ""

    /// 是否已选择项目
    @Published var isProjectSelected: Bool = false

    // MARK: - 语言偏好

    @Published var languagePreference: LanguagePreference = .chinese {
        didSet {
            // 保存到 UserDefaults
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

    // MARK: - 初始化

    private init() {
        loadPreferences()
    }

    // MARK: - 项目管理

    /// 切换到指定项目
    func switchProject(to path: String) {
        let projectURL = URL(fileURLWithPath: path)

        // 验证路径是否存在
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: path, isDirectory: &isDirectory),
              isDirectory.boolValue else {
            return
        }

        let projectName = projectURL.lastPathComponent

        currentProjectName = projectName
        currentProjectPath = path
        isProjectSelected = true

        // 保存到 UserDefaults（记住上次选择的项目）
        UserDefaults.standard.set(path, forKey: "Agent_SelectedProject")

        // 保存到最近使用列表
        saveRecentProject(name: projectName, path: path)

        // 获取或创建项目配置
        let config = ProjectConfigStore.shared.getOrCreateConfig(for: path)

        // 应用项目配置
        applyProjectConfig(config)

        // 更新 ContextService
        Task {
            await ContextService.shared.setProjectRoot(projectURL)
        }

        if Self.verbose {
            os_log("[AgentProvider] 已切换到项目：\(projectName) (\(path))")
        }
    }

    /// 应用项目配置
    func applyProjectConfig(_ config: ProjectConfig) {
        // 切换供应商
        if !config.providerId.isEmpty {
            selectedProviderId = config.providerId
        }

        // 切换模型
        if !config.model.isEmpty {
            selectedModel = config.model
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
    }

    /// 保存最近使用的项目
    private func saveRecentProject(name: String, path: String) {
        var projects = getRecentProjects()

        // 移除已存在的同名项目
        projects.removeAll { $0.path == path }

        // 添加新项目到开头
        let newProject = RecentProject(name: name, path: path, lastUsed: Date())
        projects.insert(newProject, at: 0)

        // 只保留最近 5 个
        projects = Array(projects.prefix(5))

        // 保存到 UserDefaults
        if let data = try? JSONEncoder().encode(projects) {
            UserDefaults.standard.set(data, forKey: "Agent_RecentProjects")
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
    }

    // MARK: - 日志

    nonisolated static let verbose = true
}
