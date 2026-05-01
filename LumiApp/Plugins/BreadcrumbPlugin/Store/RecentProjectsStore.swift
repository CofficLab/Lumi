import Foundation

/// 最近项目存储
final class RecentProjectsStore: @unchecked Sendable {
    private let queue = DispatchQueue(label: "RecentProjectsStore.queue", qos: .userInitiated)

    private static let legacyKey = "Agent_RecentProjects"

    // Current store file: <dbRoot>/RecentProjects/settings/recent_projects.json
    private static let pluginDirName = "RecentProjects"
    private static let settingsDirName = "settings"
    private static let stateFileName = "recent_projects.json"
    private static let tmpFileName = "recent_projects.tmp"
    
    // Current project file: <dbRoot>/RecentProjects/settings/current_project.json
    private static let currentProjectFileName = "current_project.json"
    private static let currentProjectTmpFileName = "current_project.tmp"
    
    // Current file: <dbRoot>/RecentProjects/settings/current_file.json
    private static let currentFileFileName = "current_file.json"
    private static let currentFileTmpFileName = "current_file.tmp"
    
    /// 最大保存项目数量
    private static let maxProjectsCount = 500

    // MARK: - Public API

    /// 加载最近项目列表
    func loadProjects() -> [Project] {
        queue.sync {
            if let current = loadProjectsFromCurrentFile() {
                return current
            }

            // best-effort migration from legacy storage
            if let legacy = loadProjectsFromLegacyStatePlist() {
                persistProjectsToCurrentFile(projects: legacy)
                return legacy
            }

            return []
        }
    }

    /// 保存最近项目列表
    func saveProjects(_ projects: [Project]) {
        queue.sync {
            persistProjectsToCurrentFile(projects: projects)
        }
    }

    /// 添加或更新项目到列表开头（最多保留 500 条）
    func addProject(name: String, path: String) {
        queue.sync {
            var projects = loadProjectsInternal()
            projects.removeAll { $0.path == path }

            let newProject = Project(name: name, path: path, lastUsed: Date())
            projects.insert(newProject, at: 0)
            projects = Array(projects.prefix(Self.maxProjectsCount))

            persistProjectsToCurrentFile(projects: projects)
        }
    }

    /// 删除指定项目
    func removeProject(_ project: Project) {
        queue.sync {
            var projects = loadProjectsInternal()
            projects.removeAll { $0.id == project.id }
            persistProjectsToCurrentFile(projects: projects)
        }
    }
    
    // MARK: - Current Project
    
    /// 获取当前选中的项目
    func getCurrentProject() -> Project? {
        queue.sync {
            let fileURL = currentProjectFileURL()
            guard FileManager.default.fileExists(atPath: fileURL.path) else { return nil }
            guard let data = try? Data(contentsOf: fileURL) else { return nil }
            return try? JSONDecoder().decode(Project.self, from: data)
        }
    }
    
    /// 设置当前选中的项目
    func setCurrentProject(name: String, path: String) {
        queue.sync {
            let project = Project(name: name, path: path, lastUsed: Date())
            persistCurrentProject(project)
            
            // 同时将项目添加到最近列表
            addProjectInternal(name: name, path: path)
        }
    }
    
    /// 清除当前项目
    func clearCurrentProject() {
        queue.sync {
            let fileURL = currentProjectFileURL()
            try? FileManager.default.removeItem(at: fileURL)
        }
    }

    // MARK: - Internal

    private func loadProjectsInternal() -> [Project] {
        // 避免在 queue.sync 内再次触发迁移逻辑导致重复写。
        // 读取顺序：current file -> legacy migration
        if let current = loadProjectsFromCurrentFile() {
            return current
        }
        return loadProjectsFromLegacyStatePlist() ?? []
    }

