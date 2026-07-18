import Combine
import Foundation
import SuperLogKit
import os

/// LumiCore 项目状态管理器
/// 负责管理当前项目和项目列表的状态（内存存储）
@MainActor
public final class ProjectState: ObservableObject, SuperLog {
    public nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "core.project-state")
    public nonisolated static let emoji = "📂"
    public static var verbose = false

    // MARK: - 当前项目

    @Published public private(set) var currentProject: ProjectEntry? {
        didSet {
            if currentProject != oldValue {
                if Self.verbose {
                    Self.logger.info("\(Self.t)currentProject didSet: \(oldValue?.name ?? "nil") → \(self.currentProject?.name ?? "nil") @ \(self.currentProject?.path ?? "")")
                }
                if let project = currentProject {
                    NotificationCenter.postCurrentProjectDidChange(project: project)
                    if Self.verbose {
                        Self.logger.info("\(Self.t)发送 CurrentProjectDidChange 通知")
                    }
                }
            }
        }
    }

    // MARK: - 项目列表

    @Published public private(set) var projects: [ProjectEntry] = [] {
        didSet {
            if projects != oldValue {
                NotificationCenter.postProjectListDidChange()
            }
        }
    }

    // MARK: - 初始化

    public init() {}

    // MARK: - 公开方法

    /// 通过路径设置当前项目
    /// 如果项目不在列表中，会自动创建条目
    public func setCurrentProjectPath(_ path: String) {
        let trimmed = path.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmed.isEmpty else {
            currentProject = nil
            return
        }

        // 标准化路径
        let normalized = Self.normalizePath(trimmed)

        // 查找已存在的项目
        if let existing = projects.first(where: { $0.path == normalized }) {
            currentProject = existing
            return
        }

        // 不存在，创建新条目。打开时探测一次项目语言（marker 文件扫描），
        // 结果存入 entry.language，供插件在 agentTools(context:) 内按项目类型筛选工具。
        let entry = ProjectEntry(
            name: Self.directoryName(for: normalized),
            path: normalized,
            language: ProjectLanguageDetector.detect(at: normalized)
        )
        switchToProject(entry)
    }

    /// 切换到指定项目
    public func switchToProject(_ entry: ProjectEntry) {
        if Self.verbose {
            Self.logger.info("\(Self.t)switchToProject: \(entry.name) @ \(entry.path)")
        }
        currentProject = entry

        // 如果项目不在列表中，添加到列表顶部
        if !projects.contains(where: { $0.path == entry.path }) {
            var updatedProjects = projects
            updatedProjects.insert(entry, at: 0)
            projects = updatedProjects
            if Self.verbose {
                Self.logger.info("\(Self.t)项目不在列表中，添加到列表顶部")
            }
        }
    }

    /// 清除当前项目
    public func clearCurrentProject() {
        currentProject = nil
    }

    /// 添加项目到列表
    public func addProject(_ entry: ProjectEntry) {
        // 已存在则更新，否则添加
        if let index = projects.firstIndex(where: { $0.path == entry.path }) {
            var updatedProjects = projects
            updatedProjects[index] = entry
            projects = updatedProjects
        } else {
            var updatedProjects = projects
            updatedProjects.insert(entry, at: 0)
            projects = updatedProjects
        }
    }

    /// 从列表移除项目
    public func removeProject(_ entry: ProjectEntry) {
        var updatedProjects = projects
        updatedProjects.removeAll { $0.path == entry.path }
        projects = updatedProjects

        // 如果移除的是当前项目，清除当前项目
        if currentProject?.path == entry.path {
            currentProject = nil
        }
    }

    // MARK: - 私有方法

    private static func normalizePath(_ path: String) -> String {
        let expanded = (path as NSString).expandingTildeInPath
        let url = URL(fileURLWithPath: expanded)
            .resolvingSymlinksInPath()
            .standardizedFileURL
        return url.path
    }

    private static func directoryName(for path: String) -> String {
        let name = URL(fileURLWithPath: path).lastPathComponent
        return name.isEmpty ? path : name
    }
}
