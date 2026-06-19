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
            projectPathStore?.setCurrentProjectPath(currentProject.path)
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
        syncProjectPath(updatedProject.path)
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
                syncProjectPath(currentProject.path)
            } else {
                syncProjectPath("")
            }
        }
        
        save()
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
    
    private func syncProjectPath(_ path: String) {
        projectPathStore?.setCurrentProjectPath(path)
    }
    
    private func add(_ project: LumiProjectEntry) {
        projects.removeAll { $0.path == project.path }
        projects.insert(project, at: 0)
        projects = Array(projects.prefix(Self.maxProjectsCount))
        
        if currentProject == nil {
            currentProject = projects.first
            if let currentProject {
                syncProjectPath(currentProject.path)
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
