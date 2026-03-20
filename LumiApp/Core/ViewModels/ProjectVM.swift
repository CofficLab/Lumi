import Foundation
import SwiftUI
import AppKit
import MagicKit

/// 项目管理 ViewModel
/// 负责管理项目状态、文件选择和项目配置
@MainActor
final class ProjectVM: ObservableObject, SuperLog {
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
    @Published public fileprivate(set) var currentProviderId: String = ""

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
    private let providerRegistry: ProviderRegistry?

    private static let globalConfigProviderIdKey = "Agent_GlobalProviderId"
    private static let globalConfigModelKey = "Agent_GlobalModel"

    init(
        contextService: ContextService = ContextService(),
        providerRegistry: ProviderRegistry? = nil
    ) {
        self.contextService = contextService
        self.providerRegistry = providerRegistry
        loadLanguagePreference()
        loadChatMode()
        loadGlobalOrDefaultProviderIfNeeded()
    }

    // MARK: - 项目管理

    /// 清除当前项目，恢复到未选择任何项目的状态
    func clearProject() {
        setCurrentProjectInfo(name: "", path: "", selected: false)
        PluginStateStore.shared.removeObject(forKey: "Agent_SelectedProject")
        clearFileSelection()

        Task {
            await contextService.setProjectRoot(nil)
        }

        if Self.verbose {
            AppLogger.core.info("\(Self.t)📁 已清除当前项目")
        }
    }

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

        PluginStateStore.shared.set(path, forKey: "Agent_SelectedProject")
        saveRecentProject(name: projectName, path: path)

        // 获取并应用项目配置
        let config = ProjectConfigStore.shared.getOrCreateConfig(for: path)
        applyProjectConfig(config)

        Task {
            await contextService.setProjectRoot(projectURL)
        }

        if Self.verbose {
            AppLogger.core.info("\(Self.t)📁 已切换项目：\(projectName)")
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
        Task { @MainActor in
            // 更新当前项目配置
            self.currentProviderId = config.providerId
            self.currentModel = config.model.isEmpty ? self.getDefaultModel(for: config.providerId) : config.model

            // 通知供应商设置更新配置
            NotificationCenter.postProjectConfigApplied(config)

            if Self.verbose {
                AppLogger.core.info("\(Self.t)⚙️ 已应用项目配置：\(config.providerId) / \(self.currentModel)")
            }
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
            AppLogger.core.info("\(Self.t)💾 已保存项目配置：\(providerId) / \(model)")
        }
    }

    /// 获取指定供应商的默认模型
    private func getDefaultModel(for providerId: String) -> String {
        // 优先使用注入的 ProviderRegistry（由插件系统填充）
        if let registry = providerRegistry,
           let providerType = registry.providerType(forId: providerId) {
            return providerType.defaultModel
        }

        // 兜底：本地扫描插件（用于 Preview / 测试等环境）
        let registry = ProviderRegistry()
        LLMPluginProviderRegistration.registerAllProviders(to: registry)
        guard let providerType = registry.providerType(forId: providerId) else {
            return ""
        }
        return providerType.defaultModel
    }

    /// 在未选择任何项目时，为 Agent 模式提供默认供应商和模型
    ///
    /// 规则：
    /// - 如果插件系统已注册供应商，选择第一个供应商及其默认模型
    /// - 如果没有任何供应商注册，则保持空值，Agent 模式将无法正常运行
    private func initializeDefaultProviderIfNeeded() {
        // 已经有值（例如稍后会通过项目配置覆盖）则不处理
        guard currentProviderId.isEmpty, currentModel.isEmpty else { return }

        // 优先使用注入的 ProviderRegistry
        if let registry = providerRegistry, let firstType = registry.providerTypes.first {
            currentProviderId = firstType.id
            currentModel = firstType.defaultModel
            return
        }

        // 兜底：本地扫描插件（用于 Preview / 测试等环境）
        let registry = ProviderRegistry()
        LLMPluginProviderRegistration.registerAllProviders(to: registry)
        if let firstType = registry.providerTypes.first {
            currentProviderId = firstType.id
            currentModel = firstType.defaultModel
        }
    }

    /// 加载全局 LLM 配置（未选择项目时使用），若不存在则回退到默认供应商
    private func loadGlobalOrDefaultProviderIfNeeded() {
        // 已经由项目配置覆盖，直接跳过
        guard currentProviderId.isEmpty, currentModel.isEmpty else { return }

        // 尝试读取全局配置
        let globalProviderId = PluginStateStore.shared.string(forKey: Self.globalConfigProviderIdKey)
        let globalModel = PluginStateStore.shared.string(forKey: Self.globalConfigModelKey)

        if let pid = globalProviderId, !pid.isEmpty,
           let model = globalModel, !model.isEmpty {
            currentProviderId = pid
            currentModel = model
            return
        }

        // 全局配置不存在时，按原有规则初始化默认供应商和模型
        initializeDefaultProviderIfNeeded()
    }

    /// 在未选择项目时，保存全局供应商 ID
    func setGlobalProviderId(_ providerId: String) {
        currentProviderId = providerId
        PluginStateStore.shared.set(providerId, forKey: Self.globalConfigProviderIdKey)
    }

    /// 在未选择项目时，保存全局模型名称
    func setGlobalModel(_ model: String) {
        currentModel = model
        PluginStateStore.shared.set(model, forKey: Self.globalConfigModelKey)
    }