    private func loadProjectsFromCurrentFile() -> [Project]? {
        let fileURL = currentStateFileURL()
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return nil }
        guard let data = try? Data(contentsOf: fileURL) else { return nil }
        guard let projects = try? JSONDecoder().decode([Project].self, from: data) else { return nil }
        return projects
    }

    private func persistProjectsToCurrentFile(projects: [Project]) {
        let fileManager = FileManager.default
        let settingsDir = currentSettingsDirURL()
        try? fileManager.createDirectory(at: settingsDir, withIntermediateDirectories: true, attributes: nil)

        let fileURL = currentStateFileURL()
        let tmpURL = settingsDir.appendingPathComponent(Self.tmpFileName, isDirectory: false)

        guard let data = try? JSONEncoder().encode(projects) else { return }

        do {
            try data.write(to: tmpURL, options: .atomic)
            if fileManager.fileExists(atPath: fileURL.path) {
                _ = try? fileManager.replaceItemAt(fileURL, withItemAt: tmpURL)
            } else {
                try fileManager.moveItem(at: tmpURL, to: fileURL)
            }
        } catch {
            try? fileManager.removeItem(at: tmpURL)
        }
    }
    
    private func persistCurrentProject(_ project: Project) {
        let fileManager = FileManager.default
        let settingsDir = currentSettingsDirURL()
        try? fileManager.createDirectory(at: settingsDir, withIntermediateDirectories: true, attributes: nil)

        let fileURL = currentProjectFileURL()
        let tmpURL = settingsDir.appendingPathComponent(Self.currentProjectTmpFileName, isDirectory: false)

        guard let data = try? JSONEncoder().encode(project) else { return }

        do {
            try data.write(to: tmpURL, options: .atomic)
            if fileManager.fileExists(atPath: fileURL.path) {
                _ = try? fileManager.replaceItemAt(fileURL, withItemAt: tmpURL)
            } else {
                try fileManager.moveItem(at: tmpURL, to: fileURL)
            }
        } catch {
            try? fileManager.removeItem(at: tmpURL)
        }
    }
    
    /// 内部添加项目到最近列表（不重复获取锁）
    private func addProjectInternal(name: String, path: String) {
        var projects = loadProjectsInternal()
        projects.removeAll { $0.path == path }

        let newProject = Project(name: name, path: path, lastUsed: Date())
        projects.insert(newProject, at: 0)
        projects = Array(projects.prefix(Self.maxProjectsCount))

        persistProjectsToCurrentFile(projects: projects)
    }

    /// 从旧的 PluginStateStore 持久化文件迁移一次数据。
    ///
    /// 旧路径：<dbRoot>/StatePersistencePlugin/settings/state.plist
    private func loadProjectsFromLegacyStatePlist() -> [Project]? {
        let legacyStatePlistURL = AppConfig.getDBFolderURL()
            .appendingPathComponent("StatePersistencePlugin", isDirectory: true)
            .appendingPathComponent("settings", isDirectory: true)
            .appendingPathComponent("state.plist", isDirectory: false)

        guard FileManager.default.fileExists(atPath: legacyStatePlistURL.path) else { return nil }
        guard let data = try? Data(contentsOf: legacyStatePlistURL) else { return nil }
        guard let plist = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil),
              let dict = plist as? [String: Any] else { return nil }

        guard let storedData = dict[Self.legacyKey] as? Data else { return nil }
        return try? JSONDecoder().decode([Project].self, from: storedData)
    }

    private func currentSettingsDirURL() -> URL {
        AppConfig.getDBFolderURL()
            .appendingPathComponent(Self.pluginDirName, isDirectory: true)
            .appendingPathComponent(Self.settingsDirName, isDirectory: true)
    }

    private func currentStateFileURL() -> URL {
        currentSettingsDirURL()
            .appendingPathComponent(Self.stateFileName, isDirectory: false)
    }
    
    private func currentProjectFileURL() -> URL {
        currentSettingsDirURL()
            .appendingPathComponent(Self.currentProjectFileName, isDirectory: false)
    }
    
    // MARK: - Current File
    
    /// 获取当前选中的文件
    func getCurrentFile() -> (path: String, lastSelected: Date)? {
        queue.sync {
            let fileURL = currentFileFileURL()
            guard FileManager.default.fileExists(atPath: fileURL.path) else { return nil }
            guard let data = try? Data(contentsOf: fileURL) else { return nil }
            guard let fileInfo = try? JSONDecoder().decode(CurrentFileInfo.self, from: data) else { return nil }
            return (fileInfo.path, fileInfo.lastSelected)
        }
    }
    
    /// 设置当前选中的文件
    func setCurrentFile(path: String) {
        queue.sync {
            let fileInfo = CurrentFileInfo(path: path, lastSelected: Date())
            persistCurrentFile(fileInfo)
        }
    }
    
    /// 清除当前文件
    func clearCurrentFile() {
        queue.sync {
            let fileURL = currentFileFileURL()
            try? FileManager.default.removeItem(at: fileURL)
        }
    }
    
    private func currentFileFileURL() -> URL {
        currentSettingsDirURL()
            .appendingPathComponent(Self.currentFileFileName, isDirectory: false)
    }
    
    private func persistCurrentFile(_ fileInfo: CurrentFileInfo) {
        let fileManager = FileManager.default
        let settingsDir = currentSettingsDirURL()
        try? fileManager.createDirectory(at: settingsDir, withIntermediateDirectories: true, attributes: nil)

        let fileURL = currentFileFileURL()
        let tmpURL = settingsDir.appendingPathComponent(Self.currentFileTmpFileName, isDirectory: false)

        guard let data = try? JSONEncoder().encode(fileInfo) else { return }

        do {
            try data.write(to: tmpURL, options: .atomic)
            if fileManager.fileExists(atPath: fileURL.path) {
                _ = try? fileManager.replaceItemAt(fileURL, withItemAt: tmpURL)
            } else {
                try fileManager.moveItem(at: tmpURL, to: fileURL)
            }
        } catch {
            try? fileManager.removeItem(at: tmpURL)
        }
    }
}

// MARK: - Current File Info

/// 当前文件信息
private struct CurrentFileInfo: Codable {
    let path: String
    let lastSelected: Date
}
