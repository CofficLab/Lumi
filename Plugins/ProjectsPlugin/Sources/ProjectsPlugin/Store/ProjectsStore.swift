import Foundation
import LumiCoreKit

/// 项目列表存储协议
@MainActor
public protocol ProjectsStoring: AnyObject {
    var projects: [LumiProjectEntry] { get }
    var currentProject: LumiProjectEntry? { get }
    
    func select(_ project: LumiProjectEntry)
    @discardableResult
    func add(path: String, select: Bool) throws -> LumiProjectEntry
    func remove(_ project: LumiProjectEntry)
}

/// 项目列表 Store，负责磁盘持久化与内存状态管理
@MainActor
public final class ProjectsStore: ObservableObject, ProjectsStoring, LumiProjectStoring {
    @Published public private(set) var projects: [LumiProjectEntry]
    @Published public private(set) var currentProject: LumiProjectEntry?
    
    // MARK: - Constants
    
    private static let settingsDirectoryName = "settings"
    private static let projectsFileName = "projects.json"
    private static let currentProjectFileName = "current-project.json"
    private static let maxProjectsCount = 500
    
    // MARK: - Properties
    
    private let settingsDirectory: URL
    private let projectPathStore: LumiCurrentProjectPathStoring?
    
    // MARK: - Init
    
    public init(
        pluginDirectory: URL = LumiCore.pluginDataDirectory(for: "Projects"),
        projectPathStore: LumiCurrentProjectPathStoring? = nil
    ) {
        self.settingsDirectory = pluginDirectory
            .appendingPathComponent(Self.settingsDirectoryName, isDirectory: true)
        self.projectPathStore = projectPathStore
        self.projects = Self.loadProjects(from: settingsDirectory)
        
        let currentPath = Self.loadCurrentProjectPath(from: settingsDirectory)
        self.currentProject = projects.first { $0.path == currentPath } ?? projects.first
        
        // 同步内核的 LumiCurrentProjectPathStore
        if let currentProject {
            projectPathStore?.setCurrentProjectPath(currentProject.path, reason: "初始化恢复")
        }
    }
    
    // MARK: - ProjectsStoring
    
    public func select(_ project: LumiProjectEntry) {
        let updatedProject = LumiProjectEntry(name: project.name, path: project.path)
        projects.removeAll { $0.path == updatedProject.path }
        projects.insert(updatedProject, at: 0)
        projects = Array(projects.prefix(Self.maxProjectsCount))
        currentProject = updatedProject
        save()
        syncProjectPath(updatedProject.path, reason: "用户选择项目")
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
            if let currentProject {
                syncProjectPath(currentProject.path, reason: "移除项目，切换至上一个")
            } else {
                syncProjectPath("", reason: "移除最后一个项目")
            }
        }

        save()
    }

    public func setCurrentProjectPath(_ path: String, reason: String = "") {
        let trimmed = path.trimmingCharacters(in: .whitespacesAndNewlines)

        // 空/空白路径 → "无项目"态（与 remove 落空时的约定一致）
        guard !trimmed.isEmpty else {
            currentProject = nil
            save()
            syncProjectPath("", reason: reason)
            return
        }

        // 标准化路径（展开 ~、解析符号链接），尽量与列表中既有条目的路径对齐
        let normalized = Self.normalizedPath(trimmed)

        if let existing = projects.first(where: { $0.path == normalized }) ?? projects.first(where: { $0.path == trimmed }) {
            select(existing)
            return
        }

        // 项目不在列表中：构造条目并选中。复用 select(_) 顺便完成
        // save() + syncProjectPath()（持久化 current-project.json + 同步内核 Layer A）。
        // 注意：这里不做目录存在性校验——目录即便已被移走/删除，
        // 也应让当前项目指向它，由真正使用该路径的消费者在使用时报错。
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
    
    // MARK: - Private
    
    private func syncProjectPath(_ path: String, reason: String = "") {
        projectPathStore?.setCurrentProjectPath(path, reason: reason)
    }

    /// 标准化路径：展开 `~`、解析符号链接、标准化。
    /// 与 `add(path:)` 的处理保持一致，确保 `setCurrentProjectPath` 能匹配到列表中既有条目。
    private static func normalizedPath(_ path: String) -> String {
        let expanded = (path as NSString).expandingTildeInPath
        let url = URL(fileURLWithPath: expanded)
            .resolvingSymlinksInPath()
            .standardizedFileURL
        return url.path
    }

    /// 取路径末段作为项目名（与 `add(path:)` 用 `url.lastPathComponent` 一致）。
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
            if let currentProject {
                syncProjectPath(currentProject.path, reason: "添加项目时自动选中")
            }
        }
        
        save()
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
