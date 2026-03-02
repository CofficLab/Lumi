import Combine
import Foundation
import OSLog
import SwiftData

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
                NotificationCenter.default.post(name: .conversationSelected, object: id)
            } else {
                UserDefaults.standard.removeObject(forKey: "Agent_SelectedConversationId")
            }
        }
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

    // MARK: - 初始化

    private init() {
        loadPreferences()
    }

    // MARK: - 会话选择

    /// 选择指定会话
    func selectConversation(_ id: UUID) {
        selectedConversationId = id
        if Self.verbose {
            os_log("[AgentProvider] 已选择会话：\(id)")
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
                    os_log("[AgentProvider] 上次选择的会话已不存在，清除保存状态")
                    UserDefaults.standard.removeObject(forKey: "Agent_SelectedConversationId")
                    return
                }
                // 会话存在，恢复选择
                selectedConversationId = uuid
                os_log("[AgentProvider] 已恢复会话选择：\(uuid)")
            } catch {
                os_log("[AgentProvider] 验证会话失败：\(error.localizedDescription)")
            }
        } else {
            // 没有 modelContext，直接恢复（可能在初始化阶段）
            selectedConversationId = uuid
            os_log("[AgentProvider] 已恢复会话选择（未验证）: \(uuid)")
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
            os_log("[AgentProvider] 已切换到项目：\(projectName) (\(path))")
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
        projects.removeAll { $0.path == path }

        let newProject = RecentProject(name: name, path: path, lastUsed: Date())
        projects.insert(newProject, at: 0)
        projects = Array(projects.prefix(5))

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
            os_log("[AgentProvider] 已选择文件：\(url.lastPathComponent)")
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

    // MARK: - 日志

    nonisolated static let verbose = true
}

// MARK: - Notification Names

extension Notification.Name {
    static let conversationSelected = Notification.Name("conversationSelected")
}
