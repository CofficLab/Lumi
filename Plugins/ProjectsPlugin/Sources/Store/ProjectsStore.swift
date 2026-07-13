import Combine
import Foundation
import LumiCoreKit
import SuperLogKit
import os

// MARK: - Store Protocol

@MainActor
public protocol ProjectsStoring: AnyObject {
    var projects: [LumiProjectEntry] { get }
    var currentProject: LumiProjectEntry? { get }

    func select(_ project: LumiProjectEntry)
    @discardableResult
    func add(path: String, select: Bool) throws -> LumiProjectEntry
    func remove(_ project: LumiProjectEntry)
}

// MARK: - Store

@MainActor
public final class ProjectsStore: ObservableObject, ProjectsStoring, SuperLog {
    public nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.projects.store")
    public nonisolated static let emoji = "📁"
    public static var verbose = false

    public static let shared = ProjectsStore()

    /// 可选的 LumiCore 实例引用，用于访问核心服务
    public weak var lumiCore: (any LumiCoreAccessing)?

    @Published public private(set) var projects: [LumiProjectEntry]
    @Published public private(set) var currentProject: LumiProjectEntry? {
        didSet {
            if Self.verbose {
                Self.logger.info("\(Self.t)currentProject 变化: \(oldValue?.name ?? "nil") → \(self.currentProject?.name ?? "nil")")
            }
        }
    }

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
        self.projects = Self.loadProjects(from: settingsDirectory)

        let currentPath = Self.loadCurrentProjectPath(from: settingsDirectory)
        self.currentProject = projects.first { $0.path == currentPath } ?? projects.first

        // 同步到 LumiCore
        syncToLumiCore()
    }

    /// 默认插件目录（用于单例初始化）
    private static var defaultPluginDirectory: URL {
        // 使用 FileManager 的临时目录作为 fallback
        FileManager.default.temporaryDirectory.appendingPathComponent("Lumi/Projects")
    }

    /// 配置 LumiCore 实例
    public func configure(lumiCore: (any LumiCoreAccessing)?) {
        self.lumiCore = lumiCore
    }

    // MARK: - ProjectsStoring

    public func select(_ project: LumiProjectEntry) {
        if Self.verbose {
            Self.logger.info("\(Self.t)select 被调用: \(project.name) @ \(project.path)")
        }

        let updatedProject = LumiProjectEntry(name: project.name, path: project.path)
        projects.removeAll { $0.path == updatedProject.path }
        projects.insert(updatedProject, at: 0)
        projects = Array(projects.prefix(Self.maxProjectsCount))
        currentProject = updatedProject

        if Self.verbose {
            Self.logger.info("\(Self.t)currentProject 已更新: \(self.currentProject?.name ?? "nil"), 准备调用 lumiCore.projectState?.switchToProject")
        }

        // 持久化
        save()

        // 同步到 LumiCore
        lumiCore?.projectState?.switchToProject(updatedProject)

        if Self.verbose {
            Self.logger.info("\(Self.t)switchToProject 调用完成, projectState.currentProject: \(self.lumiCore?.projectState?.currentProject?.name ?? "nil")")
        }
    }

    @discardableResult
    public func add(path: String, select shouldSelect: Bool = false) throws -> LumiProjectEntry {
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

        let project = LumiProjectEntry(name: url.lastPathComponent, path: url.path)
        if shouldSelect {
            select(project)
        } else {
            add(project)
        }

        return project
    }

    public func remove(_ project: LumiProjectEntry) {
        projects.removeAll { $0.path == project.path }

        if currentProject?.path == project.path {
            currentProject = projects.first
        }

        save()
        syncToLumiCore()
    }

    public func setCurrentProjectPath(_ path: String, reason: String = "") {
        let trimmed = path.trimmingCharacters(in: .whitespacesAndNewlines)

        // 空/空白路径 → "无项目"态
        guard !trimmed.isEmpty else {
            currentProject = nil
            save()
            lumiCore?.projectState?.clearCurrentProject()
            return
        }

        // 标准化路径
        let normalized = Self.normalizedPath(trimmed)

        if let existing = projects.first(where: { $0.path == normalized }) ?? projects.first(where: { $0.path == trimmed }) {
            select(existing)
            return
        }

        // 项目不在列表中：构造条目并选中
        let entry = LumiProjectEntry(name: Self.directoryName(for: normalized), path: normalized)
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

    // MARK: - Sync to LumiCore

    /// 将所有项目同步到 LumiCore
    private func syncToLumiCore() {
        guard let projectState = lumiCore?.projectState else { return }

        // 写入项目列表
        for project in projects {
            projectState.addProject(project)
        }

        // 写入当前项目
        if let current = currentProject {
            projectState.switchToProject(current)
        }
    }

    // MARK: - Private

    private static func normalizedPath(_ path: String) -> String {
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

    private func add(_ project: LumiProjectEntry) {
        projects.removeAll { $0.path == project.path }
        projects.insert(project, at: 0)
        projects = Array(projects.prefix(Self.maxProjectsCount))

        if currentProject == nil {
            currentProject = projects.first
        }

        save()
        syncToLumiCore()
    }

    // MARK: - Persistence

    private func save() {
        try? FileManager.default.createDirectory(
            at: settingsDirectory,
            withIntermediateDirectories: true,
            attributes: nil
        )
        Self.write(projects, to: projectsFileURL)
        Self.write(currentProject?.path, to: currentProjectFileURL)
    }

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

// MARK: - Errors

public enum ProjectsStoreError: LocalizedError {
    case pathDoesNotExist(String)
    case pathIsNotDirectory(String)

    public var errorDescription: String? {
        switch self {
        case .pathDoesNotExist(let path):
            "Path does not exist: \(path)"
        case .pathIsNotDirectory(let path):
            "Path is not a directory: \(path)"
        }
    }
}
