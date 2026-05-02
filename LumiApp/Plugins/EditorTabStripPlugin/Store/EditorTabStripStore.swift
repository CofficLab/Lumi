import Foundation
import MagicKit
import os

/// 编辑器标签页持久化存储
///
/// 按项目维度保存/恢复打开的标签页列表和活跃标签。
/// 存储位置：<dbRoot>/EditorTabStrip/projects/<projectHash>/tabs.json
final class EditorTabStripStore: @unchecked Sendable, SuperLog {
    nonisolated static var emoji: String { "📑" }
    nonisolated static let verbose: Bool = false
    nonisolated static let logger = Logger(
        subsystem: "com.coffic.lumi", category: "plugin.editor-tab-strip-store")

    private let fileManager = FileManager.default
    private let queue = DispatchQueue(label: "EditorTabStripStore.queue", qos: .userInitiated)
    private let baseDirectory: URL

    static let shared = EditorTabStripStore()

    // MARK: - Persistence Models

    /// 持久化的标签页条目
    struct PersistedTab: Codable, Equatable {
        let path: String
        let isPinned: Bool
    }

    /// 持久化的项目标签页快照
    private struct PersistedProjectTabs: Codable {
        let projectPath: String
        let tabs: [PersistedTab]
        let activeTabPath: String?
        let savedAt: Date
    }

    // MARK: - Initialization

    private init() {
        self.baseDirectory = AppConfig.getDBFolderURL()
            .appendingPathComponent("EditorTabStrip", isDirectory: true)
            .appendingPathComponent("projects", isDirectory: true)
        try? fileManager.createDirectory(at: baseDirectory, withIntermediateDirectories: true)
    }

    // MARK: - Public API

    /// 保存指定项目的标签页列表
    func saveTabs(
        projectPath: String,
        tabs: [EditorTab],
        activeTabPath: String?
    ) {
        queue.sync {
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
            writeSnapshot(snapshot, forProject: projectPath)

            if Self.verbose {
                Self.logger.info("\(Self.t)保存项目标签：\(projectPath)，共 \(persisted.count) 个标签")
            }
        }
    }

    /// 加载指定项目的标签页列表
    func loadTabs(forProject projectPath: String) -> (tabs: [PersistedTab], activeTabPath: String?) {
        queue.sync {
            guard let snapshot = readSnapshot(forProject: projectPath) else {
                return ([], nil)
            }
            return (snapshot.tabs, snapshot.activeTabPath)
        }
    }

    /// 清除指定项目的标签页记录
    func clearTabs(forProject projectPath: String) {
        queue.sync {
            let fileURL = getFileURL(forProject: projectPath)
            try? fileManager.removeItem(at: fileURL)
        }
    }

    // MARK: - Private Helpers

    private func getFileURL(forProject projectPath: String) -> URL {
        let hash = projectPath.hashValue
        let safeName = "project_\(abs(hash))"
        return baseDirectory
            .appendingPathComponent(safeName, isDirectory: true)
            .appendingPathComponent("tabs.json", isDirectory: false)
    }

    private func readSnapshot(forProject projectPath: String) -> PersistedProjectTabs? {
        let fileURL = getFileURL(forProject: projectPath)
        guard fileManager.fileExists(atPath: fileURL.path) else { return nil }
        guard let data = try? Data(contentsOf: fileURL) else { return nil }
        return try? JSONDecoder().decode(PersistedProjectTabs.self, from: data)
    }

    private func writeSnapshot(_ snapshot: PersistedProjectTabs, forProject projectPath: String) {
        let fileURL = getFileURL(forProject: projectPath)
        let dirURL = fileURL.deletingLastPathComponent()
        try? fileManager.createDirectory(at: dirURL, withIntermediateDirectories: true)

        guard let data = try? JSONEncoder().encode(snapshot) else { return }

        let tmpURL = dirURL.appendingPathComponent("tabs.tmp")
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

// MARK: - PersistedTab Public Extension

extension EditorTabStripStore.PersistedTab {
    /// 转换为文件 URL
    var fileURL: URL? {
        URL(fileURLWithPath: path)
    }
}
