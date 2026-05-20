import Foundation

/// 窗口状态持久化存储
/// 负责窗口状态的磁盘读写，独立于内核（WindowManager）。
final class WindowStateStore: @unchecked Sendable {
    private let queue = DispatchQueue(label: "WindowStateStore.queue", qos: .userInitiated)

    private static let pluginDirName = "WindowPersistence"
    private static let settingsDirName = "settings"
    private static let statesFileName = "window_states.json"
    private static let tmpFileName = "window_states.tmp"

    // MARK: - Public API

    /// 从 WindowScope 列表保存窗口状态（异步）
    @MainActor
    func saveWindowStates(from scopes: [WindowScope]) {
        let records = scopes.map { scope in
            WindowPersistenceRecord(
                windowId: scope.id,
                conversationId: scope.selectedConversationId,
                projectPath: scope.projectPath,
                activePanel: scope.activePanel.rawValue,
                editorState: scope.editorState,
                sidebarVisibility: scope.sidebarVisibility,
                createdAt: scope.createdAt
            )
        }
        queue.async { [self] in
            persist(records)
        }
    }

    /// 加载所有窗口的状态快照（同步）
    func loadWindowStates() -> [WindowPersistenceRecord] {
        queue.sync { [self] in
            guard let data = try? Data(contentsOf: statesFileURL()) else { return [] }
            return (try? JSONDecoder().decode([WindowPersistenceRecord].self, from: data)) ?? []
        }
    }

    /// 清除所有窗口状态
    func clearWindowStates() {
        queue.async { [self] in
            try? FileManager.default.removeItem(at: statesFileURL())
        }
    }

    // MARK: - Internal

    private func persist(_ records: [WindowPersistenceRecord]) {
        guard let data = try? JSONEncoder().encode(records) else { return }

        let fileManager = FileManager.default
        let settingsDir = settingsDirURL()
        try? fileManager.createDirectory(at: settingsDir, withIntermediateDirectories: true, attributes: nil)

        let fileURL = statesFileURL()
        let tmpURL = settingsDir.appendingPathComponent(Self.tmpFileName, isDirectory: false)

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

    private func settingsDirURL() -> URL {
        AppConfig.getDBFolderURL()
            .appendingPathComponent(Self.pluginDirName, isDirectory: true)
            .appendingPathComponent(Self.settingsDirName, isDirectory: true)
    }

    private func statesFileURL() -> URL {
        settingsDirURL()
            .appendingPathComponent(Self.statesFileName, isDirectory: false)
    }
}
