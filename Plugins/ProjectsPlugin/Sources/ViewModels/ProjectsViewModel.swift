import Combine
import Foundation
import LumiCoreKit
import os
import SuperLogKit

/// 项目视图模型，持有状态并暴露 Intent 给视图。
/// 
/// 职责：
/// - 从 Store 加载初始状态
/// - 持有 @Published 状态供视图观察
/// - 暴露 Intent 方法供视图调用
/// - 调用 Store 持久化数据
/// 
/// 注意：ViewModel 不直接与 LumiCore 交互，同步逻辑由 ProjectsSyncCoordinator 负责。
@MainActor
public final class ProjectsViewModel: ObservableObject, SuperLog {
    public nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.projects.viewmodel")
    public nonisolated static let emoji = "📊"
    public static var verbose = false

    // MARK: - Published State

    @Published public private(set) var projects: [LumiProjectEntry]
    @Published public private(set) var currentProject: LumiProjectEntry? {
        didSet {
            if Self.verbose {
                Self.logger.info("\(Self.t)currentProject 变化: \(oldValue?.name ?? "nil") → \(self.currentProject?.name ?? "nil")")
            }
        }
    }

    // MARK: - Dependencies

    private let store: ProjectsStore

    // MARK: - Init

    public init(store: ProjectsStore) {
        if Self.verbose {
            Self.logger.info("\(Self.t)初始化开始")
        }

        self.store = store

        // 从 Store 加载初始状态
        self.projects = store.loadProjects()
        self.currentProject = store.loadCurrentProject(from: projects)

        if Self.verbose {
            Self.logger.info("\(Self.t)初始化完成, 项目数量: \(self.projects.count), 当前项目: \(self.currentProject?.name ?? "nil")")
        }
    }

    // MARK: - Intents

    /// 选中项目：更新状态并持久化
    public func select(_ project: LumiProjectEntry) {
        if Self.verbose {
            Self.logger.info("\(Self.t)select: \(project.name) @ \(project.path)")
        }

        let updatedProjects = store.selectProject(project, in: projects)
        let updatedProject = LumiProjectEntry(name: project.name, path: project.path)

        self.projects = updatedProjects
        self.currentProject = updatedProject

        // 持久化
        store.save(projects: projects, currentProject: currentProject)
    }

    /// 添加项目
    @discardableResult
    public func add(path: String, select shouldSelect: Bool = false) throws -> LumiProjectEntry {
        if Self.verbose {
            Self.logger.info("\(Self.t)add: \(path), select: \(shouldSelect)")
        }

        let project = try store.add(path: path, to: projects)

        if shouldSelect {
            select(project)
        } else {
            self.projects = store.addProject(project, to: projects)
            if currentProject == nil {
                currentProject = projects.first
            }
            store.save(projects: projects, currentProject: currentProject)
        }

        return project
    }

    /// 移除项目
    public func remove(_ project: LumiProjectEntry) {
        if Self.verbose {
            Self.logger.info("\(Self.t)remove: \(project.name) @ \(project.path)")
        }

        self.projects = store.removeProject(project, from: projects)

        if currentProject?.path == project.path {
            currentProject = projects.first
        }

        store.save(projects: projects, currentProject: currentProject)
    }

    /// 设置当前项目路径
    public func setCurrentProjectPath(_ path: String) {
        if Self.verbose {
            Self.logger.info("\(Self.t)setCurrentProjectPath: \(path)")
        }

        let trimmed = path.trimmingCharacters(in: .whitespacesAndNewlines)

        // 空/空白路径 → "无项目"态
        guard !trimmed.isEmpty else {
            currentProject = nil
            store.save(projects: projects, currentProject: currentProject)
            return
        }

        // 标准化路径
        let normalized = ProjectsStore.normalizedPath(trimmed)

        // 查找已存在的项目
        if let existing = projects.first(where: { $0.path == normalized }) ?? projects.first(where: { $0.path == trimmed }) {
            select(existing)
            return
        }

        // 项目不在列表中：构造条目并选中
        let entry = LumiProjectEntry(name: ProjectsStore.directoryName(for: normalized), path: normalized)
        select(entry)
    }

    /// 便捷方法：通过路径添加项目
    @discardableResult
    public func addProject(path: String, select shouldSelect: Bool = false) throws -> LumiProjectEntry {
        try add(path: path, select: shouldSelect)
    }

    /// 便捷方法：通过 URL 添加并选项目
    public func addProject(url: URL) {
        _ = try? add(path: url.path, select: true)
    }
}