    /// 保存最近使用的项目
    private func saveRecentProject(name: String, path: String) {
        var projects = getRecentProjects()
        projects.removeAll { $0.path == path }

        let newProject = RecentProject(name: name, path: path, lastUsed: Date())
        projects.insert(newProject, at: 0)
        projects = Array(projects.prefix(5))

        if let data = try? JSONEncoder().encode(projects) {
            PluginStateStore.shared.set(data, forKey: "Agent_RecentProjects")
        }

        if Self.verbose {
            AppLogger.core.info("\(Self.t)📋 已保存最近项目：\(name)")
        }
    }

    /// 获取最近使用的项目列表
    func getRecentProjects() -> [RecentProject] {
        guard let data = PluginStateStore.shared.data(forKey: "Agent_RecentProjects"),
              let projects = try? JSONDecoder().decode([RecentProject].self, from: data) else {
            return []
        }
        return projects
    }

    // MARK: - 文件选择

    /// 选择指定路径（支持文件与目录）
    func selectFile(at url: URL) {
        let isDirectory = (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
        
        // 目录：仅更新选中路径，不加载内容
        if isDirectory {
            setSelectedFileInfo(url: url, path: url.path, content: "", selected: false)
            
            if Self.verbose {
                AppLogger.core.info("\(Self.t)📁 已选择目录：\(url.lastPathComponent)")
            }
        } else {
            setSelectedFileInfo(url: url, path: url.path, content: "", selected: true)
            
            Task {
                await contextService.trackOpenFile(url)
                await loadFileContent(from: url)
            }
            
            if Self.verbose {
                AppLogger.core.info("\(Self.t)📄 已选择文件：\(url.lastPathComponent)")
            }
        }
    }
    
    /// 将指定文件或目录移到废纸篓
    /// - Parameter url: 目标文件或目录路径
    func deleteItem(at url: URL) {
        do {
            try FileManager.default.trashItem(at: url, resultingItemURL: nil)
            if Self.verbose {
                AppLogger.core.info("\(Self.t)🗑️ 已移到废纸篓：\(url.lastPathComponent)")
            }
        } catch {
            AppLogger.core.error("\(Self.t)❌ 移到废纸篓失败：\(error.localizedDescription)")
        }
    }
    
    /// 在 Finder 中显示指定路径
    /// - Parameter url: 目标文件或目录路径
    func openInFinder(_ url: URL) {
        NSWorkspace.shared.activateFileViewerSelecting([url])
        
        if Self.verbose {
            AppLogger.core.info("\(Self.t)🔍 在 Finder 中显示：\(url.path)")
        }
    }
    
    /// 在 VS Code 中打开指定路径
    /// - Parameter url: 目标文件或目录路径
    func openInVSCode(_ url: URL) {
        let process = Process()
        process.launchPath = "/usr/bin/env"
        process.arguments = ["open", "-a", "Visual Studio Code", url.path]
        
        do {
            try process.run()
            if Self.verbose {
                AppLogger.core.info("\(Self.t)📝 使用 VS Code 打开：\(url.path)")
            }
        } catch {
            AppLogger.core.error("\(Self.t)❌ 启动 VS Code 失败：\(error.localizedDescription)")
        }
    }
    
    /// 在终端中打开指定路径
    /// - Parameter url: 目标文件或目录路径（文件会自动转为其父目录）
    func openInTerminal(_ url: URL) {
        let targetURL: URL
        let isDirectory = (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
        if isDirectory {
            targetURL = url
        } else {
            targetURL = url.deletingLastPathComponent()
        }
        
        let process = Process()
        process.launchPath = "/usr/bin/env"
        process.arguments = ["open", "-a", "Terminal", targetURL.path]
        
        do {
            try process.run()
            if Self.verbose {
                AppLogger.core.info("\(Self.t)💻 在终端中打开：\(targetURL.path)")
            }
        } catch {
            AppLogger.core.error("\(Self.t)❌ 启动终端失败：\(error.localizedDescription)")
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
            AppLogger.core.error("\(Self.t)❌ 加载文件失败：\(error.localizedDescription)")
        }
    }

    /// 设置文件信息
    func setSelectedFileInfo(url: URL?, path: String, content: String, selected: Bool) {
        selectedFileURL = url
        selectedFilePath = path
        selectedFileContent = content
        isFileSelected = selected

        // 发送文件选择变化通知
        NotificationCenter.postFileSelectionChanged()
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
        if let data = PluginStateStore.shared.data(forKey: "Agent_LanguagePreference"),
           let preference = try? JSONDecoder().decode(LanguagePreference.self, from: data) {
            Task { @MainActor in
                self.languagePreference = preference
            }
        }
    }

    func setLanguagePreference(_ preference: LanguagePreference) {
        Task { @MainActor in
            self.languagePreference = preference
            if let encoded = try? JSONEncoder().encode(self.languagePreference) {
                PluginStateStore.shared.set(encoded, forKey: "Agent_LanguagePreference")
            }
        }
    }

    // MARK: - 聊天模式

    private func loadChatMode() {
        if let rawValue = PluginStateStore.shared.string(forKey: "Agent_ChatMode"),
           let mode = ChatMode(rawValue: rawValue) {
            Task { @MainActor in
                self.chatMode = mode
            }
        }
    }

    func setChatMode(_ mode: ChatMode) {
        Task { @MainActor in
            self.chatMode = mode
            PluginStateStore.shared.set(self.chatMode.rawValue, forKey: "Agent_ChatMode")
        }
    }

    // MARK: - 自动批准风险

    /// 加载自动批准风险设置（持久化由插件负责）
    private func loadAutoApproveRisk() {
        // no-op
    }

    func setAutoApproveRisk(_ enabled: Bool) {
        Task { @MainActor in
            self.autoApproveRisk = enabled
        }
    }
}
