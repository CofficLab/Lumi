import CryptoKit
import EditorService
import LumiCoreKit
import SuperLogKit
import Foundation
import os

/// 编辑器标签页持久化存储
///
/// 按项目维度保存/恢复打开的标签页列表和活跃标签。
/// 存储位置：<dbRoot>/EditorTabStrip/projects/<projectHash>/tabs.json
public final class StripStore: @unchecked Sendable, SuperLog {
    public nonisolated static var emoji: String { "📑" }
    public nonisolated static let verbose: Bool = true
    public nonisolated static let logger = Logger(
        subsystem: "com.coffic.lumi", category: "plugin.editor-tab-strip-store")

    private let fileManager = FileManager.default
    private let queue = DispatchQueue(label: "StripStore.queue", qos: .userInitiated)
    private let baseDirectory: URL

    public static let shared = StripStore()

    // MARK: - Persistence Models

    /// 持久化的标签页条目
    public struct PersistedTab: Codable, Equatable {
        public let path: String
        public let isPinned: Bool
    }

    /// 持久化的项目标签页快照
    private struct PersistedProjectTabs: Codable {
        let projectPath: String
        let tabs: [PersistedTab]
        let activeTabPath: String?
        let savedAt: Date
    }

    // MARK: - Initialization

    public convenience init() {
        self.init(baseDirectory: AppConfig.getDBFolderURL()
            .appendingPathComponent("EditorTabStrip", isDirectory: true)
            .appendingPathComponent("projects", isDirectory: true))
    }

    init(baseDirectory: URL) {
        self.baseDirectory = baseDirectory
        do {
            try fileManager.createDirectory(at: baseDirectory, withIntermediateDirectories: true)
        } catch {
            Self.logger.error("\(Self.t)Create editor tab strip directory failed: \(error.localizedDescription)")
        }
    }

    // MARK: - Public API

    /// 保存指定项目的标签页列表（异步，不阻塞调用线程）
    public func saveTabs(
        projectPath: String,
        tabs: [EditorTab],
        activeTabPath: String?
    ) {
        queue.async { [self] in
            let persisted = tabs.compactMap { tab -> PersistedTab? in
                guard let url = tab.fileURL else { return nil }
                return PersistedTab(path: url.path, isPinned: tab.isPinned)
            }
            let snapshot = PersistedProjectTabs(
                projectPath: projectPath,
                tabs: persisted,
                activeTabPath: activeTabPath,
                savedAt: Date()
            )

            self.writeSnapshot(snapshot, forProject: projectPath)
        }
    }

    /// 加载指定项目的标签页列表（同步，需要返回值）
    public func loadTabs(forProject projectPath: String) -> (tabs: [PersistedTab], activeTabPath: String?) {
        queue.sync {
            guard let snapshot = self.readSnapshot(forProject: projectPath) else {
                return ([], nil)
            }

            return (snapshot.tabs, snapshot.activeTabPath)
        }
    }

    /// 清除指定项目的标签页记录（异步，不阻塞调用线程）
    public func clearTabs(forProject projectPath: String) {
        queue.async { [self] in
            let fileURL = self.getFileURL(forProject: projectPath)
            do {
                try self.fileManager.removeItem(at: fileURL)
            } catch {
                Self.logger.error("\(Self.t)Clear editor tab strip state failed: \(error.localizedDescription)")
            }
        }
    }

    // MARK: - Current File

    /// 获取指定项目的当前活跃文件路径（同步，需要返回值）
    ///
    /// 读取持久化快照中的 `activeTabPath`，并校验文件仍存在。
    public func getCurrentFilePath(forProject projectPath: String) -> (path: String, lastSelected: Date)? {
        queue.sync {
            guard let snapshot = readSnapshot(forProject: projectPath),
                  let activePath = snapshot.activeTabPath,
                  fileManager.fileExists(atPath: activePath) else {
                return nil
            }
            return (activePath, snapshot.savedAt)
        }
    }

