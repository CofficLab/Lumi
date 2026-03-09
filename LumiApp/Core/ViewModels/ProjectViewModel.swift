import Foundation
import SwiftUI
import AppKit
import OSLog
import MagicKit

/// 项目管理 ViewModel
/// 负责管理项目状态、文件选择和项目配置
@MainActor
final class ProjectViewModel: ObservableObject, SuperLog {
    nonisolated static let emoji = "📁"
    nonisolated static let verbose = false

    // MARK: - 项目信息

    /// 当前项目名称
    @Published public fileprivate(set) var currentProjectName: String = ""

    /// 当前项目路径
    @Published public fileprivate(set) var currentProjectPath: String = ""

    /// 是否已选择项目
    @Published public fileprivate(set) var isProjectSelected: Bool = false

    // MARK: - 项目配置

    /// 当前项目的供应商 ID
    @Published public fileprivate(set) var currentProviderId: String = "anthropic"

    /// 当前项目的模型名称
    @Published public fileprivate(set) var currentModel: String = ""

    // MARK: - 文件选择

    /// 当前选择的文件 URL
    @Published public fileprivate(set) var selectedFileURL: URL?

    /// 当前选择的文件路径
    @Published public fileprivate(set) var selectedFilePath: String = ""

    /// 当前选择的文件内容
    @Published public fileprivate(set) var selectedFileContent: String = ""

    /// 是否已选择文件
    @Published public fileprivate(set) var isFileSelected: Bool = false

    // MARK: - 语言偏好

    @Published var languagePreference: LanguagePreference = .chinese

    // MARK: - 聊天模式

    @Published var chatMode: ChatMode = .build

    // MARK: - 自动批准风险

    @Published var autoApproveRisk: Bool = false

    // MARK: - 初始化

    private let contextService: ContextService

    init(contextService: ContextService = ContextService()) {
        self.contextService = contextService
        loadLanguagePreference()
        loadChatMode()
        loadAutoApproveRisk()
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

        setCurrentProjectInfo(name: projectName, path: path, selected: true)

        UserDefaults.standard.set(path, forKey: "Agent_SelectedProject")
        saveRecentProject(name: projectName, path: path)

        // 获取并应用项目配置
        let config = ProjectConfigStore.shared.getOrCreateConfig(for: path)
        applyProjectConfig(config)

        Task {
            await contextService.setProjectRoot(projectURL)
        }

        if Self.verbose {
            os_log("\(Self.t)📁 已切换项目：\(projectName)")
        }
    }

    /// 设置当前项目信息
    func setCurrentProjectInfo(name: String, path: String, selected: Bool) {
        Task { @MainActor in
            self.currentProjectName = name
            self.currentProjectPath = path
            self.isProjectSelected = selected
        }
    }

    /// 应用项目配置
    func applyProjectConfig(_ config: ProjectConfig) {
        // 更新当前项目配置
        currentProviderId = config.providerId
        currentModel = config.model.isEmpty ? getDefaultModel(for: config.providerId) : config.model

        // 通知供应商设置更新配置
        NotificationCenter.default.post(
            name: NSNotification.Name("ProjectConfigApplied"),
            object: config
        )

        if Self.verbose {
            os_log("\(Self.t)⚙️ 已应用项目配置：\(config.providerId) / \(self.currentModel)")
        }
    }

    /// 获取项目配置
    func getProjectConfig(for path: String) -> ProjectConfig {
        ProjectConfigStore.shared.getOrCreateConfig(for: path)
    }

    /// 保存项目配置
    func saveProjectConfig(path: String, providerId: String, model: String) {
        let config = ProjectConfig(
            projectPath: path,
            providerId: providerId,
            model: model
        )
        ProjectConfigStore.shared.saveConfig(config)

        // 如果是当前项目，更新本地状态
        if path == currentProjectPath {
            currentProviderId = providerId
            currentModel = model
        }

        if Self.verbose {
            os_log("\(Self.t)💾 已保存项目配置：\(providerId) / \(model)")
        }
    }

    /// 获取指定供应商的默认模型
    private func getDefaultModel(for providerId: String) -> String {
        let registry = ProviderRegistry()
        guard let providerType = registry.providerType(forId: providerId) else {
            return ""
        }
        return providerType.defaultModel
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

    /// 设置文件信息
    func setSelectedFileInfo(url: URL?, path: String, content: String, selected: Bool) {
        selectedFileURL = url
        selectedFilePath = path
        selectedFileContent = content
        isFileSelected = selected

        // 发送文件选择变化通知
        NotificationCenter.default.post(name: NSNotification.Name("AgentProviderFileSelectionChanged"), object: nil)
    }

    /// 设置文件内容
    func setSelectedFileContent(_ content: String) {
        selectedFileContent = content
    }

    /// 清除文件选择
    func clearFileSelection() {
        setSelectedFileInfo(url: nil, path: "", content: "", selected: false)
    }

    // MARK: - 语言偏好

    private func loadLanguagePreference() {
        if let data = UserDefaults.standard.data(forKey: "Agent_LanguagePreference"),
           let preference = try? JSONDecoder().decode(LanguagePreference.self, from: data) {
            languagePreference = preference
        }
    }

    func setLanguagePreference(_ preference: LanguagePreference) {
        languagePreference = preference
        if let encoded = try? JSONEncoder().encode(languagePreference) {
            UserDefaults.standard.set(encoded, forKey: "Agent_LanguagePreference")
        }
    }

    // MARK: - 聊天模式

    private func loadChatMode() {
        if let rawValue = UserDefaults.standard.string(forKey: "Agent_ChatMode"),
           let mode = ChatMode(rawValue: rawValue) {
            chatMode = mode
        }
    }

    func setChatMode(_ mode: ChatMode) {
        chatMode = mode
        UserDefaults.standard.set(chatMode.rawValue, forKey: "Agent_ChatMode")
    }

    // MARK: - 自动批准风险

    /// 加载自动批准风险设置
    private func loadAutoApproveRisk() {
        autoApproveRisk = UserDefaults.standard.bool(forKey: "Agent_AutoApproveRisk")
    }

    func setAutoApproveRisk(_ enabled: Bool) {
        autoApproveRisk = enabled
        UserDefaults.standard.set(enabled, forKey: "Agent_AutoApproveRisk")
    }
}
