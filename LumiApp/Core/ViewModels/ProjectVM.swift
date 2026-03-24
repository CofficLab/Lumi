import AppKit
import Foundation
import MagicKit
import SwiftUI

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

    /// 是否已选择文件
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

    /// 初始化 ProjectVM
    /// - Parameters:
    ///   - contextService: 上下文服务（必须由外部传入）
    ///   - llmService: LLM 服务（必须由外部传入，不允许自行创建）
    init(contextService: ContextService, llmService: LLMService) {
        self.contextService = contextService
        self.llmService = llmService
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
        selectedFileURL = url

        // 发送文件选择变化通知
        NotificationCenter.postFileSelectionChanged()

        if Self.verbose {
            let isDirectory = (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
            if isDirectory {
                AppLogger.core.info("\(Self.t)📁 已选择目录：\(url.lastPathComponent)")
            } else {
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

    /// 清除文件选择
    func clearFileSelection() {
        selectedFileURL = nil

        // 发送文件选择变化通知
        NotificationCenter.postFileSelectionChanged()
    }

    // MARK: - 语言偏好

    func setLanguagePreference(_ preference: LanguagePreference) {
    }

    // MARK: - 聊天模式

    func setChatMode(_ mode: ChatMode) {
    }

    func setAutoApproveRisk(_ enabled: Bool) {
        autoApproveRisk = enabled
    }
}