    /// 设置指定项目的当前活跃文件（异步，不阻塞调用线程）
    ///
    /// 如果该文件已在 tabs 中，仅切换 activeTabPath；
    /// 如果不在 tabs 中，则追加一个未钉住的 tab 并设为活跃。
    public func setCurrentFilePath(path: String, forProject projectPath: String) {
        queue.async { [self] in
            var snapshot = self.readSnapshot(forProject: projectPath) ?? PersistedProjectTabs(
                projectPath: projectPath,
                tabs: [],
                activeTabPath: nil,
                savedAt: Date()
            )

            let existingIndex = snapshot.tabs.firstIndex(where: { $0.path == path })
            if existingIndex == nil {
                // 文件不在 tabs 中 → 追加
                snapshot = PersistedProjectTabs(
                    projectPath: snapshot.projectPath,
                    tabs: snapshot.tabs + [PersistedTab(path: path, isPinned: false)],
                    activeTabPath: path,
                    savedAt: Date()
                )
            } else {
                // 文件已在 tabs 中 → 仅更新 activeTabPath 和时间
                snapshot = PersistedProjectTabs(
                    projectPath: snapshot.projectPath,
                    tabs: snapshot.tabs,
                    activeTabPath: path,
                    savedAt: Date()
                )
            }

            self.writeSnapshot(snapshot, forProject: projectPath)

            if Self.verbose {
                if Self.verbose {
                                    Self.logger.info("\(Self.t)设置当前文件：\(path)，项目：\(projectPath)")
                }
            }
        }
    }

    // MARK: - Private Helpers

    private func getFileURL(forProject projectPath: String) -> URL {
        let safeName = stableDirectoryName(for: projectPath)
        return baseDirectory
            .appendingPathComponent(safeName, isDirectory: true)
            .appendingPathComponent("tabs.json", isDirectory: false)
    }

    /// 对项目路径生成稳定的目录名（SHA-256 前 16 位十六进制）
    ///
    /// 不使用 `String.hashValue`，因为它在每次程序启动时会产生不同的值，
    /// 导致重启后无法找到之前保存的数据。
    private func stableDirectoryName(for projectPath: String) -> String {
        let data = Data(projectPath.utf8)
        let hash = SHA256.hash(data: data)
        let hex = hash.compactMap { String(format: "%02x", $0) }.joined()
        return "project_\(String(hex.prefix(16)))"
    }

    private func readSnapshot(forProject projectPath: String) -> PersistedProjectTabs? {
        let fileURL = getFileURL(forProject: projectPath)
        guard fileManager.fileExists(atPath: fileURL.path) else { return nil }
        do {
            let data = try Data(contentsOf: fileURL)
            return try JSONDecoder().decode(PersistedProjectTabs.self, from: data)
        } catch {
            Self.logger.error("\(Self.t)Read editor tab strip state failed: \(error.localizedDescription)")
            quarantineCorruptSnapshot(forProject: projectPath)
            return nil
        }
    }

    private func writeSnapshot(_ snapshot: PersistedProjectTabs, forProject projectPath: String) {
        let fileURL = getFileURL(forProject: projectPath)
        let dirURL = fileURL.deletingLastPathComponent()

        let data: Data
        do {
            data = try JSONEncoder().encode(snapshot)
        } catch {
            Self.logger.error("\(Self.t)Encode editor tab strip state failed: \(error.localizedDescription)")
            return
        }

        let tmpURL = dirURL.appendingPathComponent("tabs.tmp")
        do {
            try fileManager.createDirectory(at: dirURL, withIntermediateDirectories: true)
            try data.write(to: tmpURL, options: .atomic)
            if fileManager.fileExists(atPath: fileURL.path) {
                _ = try fileManager.replaceItemAt(fileURL, withItemAt: tmpURL)
            } else {
                try fileManager.moveItem(at: tmpURL, to: fileURL)
            }
        } catch {
            Self.logger.error("\(Self.t)Persist editor tab strip state failed: \(error.localizedDescription)")
            try? fileManager.removeItem(at: tmpURL)
        }
    }

    private func quarantineCorruptSnapshot(forProject projectPath: String) {
        let fileURL = getFileURL(forProject: projectPath)
        guard fileManager.fileExists(atPath: fileURL.path) else { return }

        let corruptURL = fileURL.deletingLastPathComponent()
            .appendingPathComponent("tabs.corrupt.json", isDirectory: false)
        do {
            if fileManager.fileExists(atPath: corruptURL.path) {
                try fileManager.removeItem(at: corruptURL)
            }
            try fileManager.moveItem(at: fileURL, to: corruptURL)
        } catch {
            Self.logger.error("\(Self.t)Quarantine corrupt editor tab strip state failed: \(error.localizedDescription)")
        }
    }
}

// MARK: - PersistedTab Public Extension

extension StripStore.PersistedTab {
    /// 转换为文件 URL
    public var fileURL: URL? {
        URL(fileURLWithPath: path)
    }
}
