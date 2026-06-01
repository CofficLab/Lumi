import Foundation
import LumiCoreKit
import os

/// 项目存储
/// 负责全局项目列表的持久化。
public final class ProjectsStore: @unchecked Sendable {
    private static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.projects.store")
    private let queue = DispatchQueue(label: "ProjectsStore.queue", qos: .userInitiated)
    private let dbFolderURLProvider: @Sendable () -> URL

    private static let legacyKey = "Agent_Projects"

    // Store file: <dbRoot>/Projects/settings/projects.json
    private static let pluginDirName = "Projects"
    private static let settingsDirName = "settings"
    private static let stateFileName = "projects.json"
    private static let corruptStateFileName = "projects.corrupt.json"
    private static let tmpFileName = "projects.tmp"

    /// 最大保存项目数量
    private static let maxProjectsCount = 500

    public convenience init() {
        self.init(dbFolderURLProvider: { AppConfig.getDBFolderURL() })
    }

    init(dbFolderURLProvider: @escaping @Sendable () -> URL) {
        self.dbFolderURLProvider = dbFolderURLProvider
    }

    // MARK: - Public API

    /// 加载最近项目列表（同步，需要返回值）
    public func loadProjects() -> [Project] {
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
    public func saveProjects(_ projects: [Project]) {
        queue.async { [self] in
            self.persistProjectsToCurrentFile(projects: projects)
        }
    }

    /// 添加或更新项目到列表开头（异步，不阻塞调用线程）
    /// 最多保留 500 条
    public func addProject(name: String, path: String) {
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
    public func removeProject(_ project: Project) {
        queue.async { [self] in
            var projects = self.loadProjectsInternal()
            projects.removeAll { $0.id == project.id }
            self.persistProjectsToCurrentFile(projects: projects)
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
        do {
            let data = try Data(contentsOf: fileURL)
            return try JSONDecoder().decode([Project].self, from: data)
        } catch {
            Self.logger.error("Read projects state failed: \(error.localizedDescription)")
            quarantineCorruptCurrentState()
            return nil
        }
    }

    private func persistProjectsToCurrentFile(projects: [Project]) {
        let fileManager = FileManager.default
        let settingsDir = currentSettingsDirURL()

        let fileURL = currentStateFileURL()
        let tmpURL = settingsDir.appendingPathComponent(Self.tmpFileName, isDirectory: false)

        let data: Data
        do {
            data = try JSONEncoder().encode(projects)
        } catch {
            Self.logger.error("Encode projects state failed: \(error.localizedDescription)")
            return
        }

        do {
            try fileManager.createDirectory(at: settingsDir, withIntermediateDirectories: true, attributes: nil)
            try data.write(to: tmpURL, options: .atomic)
            if fileManager.fileExists(atPath: fileURL.path) {
                _ = try fileManager.replaceItemAt(fileURL, withItemAt: tmpURL)
            } else {
                try fileManager.moveItem(at: tmpURL, to: fileURL)
            }
        } catch {
            Self.logger.error("Persist projects state failed: \(error.localizedDescription)")
            try? fileManager.removeItem(at: tmpURL)
        }
    }

    private func quarantineCorruptCurrentState() {
        let fileManager = FileManager.default
        let fileURL = currentStateFileURL()
        guard fileManager.fileExists(atPath: fileURL.path) else { return }

        do {
            let corruptURL = currentCorruptStateFileURL()
            if fileManager.fileExists(atPath: corruptURL.path) {
                try fileManager.removeItem(at: corruptURL)
            }
            try fileManager.moveItem(at: fileURL, to: corruptURL)
        } catch {
            Self.logger.error("Quarantine corrupt projects state failed: \(error.localizedDescription)")
        }
    }

    /// 从旧的 PluginStateStore 持久化文件迁移一次数据。
    ///
    /// 旧路径：<dbRoot>/StatePersistencePlugin/settings/state.plist
    private func loadProjectsFromLegacyStatePlist() -> [Project]? {
        let legacyStatePlistURL = dbFolderURLProvider()
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
        dbFolderURLProvider()
            .appendingPathComponent(Self.pluginDirName, isDirectory: true)
            .appendingPathComponent(Self.settingsDirName, isDirectory: true)
    }

    private func currentStateFileURL() -> URL {
        currentSettingsDirURL()
            .appendingPathComponent(Self.stateFileName, isDirectory: false)
    }

    private func currentCorruptStateFileURL() -> URL {
        currentSettingsDirURL()
            .appendingPathComponent(Self.corruptStateFileName, isDirectory: false)
    }
}
