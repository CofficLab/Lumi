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

    @Published public fileprivate(set) var currentProject: Project? = nil

    /// 当前项目名称
    var currentProjectName: String {
        self.currentProject?.name ?? ""
    }

    /// 当前项目路径
    var currentProjectPath: String {
        self.currentProject?.path ?? ""
    }

    /// 是否已选择项目
    var isProjectSelected: Bool {
        self.currentProject != nil
    }

    /// 当前项目的供应商 ID
    @Published public fileprivate(set) var currentProviderId: String = ""

    /// 当前项目的模型名称
    @Published public fileprivate(set) var currentModel: String = ""

    /// 当前选择的文件 URL
    @Published public fileprivate(set) var selectedFileURL: URL?

    /// 当前选择的文件内容
    @Published public fileprivate(set) var selectedFileContent: String = ""

    /// 是否已选择文件（计算属性）
    var isFileSelected: Bool {
        selectedFileURL != nil
    }

    // 语言偏好
    @Published var languagePreference: LanguagePreference = .chinese

    // 聊天模式
    @Published var chatMode: ChatMode = .build

    // 自动批准风险
    @Published var autoApproveRisk: Bool = false

    /// 最近使用的项目列表
    @Published public fileprivate(set) var recentProjects: [Project] = []

    // MARK: - 初始化

    private let contextService: ContextService
    private let llmService: LLMService

    private static let globalConfigProviderIdKey = "Agent_GlobalProviderId"
    private static let globalConfigModelKey = "Agent_GlobalModel"

    /// 初始化 ProjectVM
    /// - Parameters:
    ///   - contextService: 上下文服务（必须由外部传入）
    ///   - llmService: LLM 服务（必须由外部传入，不允许自行创建）
    init(
        contextService: ContextService,
        llmService: LLMService
    ) {
        self.contextService = contextService
        self.llmService = llmService
        loadGlobalOrDefaultProviderIfNeeded()
        restoreAutoApproveRiskIfNeeded()
    }

    // MARK: - 项目管理

    /// 清除当前项目，恢复到未选择任何项目的状态
    func clearProject() {
        clearFileSelection()

        Task {
            await contextService.setProjectRoot(nil)
        }

        if Self.verbose {
            AppLogger.core.info("\(Self.t)📁 已清除当前项目")
        }
    }

    /// 切换到指定项目
    func switchProject(to project: Project) {
        self.currentProject = project
    }

    /// 获取指定供应商的默认模型
    private func getDefaultModel(for providerId: String) -> String {
        // 通过 LLMService 获取供应商类型
        guard let providerType = llmService.providerType(forId: providerId) else {
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

        // 通过 LLMService 获取所有供应商
        let providers = llmService.allProviders()
        if let firstProvider = providers.first {
            currentProviderId = firstProvider.id
            currentModel = firstProvider.availableModels.first ?? ""
        }
    }

    /// 加载全局 LLM 配置（未选择项目时使用），若不存在则回退到默认供应商
    private func loadGlobalOrDefaultProviderIfNeeded() {
        // 已经由项目配置覆盖，直接跳过
        guard currentProviderId.isEmpty, currentModel.isEmpty else { return }

        // 全局配置不存在时，按原有规则初始化默认供应商和模型
        initializeDefaultProviderIfNeeded()
    }

    /// 在未选择项目时，保存全局供应商 ID
    func setGlobalProviderId(_ providerId: String) {
        currentProviderId = providerId
    }

    /// 在未选择项目时，保存全局模型名称
    func setGlobalModel(_ model: String) {
        currentModel = model
    }

    // MARK: - 最近项目管理

    /// 设置最近项目列表（由 AgentRecentProjectsPlugin 调用）
    func setRecentProjects(_ projects: [Project]) {
        recentProjects = projects
    }

    /// 获取最近项目列表
    func getRecentProjects() -> [Project] {
        recentProjects
    }

    // MARK: - 文件选择

    /// 选择指定路径（支持文件与目录）
    func selectFile(at url: URL) {
        let isDirectory = (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false

        // 目录：仅更新选中路径，不加载内容
        if isDirectory {
            setSelectedFileInfo(url: url, content: "")

            if Self.verbose {
                AppLogger.core.info("\(Self.t)📁 已选择目录：\(url.lastPathComponent)")
            }
        } else {
            setSelectedFileInfo(url: url, content: "")

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
    func setSelectedFileInfo(url: URL?, content: String) {
        selectedFileURL = url
        selectedFileContent = content

        // 发送文件选择变化通知
        NotificationCenter.postFileSelectionChanged()
    }

    /// 设置文件内容
    func setSelectedFileContent(_ content: String) {
        selectedFileContent = content
    }

    /// 清除文件选择
    func clearFileSelection() {
        setSelectedFileInfo(url: nil, content: "")
    }

    // MARK: - 语言偏好

    func setLanguagePreference(_ preference: LanguagePreference) {

    }

    // MARK: - 聊天模式

    func setChatMode(_ mode: ChatMode) {

    }

    func setAutoApproveRisk(_ enabled: Bool) {
        autoApproveRisk = enabled
        persistAutoApproveRisk(enabled)
    }

    // MARK: - Auto-approve persistence
    ///
    /// 目前 `autoApproveRisk` 的持久化逻辑在 UI 层由 `AutoApprovePersistenceOverlay` 承担；
    /// 但如果该 overlay 在某些启动路径没有挂载/恢复，就会导致开关在重启后失效。
    /// 为保证行为稳定，这里直接读写同一份状态文件。
    private static let autoApproveStatePlistKey = "autoApproveRisk"
    private static let autoApproveStateFileName = "auto_approve_state.plist"
    private static let autoApproveStateTmpFileName = "auto_approve_state.tmp"

    private func autoApproveStateSettingsDir() -> URL {
        AppConfig.getDBFolderURL()
            .appendingPathComponent("AgentAutoApproveHeader", isDirectory: true)
            .appendingPathComponent("settings", isDirectory: true)
    }

    private func autoApproveStateFileURL() -> URL {
        autoApproveStateSettingsDir()
            .appendingPathComponent(Self.autoApproveStateFileName, isDirectory: false)
    }

    private func restoreAutoApproveRiskIfNeeded() {
        guard let enabled = loadAutoApproveRiskFromDisk() else { return }
        autoApproveRisk = enabled
    }

    private func loadAutoApproveRiskFromDisk() -> Bool? {
        let fileURL = autoApproveStateFileURL()
        let fileManager = FileManager.default

        guard fileManager.fileExists(atPath: fileURL.path) else { return nil }
        guard let data = try? Data(contentsOf: fileURL),
              let plist = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil),
              let dict = plist as? [String: Any] else {
            return nil
        }

        if let boolVal = dict[Self.autoApproveStatePlistKey] as? Bool {
            return boolVal
        }

        // propertyListSerialization 有时会把 bool 以 NSNumber 形式还原
        if let numVal = dict[Self.autoApproveStatePlistKey] as? NSNumber {
            return numVal.boolValue
        }

        return nil
    }

    private func persistAutoApproveRisk(_ enabled: Bool) {
        let fileManager = FileManager.default
        let settingsDir = autoApproveStateSettingsDir()
        try? fileManager.createDirectory(at: settingsDir, withIntermediateDirectories: true, attributes: nil)

        let fileURL = autoApproveStateFileURL()
        let tmpURL = settingsDir.appendingPathComponent(Self.autoApproveStateTmpFileName, isDirectory: false)

        var dict: [String: Any] = [:]
        if fileManager.fileExists(atPath: fileURL.path),
           let data = try? Data(contentsOf: fileURL),
           let plist = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil),
           let existing = plist as? [String: Any] {
            dict = existing
        }

        dict[Self.autoApproveStatePlistKey] = enabled

        guard let data = try? PropertyListSerialization.data(fromPropertyList: dict, format: .binary, options: 0) else { return }
        do {
            try data.write(to: tmpURL, options: .atomic)
            if fileManager.fileExists(atPath: fileURL.path) {
                _ = try? fileManager.replaceItemAt(fileURL, withItemAt: tmpURL)
            } else {
                try fileManager.moveItem(at: tmpURL, to: fileURL)
            }
        } catch {
            // 写入失败时不影响内存状态；下一次启动仍会以默认值为准
        }
    }
}