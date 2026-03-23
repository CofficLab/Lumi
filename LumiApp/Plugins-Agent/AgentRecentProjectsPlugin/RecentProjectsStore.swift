import Foundation

/// 最近项目存储
///
/// - 目标：不依赖 `PluginStateStore`，自己实现文件型持久化
/// - 兼容：若旧版本仍在 `StatePersistencePlugin/settings/state.plist` 内保存，则会在首次读取时尝试迁移
final class RecentProjectsStore: @unchecked Sendable {
    private let queue = DispatchQueue(label: "RecentProjectsStore.queue", qos: .userInitiated)

    private static let legacyKey = "Agent_RecentProjects"

    // Current store file: <dbRoot>/AgentRecentProjects/settings/recent_projects.json
    private static let pluginDirName = "AgentRecentProjects"
    private static let settingsDirName = "settings"
    private static let stateFileName = "recent_projects.json"
    private static let tmpFileName = "recent_projects.tmp"

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

    /// 添加或更新项目到列表开头（最多保留 5 条）
    func addProject(name: String, path: String) {
        queue.sync {
            var projects = loadProjectsInternal()
            projects.removeAll { $0.path == path }

            let newProject = Project(name: name, path: path, lastUsed: Date())
            projects.insert(newProject, at: 0)
            projects = Array(projects.prefix(5))

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
}

