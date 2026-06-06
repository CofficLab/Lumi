import Foundation
import SuperLogKit
import os

/// 窗口状态持久化存储（`window_states.json` 读写）
public final class WindowStateStore: @unchecked Sendable, SuperLog {
    public nonisolated static let emoji = "window"
    public nonisolated static let verbose: Bool = false
    public nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "window-state-store")

    public static let shared = WindowStateStore()

    private let queue: DispatchQueue
    private let databaseRootURLProvider: @Sendable () -> URL

    private static let pluginDirName = "WindowPersistence"
    private static let settingsDirName = "settings"
    private static let statesFileName = "window_states.json"
    private static let corruptStatesFileName = "window_states.corrupt.json"
    public static let maxPersistedWindowCount = 20

    public init(databaseRootURLProvider: @escaping @Sendable () -> URL = { AppConfig.getDBFolderURL() }) {
        self.queue = DispatchQueue(label: "WindowStateStore.queue.\(UUID().uuidString)", qos: .userInitiated)
        self.databaseRootURLProvider = databaseRootURLProvider
    }

    // MARK: - Save

    public func saveProject(
        windowId: UUID,
        projectPath: String?,
        createdAt: Date? = nil
    ) {
        merge(windowId: windowId) { existing in
            WindowPersistenceRecord(
                windowId: windowId,
                conversationId: existing?.conversationId,
                projectPath: projectPath,
                editorOpenFilePaths: existing?.editorOpenFilePaths,
                editorActiveFilePath: existing?.editorActiveFilePath,
                sidebarVisibility: existing?.sidebarVisibility,
                createdAt: existing?.createdAt ?? createdAt
            )
        }
        logSave(field: "project", windowId: windowId, detail: projectPath)
    }

    public func saveConversation(windowId: UUID, conversationId: UUID?) {
        merge(windowId: windowId) { existing in
            WindowPersistenceRecord(
                windowId: windowId,
                conversationId: conversationId,
                projectPath: existing?.projectPath,
                editorOpenFilePaths: existing?.editorOpenFilePaths,
                editorActiveFilePath: existing?.editorActiveFilePath,
                sidebarVisibility: existing?.sidebarVisibility,
                createdAt: existing?.createdAt
            )
        }
        logSave(field: "conversation", windowId: windowId, detail: conversationId?.uuidString)
    }

    public func saveSidebar(windowId: UUID, sidebarVisibility: Bool) {
        merge(windowId: windowId) { existing in
            WindowPersistenceRecord(
                windowId: windowId,
                conversationId: existing?.conversationId,
                projectPath: existing?.projectPath,
                editorOpenFilePaths: existing?.editorOpenFilePaths,
                editorActiveFilePath: existing?.editorActiveFilePath,
                sidebarVisibility: sidebarVisibility,
                createdAt: existing?.createdAt
            )
        }
        logSave(field: "sidebar", windowId: windowId, detail: String(sidebarVisibility))
    }

    public func saveEditor(
        windowId: UUID,
        editorOpenFilePaths: [String]?,
        editorActiveFilePath: String?
    ) {
        merge(windowId: windowId) { existing in
            WindowPersistenceRecord(
                windowId: windowId,
                conversationId: existing?.conversationId,
                projectPath: existing?.projectPath,
                editorOpenFilePaths: editorOpenFilePaths,
                editorActiveFilePath: editorActiveFilePath,
                sidebarVisibility: existing?.sidebarVisibility,
                createdAt: existing?.createdAt
            )
        }
        logSave(field: "editor", windowId: windowId, detail: editorActiveFilePath)
    }

    public func saveAll(_ records: [WindowPersistenceRecord]) {
        let capped = sanitizedRecords(records)
        queue.async { [self] in
            persist(capped)
        }
    }

    public func saveAllSynchronously(_ records: [WindowPersistenceRecord]) {
        let capped = sanitizedRecords(records)
        queue.sync { [self] in
            persist(capped)
        }
    }

    // MARK: - Load

    public func loadAll() -> [WindowPersistenceRecord] {
        sanitizedRecords(loadWindowStates())
    }

    public func record(for windowId: UUID) -> WindowPersistenceRecord? {
        loadWindowStates().first { $0.windowId == windowId }
    }

    // MARK: - Internal

    private func merge(
        windowId: UUID,
        build: @escaping @Sendable (WindowPersistenceRecord?) -> WindowPersistenceRecord
    ) {
        queue.async { [self] in
            var records = loadRecords()
            if let index = records.firstIndex(where: { $0.windowId == windowId }) {
                let updated = build(records[index])
                records[index] = updated
            } else {
                let updated = build(nil)
                records.append(updated)
            }
            persist(records)
        }
    }

    private func loadWindowStates() -> [WindowPersistenceRecord] {
        queue.sync { loadRecords() }
    }

    private func loadRecords() -> [WindowPersistenceRecord] {
        let fileURL = statesFileURL()
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            if Self.verbose {
                Self.logger.info("\(Self.t)window_states.json missing at \(fileURL.path, privacy: .public)")
            }
            return []
        }
        guard let data = try? Data(contentsOf: fileURL) else {
            if Self.verbose {
                Self.logger.error("\(Self.t)failed to read window_states.json")
            }
            quarantineCorruptStatesFile()
            return []
        }
        do {
            let records = try JSONDecoder().decode([WindowPersistenceRecord].self, from: data)
            if Self.verbose {
                Self.logger.info("\(Self.t)decoded \(records.count, privacy: .public) window state record(s)")
            }
            return sanitizedRecords(records)
        } catch {
            if Self.verbose {
                Self.logger.error(
                    "\(Self.t)decode window_states.json failed: \(String(describing: error), privacy: .public)"
                )
            }
            quarantineCorruptStatesFile()
            return []
        }
    }

    private func persist(_ records: [WindowPersistenceRecord]) {
        let sanitized = sanitizedRecords(records)
        guard let data = try? JSONEncoder().encode(sanitized) else {
            if Self.verbose {
                Self.logger.error("\(Self.t)failed to encode window state records")
            }
            return
        }

        let fileManager = FileManager.default
        let settingsDir = settingsDirURL()
        do {
            try fileManager.createDirectory(at: settingsDir, withIntermediateDirectories: true, attributes: nil)
        } catch {
            if Self.verbose {
                Self.logger.error(
                    "\(Self.t)failed to create settings dir: \(String(describing: error), privacy: .public)"
                )
            }
            return
        }

        let fileURL = statesFileURL()
        do {
            try data.write(to: fileURL, options: .atomic)
            if Self.verbose {
                let projectSummary = sanitized
                    .map { $0.projectPath ?? "nil" }
                    .joined(separator: ", ")
                Self.logger.info(
                    "\(Self.t)persisted \(sanitized.count, privacy: .public) record(s) at \(fileURL.path, privacy: .public); projects=[\(projectSummary, privacy: .public)]"
                )
            }
        } catch {
            if Self.verbose {
                Self.logger.error(
                    "\(Self.t)failed to write \(fileURL.path, privacy: .public): \(String(describing: error), privacy: .public)"
                )
            }
        }
    }

    private func settingsDirURL() -> URL {
        databaseRootURLProvider()
            .appendingPathComponent(Self.pluginDirName, isDirectory: true)
            .appendingPathComponent(Self.settingsDirName, isDirectory: true)
    }

    private func statesFileURL() -> URL {
        settingsDirURL()
            .appendingPathComponent(Self.statesFileName, isDirectory: false)
    }

    private func corruptStatesFileURL() -> URL {
        settingsDirURL()
            .appendingPathComponent(Self.corruptStatesFileName, isDirectory: false)
    }

    private func sanitizedRecords(_ records: [WindowPersistenceRecord]) -> [WindowPersistenceRecord] {
        var seen = Set<UUID>()
        var sanitized: [WindowPersistenceRecord] = []
        sanitized.reserveCapacity(min(records.count, Self.maxPersistedWindowCount))

        for record in records where seen.insert(record.windowId).inserted {
            sanitized.append(record)
            if sanitized.count == Self.maxPersistedWindowCount {
                break
            }
        }

        return sanitized
    }

    private func quarantineCorruptStatesFile() {
        let fileManager = FileManager.default
        let fileURL = statesFileURL()
        guard fileManager.fileExists(atPath: fileURL.path) else { return }

        do {
            let corruptURL = corruptStatesFileURL()
            if fileManager.fileExists(atPath: corruptURL.path) {
                try fileManager.removeItem(at: corruptURL)
            }
            try fileManager.moveItem(at: fileURL, to: corruptURL)
        } catch {
            if Self.verbose {
                Self.logger.error(
                    "\(Self.t)failed to quarantine corrupt window state file: \(String(describing: error), privacy: .public)"
                )
            }
        }
    }

    private func logSave(field: String, windowId: UUID, detail: String?) {
        if Self.verbose {
            Self.logger.info(
                "\(Self.t)save \(field, privacy: .public) window=\(windowId.uuidString.prefix(8), privacy: .public) value=\(detail ?? "nil", privacy: .public)"
            )
        }
    }
}
