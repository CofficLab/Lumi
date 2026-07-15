import Foundation
import LumiCoreKit
import os
import SuperLogKit

/// 纯数据存取层，专注于项目的持久化存储。
/// 不包含任何状态管理逻辑，所有数据通过方法参数传入/返回。
@MainActor
public final class ProjectsStore: SuperLog {
    public nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.projects.store")
    public nonisolated static let emoji = "📁"
    public static var verbose = true

    // MARK: - Constants

    private static let settingsDirectoryName = "settings"
    private static let projectsFileName = "projects.json"
    private static let currentProjectFileName = "current-project.json"
    private static let maxProjectsCount = 500

    // MARK: - Properties

    private let settingsDirectory: URL

    // MARK: - Init

    public init(pluginDirectory: URL? = nil) {
        let directory = pluginDirectory ?? ProjectsStore.defaultPluginDirectory
        self.settingsDirectory = directory
            .appendingPathComponent(Self.settingsDirectoryName, isDirectory: true)

        if Self.verbose {
            Self.logger.info("\(Self.t)初始化完成, settingsDirectory: \(self.settingsDirectory.path)")
        }
    }

    /// 默认插件目录
    private static var defaultPluginDirectory: URL {
        FileManager.default.temporaryDirectory.appendingPathComponent("Lumi/Projects")
    }

    // MARK: - Load

    /// 加载所有项目
    public func loadProjects() -> [LumiProjectEntry] {
        Self.loadProjects(from: settingsDirectory)
    }

    /// 加载当前项目路径
    public func loadCurrentProjectPath() -> String? {
        Self.loadCurrentProjectPath(from: settingsDirectory)
    }

    /// 加载当前项目（从项目列表中查找）
    public func loadCurrentProject(from projects: [LumiProjectEntry]) -> LumiProjectEntry? {
        let currentPath = loadCurrentProjectPath()
        return projects.first { $0.path == currentPath } ?? projects.first
    }

    // MARK: - Save

    /// 保存所有项目和当前项目
    public func save(projects: [LumiProjectEntry], currentProject: LumiProjectEntry?) {
        try? FileManager.default.createDirectory(
            at: settingsDirectory,
            withIntermediateDirectories: true,
            attributes: nil
        )
        Self.write(projects, to: projectsFileURL)
        Self.write(currentProject?.path, to: currentProjectFileURL)
    }

    /// 添加项目到列表，返回更新后的列表
    public func addProject(_ project: LumiProjectEntry, to projects: [LumiProjectEntry]) -> [LumiProjectEntry] {
        var updated = projects
        updated.removeAll { $0.path == project.path }
        updated.insert(project, at: 0)
        return Array(updated.prefix(Self.maxProjectsCount))
    }

    /// 从项目列表中移除项目，返回更新后的列表
    public func removeProject(_ project: LumiProjectEntry, from projects: [LumiProjectEntry]) -> [LumiProjectEntry] {
        var updated = projects
        updated.removeAll { $0.path == project.path }
        return updated
    }

    /// 选中项目：将项目移到列表顶部，返回更新后的列表
    public func selectProject(_ project: LumiProjectEntry, in projects: [LumiProjectEntry]) -> [LumiProjectEntry] {
        let updatedProject = LumiProjectEntry(name: project.name, path: project.path)
        var updated = projects
        updated.removeAll { $0.path == updatedProject.path }
        updated.insert(updatedProject, at: 0)
        return Array(updated.prefix(Self.maxProjectsCount))
    }

    /// 通过路径添加项目
    @discardableResult
    public func add(path: String, to projects: [LumiProjectEntry]) throws -> LumiProjectEntry {
        let expandedPath = (path as NSString).expandingTildeInPath
        let url = URL(fileURLWithPath: expandedPath)
            .resolvingSymlinksInPath()
            .standardizedFileURL

        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory) else {
            throw ProjectsStoreError.pathDoesNotExist(url.path)
        }

        guard isDirectory.boolValue else {
            throw ProjectsStoreError.pathIsNotDirectory(url.path)
        }

        return LumiProjectEntry(name: url.lastPathComponent, path: url.path)
    }

    /// 标准化路径
    public static func normalizedPath(_ path: String) -> String {
        let expanded = (path as NSString).expandingTildeInPath
        let url = URL(fileURLWithPath: expanded)
            .resolvingSymlinksInPath()
            .standardizedFileURL
        return url.path
    }

    /// 获取目录名称
    public static func directoryName(for path: String) -> String {
        let name = URL(fileURLWithPath: path).lastPathComponent
        return name.isEmpty ? path : name
    }

    // MARK: - Private

    private var projectsFileURL: URL {
        settingsDirectory.appendingPathComponent(Self.projectsFileName, isDirectory: false)
    }

    private var currentProjectFileURL: URL {
        settingsDirectory.appendingPathComponent(Self.currentProjectFileName, isDirectory: false)
    }

    // MARK: - Static I/O

    private static func loadProjects(from settingsDirectory: URL) -> [LumiProjectEntry] {
        let fileURL = settingsDirectory.appendingPathComponent(projectsFileName, isDirectory: false)

        guard let data = try? Data(contentsOf: fileURL),
              let projects = try? JSONDecoder().decode([LumiProjectEntry].self, from: data)
        else {
            return []
        }

        return projects
    }

    private static func loadCurrentProjectPath(from settingsDirectory: URL) -> String? {
        let fileURL = settingsDirectory.appendingPathComponent(currentProjectFileName, isDirectory: false)
        guard let data = try? Data(contentsOf: fileURL) else {
            return nil
        }

        return try? JSONDecoder().decode(String.self, from: data)
    }

    private static func write<Value: Encodable>(_ value: Value, to fileURL: URL) {
        guard let data = try? JSONEncoder().encode(value) else {
            return
        }

        let temporaryURL = fileURL
            .deletingLastPathComponent()
            .appendingPathComponent("\(fileURL.lastPathComponent).tmp", isDirectory: false)

        do {
            try data.write(to: temporaryURL, options: .atomic)

            if FileManager.default.fileExists(atPath: fileURL.path) {
                _ = try FileManager.default.replaceItemAt(fileURL, withItemAt: temporaryURL)
            } else {
                try FileManager.default.moveItem(at: temporaryURL, to: fileURL)
            }
        } catch {
            try? FileManager.default.removeItem(at: temporaryURL)
        }
    }
}
