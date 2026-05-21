import Foundation
import os

/// 窗口状态持久化存储（`window_states.json` 读写）。
final class WindowStateStore: @unchecked Sendable {
    private static let logger = Logger(
        subsystem: "com.coffic.lumi",
        category: "plugin.window-persistence.store"
    )
    private let queue = DispatchQueue(label: "WindowStateStore.queue", qos: .userInitiated)

    private static let pluginDirName = "WindowPersistence"
    private static let settingsDirName = "settings"
    private static let statesFileName = "window_states.json"
    private static let tmpFileName = "window_states.tmp"
    static let maxPersistedWindowCount = 20

    // MARK: - Public API

    @MainActor
    func saveWindowStates(from containers: [WindowContainer]) {
        let records = records(from: containers)
        queue.async { [self] in
            persist(records)
        }
    }

    @MainActor
    func saveWindowStatesSynchronously(from containers: [WindowContainer]) {
        let records = records(from: containers)
        queue.sync { [self] in
            persist(records)
        }
    }

    func loadWindowStates() -> [WindowPersistenceRecord] {
        queue.sync { [self] in
            let fileURL = statesFileURL()
            guard FileManager.default.fileExists(atPath: fileURL.path) else {
                Self.logger.info("window_states.json missing at \(fileURL.path, privacy: .public)")
                return []
            }
            guard let data = try? Data(contentsOf: fileURL) else {
                Self.logger.error("failed to read window_states.json")
                return []
            }
            do {
                let records = try JSONDecoder().decode([WindowPersistenceRecord].self, from: data)
                Self.logger.info("decoded \(records.count, privacy: .public) window state record(s)")
                return records
            } catch {
                Self.logger.error("decode window_states.json failed: \(String(describing: error), privacy: .public)")
                return []
            }
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

    @MainActor
    private func records(from containers: [WindowContainer]) -> [WindowPersistenceRecord] {
        containers.prefix(Self.maxPersistedWindowCount).map { container in
            WindowPersistenceRecord(
                windowId: container.id,
                conversationId: container.selectedConversationId,
                projectPath: container.projectPath,
                activePanel: container.activePanel.rawValue,
                editorState: container.editorState,
                sidebarVisibility: container.sidebarVisibility,
                createdAt: container.createdAt
            )
        }
    }
}
