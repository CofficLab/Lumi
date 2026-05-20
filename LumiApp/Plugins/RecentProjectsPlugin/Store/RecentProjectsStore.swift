import Foundation

/// 窗口-项目关联记录
/// 用于持久化每个窗口当前打开的项目路径。
struct WindowProjectRecord: Codable {
    let windowId: UUID
    let projectPath: String?
}

/// 最近项目存储
/// 负责全局最近项目列表和窗口级当前项目的持久化。
final class RecentProjectsStore: @unchecked Sendable {
    private let queue = DispatchQueue(label: "RecentProjectsStore.queue", qos: .userInitiated)

    private static let legacyKey = "Agent_RecentProjects"

    // Store file: <dbRoot>/RecentProjects/settings/recent_projects.json
    private static let pluginDirName = "RecentProjects"
    private static let settingsDirName = "settings"
    private static let stateFileName = "recent_projects.json"
    private static let tmpFileName = "recent_projects.tmp"

    // Window-project file: <dbRoot>/RecentProjects/settings/window_projects.json
    private static let windowProjectsFileName = "window_projects.json"
    private static let windowProjectsTmpFileName = "window_projects.tmp"

    /// 最大保存项目数量
    private static let maxProjectsCount = 500

    // MARK: - Public API

    /// 加载最近项目列表（同步，需要返回值）
    func loadProjects() -> [Project] {
        queue.sync { [self] in
            if let current = self.loadProjectsFromCurrentFile() {
                return current
            }

            // best-effort migration from legacy storage
            if let legacy = self.loadProjectsFromLegacyStatePlist() {
                self.persistProjectsToCurrentFile(projects: legacy)
                return legacy
            }

            return []
        }
    }

    /// 保存最近项目列表（异步，不阻塞调用线程）
    func saveProjects(_ projects: [Project]) {
        queue.async { [self] in
            self.persistProjectsToCurrentFile(projects: projects)
        }
    }

    /// 添加或更新项目到列表开头（异步，不阻塞调用线程）
    /// 最多保留 500 条
    func addProject(name: String, path: String) {
        queue.async { [self] in
            var projects = self.loadProjectsInternal()
            projects.removeAll { $0.path == path }

            let newProject = Project(name: name, path: path, lastUsed: Date())
            projects.insert(newProject, at: 0)
            projects = Array(projects.prefix(Self.maxProjectsCount))

            self.persistProjectsToCurrentFile(projects: projects)
        }
    }

    /// 删除指定项目（异步，不阻塞调用线程）
    func removeProject(_ project: Project) {
        queue.async { [self] in
            var projects = self.loadProjectsInternal()
            projects.removeAll { $0.id == project.id }
            self.persistProjectsToCurrentFile(projects: projects)
        }
    }

    // MARK: - Window-Project Persistence

    /// 保存每个窗口的当前项目路径（异步，不阻塞调用线程）
    @MainActor
    func saveWindowProjects(from scopes: [WindowScope]) {
        let records = scopes.map { scope in
            WindowProjectRecord(
                windowId: scope.id,
                projectPath: scope.projectPath
            )
        }
        queue.async { [self] in
            self.persistWindowProjects(records)
        }
    }

    /// 保存每个窗口的当前项目路径（同步，用于应用退出时）
    @MainActor
    func saveWindowProjectsSynchronously(from scopes: [WindowScope]) {
        let records = scopes.map { scope in
            WindowProjectRecord(
                windowId: scope.id,
                projectPath: scope.projectPath
            )
        }
        queue.sync { [self] in
            self.persistWindowProjects(records)
        }
    }

    /// 加载所有窗口的项目路径记录（同步）
    func loadWindowProjects() -> [WindowProjectRecord] {
        queue.sync { [self] in
            let fileURL = windowProjectsFileURL()
            guard FileManager.default.fileExists(atPath: fileURL.path) else { return [] }
            guard let data = try? Data(contentsOf: fileURL) else { return [] }
            return (try? JSONDecoder().decode([WindowProjectRecord].self, from: data)) ?? []
        }
    }

    /// 清除所有窗口-项目关联（异步）
    func clearWindowProjects() {
        queue.async { [self] in
            try? FileManager.default.removeItem(at: windowProjectsFileURL())
        }
    }

    // MARK: - Internal

    private func loadProjectsInternal() -> [Project] {
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

    private func persistWindowProjects(_ records: [WindowProjectRecord]) {
        let fileManager = FileManager.default
        let settingsDir = currentSettingsDirURL()
        try? fileManager.createDirectory(at: settingsDir, withIntermediateDirectories: true, attributes: nil)

        let fileURL = windowProjectsFileURL()
        let tmpURL = settingsDir.appendingPathComponent(Self.windowProjectsTmpFileName, isDirectory: false)

        guard let data = try? JSONEncoder().encode(records) else { return }

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

    private func currentSettingsDirURL() -> URL {
        AppConfig.getDBFolderURL()
            .appendingPathComponent(Self.pluginDirName, isDirectory: true)
            .appendingPathComponent(Self.settingsDirName, isDirectory: true)
    }

    private func currentStateFileURL() -> URL {
        currentSettingsDirURL()
            .appendingPathComponent(Self.stateFileName, isDirectory: false)
    }

    private func windowProjectsFileURL() -> URL {
        currentSettingsDirURL()
            .appendingPathComponent(Self.windowProjectsFileName, isDirectory: false)
    }
}
