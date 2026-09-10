import Foundation
import os
import KitSuperLog
import ProviderProject

/// 项目视图模型，持有插件视图状态并暴露 Intent 给视图。
///
/// 职责：
/// - 缓存项目状态（经由 `ProjectsProjectCapability` 收窄的项目能力）供视图观察
/// - 暴露 Intent 方法供视图调用
/// - 调用 Store 持久化数据
///
/// 注意：项目列表和当前项目的唯一运行时来源是内核 Provider；ViewModel 通过
/// 插件自有的能力协议读写它，不直接持有 `ProjectProviding` 具体类型，
/// ViewModel 不向外提供另一套项目状态，只保存 Provider 的视图快照。
@MainActor
public final class ProjectsViewModel: ObservableObject, SuperLog {
    public nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.projects.viewmodel")
    public nonisolated static let emoji = "📊"
    public static var verbose = false

    // MARK: - Published State

    @Published public private(set) var projects: [ProjectEntry]
    @Published public private(set) var currentProject: ProjectEntry? {
        didSet {
            if Self.verbose {
                Self.logger.info("\(Self.t)currentProject 变化: \(oldValue?.name ?? "nil") → \(self.currentProject?.name ?? "nil")")
            }
        }
    }

    // MARK: - Dependencies

    public let store: ProjectsStore
    private let projectCapability: any ProjectsProjectCapability

    // MARK: - Init

    init(store: ProjectsStore, projectCapability: any ProjectsProjectCapability) {
        if Self.verbose {
            Self.logger.info("\(Self.t)初始化开始")
        }

        self.store = store
        self.projectCapability = projectCapability
        // 运行时状态从项目能力读取；Store 只由 ProjectsPlugin 在启动时
        // 用于恢复 Provider，并在 Provider 事件后保存快照。
        self.projects = []
        self.currentProject = nil

        if Self.verbose {
            Self.logger.info("\(Self.t)初始化完成, 项目数量: \(self.projects.count), 当前项目: \(self.currentProject?.name ?? "nil")")
        }
    }

    // MARK: - Intents

    /// 从项目能力同步插件所需的项目快照。
    ///
    /// 该方法只读取能力，不向 Provider 写回项目状态。
    func syncFromProvider(persist: Bool = true) {
        let previousByPath = Dictionary(
            uniqueKeysWithValues: projects.map { ($0.path, $0) }
        )
        let syncedProjects = projectCapability.projects.map { info in
            ProjectEntry(
                name: info.name,
                path: info.path,
                language: info.language,
                lastUsed: previousByPath[info.path]?.lastUsed ?? Date()
            )
        }

        projects = syncedProjects
        if let info = projectCapability.currentProject {
            currentProject = ProjectEntry(
                name: info.name,
                path: info.path,
                language: info.language,
                lastUsed: previousByPath[info.path]?.lastUsed ?? Date()
            )
        } else {
            currentProject = nil
        }

        if persist {
            persistAsync(projects: projects, currentProject: currentProject)
        }
    }

    /// 选中项目：请求项目能力打开项目。
    public func select(_ project: ProjectEntry) {
        if Self.verbose {
            Self.logger.info("\(Self.t)select: \(project.name) @ \(project.path)")
        }

        openProject(at: project.path)
    }

    /// 添加项目
    @discardableResult
    public func add(path: String, select shouldSelect: Bool = false) throws -> ProjectEntry {
        if Self.verbose {
            Self.logger.info("\(Self.t)add: \(path), select: \(shouldSelect)")
        }

        let project = try store.add(path: path, to: projects)
        let projectInfo = ProjectInfo(name: project.name, path: project.path, language: project.language)

        if shouldSelect {
            openProject(at: project.path)
        } else {
            var providerProjects = projectCapability.projects
            if !providerProjects.contains(where: { $0.path == projectInfo.path }) {
                providerProjects.insert(projectInfo, at: 0)
                projectCapability.synchronizeProjects(providerProjects)
            }
            if projectCapability.currentProject == nil, let first = providerProjects.first {
                openProject(at: first.path)
            }
        }

        return project
    }

    /// 移除项目
    public func remove(_ project: ProjectEntry) {
        if Self.verbose {
            Self.logger.info("\(Self.t)remove: \(project.name) @ \(project.path)")
        }

        let wasCurrentProject = projectCapability.currentProject?.path == project.path
        let remaining = projectCapability.projects.filter { $0.path != project.path }
        projectCapability.synchronizeProjects(remaining)

        if wasCurrentProject {
            if let first = remaining.first {
                openProject(at: first.path, reason: .projectRemoved)
            } else {
                Task { @MainActor [projectCapability] in
                    await projectCapability.closeProject(reason: .projectRemoved)
                }
            }
        }
    }

    /// 设置当前项目路径
    public func setCurrentProjectPath(_ path: String) {
        if Self.verbose {
            Self.logger.info("\(Self.t)setCurrentProjectPath: \(path)")
        }

        let trimmed = path.trimmingCharacters(in: .whitespacesAndNewlines)

        // 空/空白路径 → "无项目"态
        guard !trimmed.isEmpty else {
            Task { @MainActor [projectCapability] in
                await projectCapability.closeProject(reason: .settingsChange)
            }
            return
        }

        // 标准化路径
        let normalized = ProjectsStore.normalizedPath(trimmed)

        // 查找已存在的项目
        if let existing = projectCapability.projects.first(where: { $0.path == normalized }) ?? projectCapability.projects.first(where: { $0.path == trimmed }) {
            openProject(at: existing.path, reason: .settingsChange)
            return
        }

        // 项目不在列表中：构造条目并选中（探测一次语言，供插件按项目类型筛选工具）
        openProject(at: normalized, reason: .settingsChange)
    }

    /// 便捷方法：通过路径添加项目
    @discardableResult
    public func addProject(path: String, select shouldSelect: Bool = false) throws -> ProjectEntry {
        try add(path: path, select: shouldSelect)
    }

    /// 便捷方法：通过 URL 添加并选项目
    public func addProject(url: URL) {
        _ = try? add(path: url.path, select: true)
    }

    private func openProject(at path: String, reason: ProjectChangeReason = .userSelected) {
        Task { @MainActor [projectCapability] in
            do {
                try await projectCapability.openProject(at: path, reason: reason)
            } catch {
                Self.logger.error("\(Self.t)打开项目失败: \(error.localizedDescription)")
            }
        }
    }

    // MARK: - Persistence

    /// 将当前状态快照异步写入磁盘。
    ///
    /// 写入是全量快照（atomic），最终一致即可；放在后台线程执行以避免阻塞 UI。
    /// 在主 actor 上捕获快照值与 store 引用后下放，规避跨 actor 访问。
    private func persistAsync(projects: [ProjectEntry], currentProject: ProjectEntry?) {
        let store = self.store
        Task.detached(priority: .utility) {
            store.save(projects: projects, currentProject: currentProject)
        }
    }
}
