import Foundation
import os
import SuperLogKit

enum LumiStorageMigration: SuperLog {
    private static let logger = Logger(subsystem: "com.coffic.lumi", category: "storage.migration")

    static func migrateMisplacedPluginDirectories(to dataRootDirectory: URL) {
        let appDirectory = dataRootDirectory.deletingLastPathComponent()
        guard let entries = try? FileManager.default.contentsOfDirectory(
            at: appDirectory,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else {
            return
        }

        for entry in entries {
            guard isDirectory(entry) else { continue }

            let name = entry.lastPathComponent
            guard shouldMigrateTopLevelEntry(named: name) else { continue }

            let destination = dataRootDirectory.appendingPathComponent(name, isDirectory: true)
            guard entry.standardizedFileURL != destination.standardizedFileURL else { continue }
            guard !FileManager.default.fileExists(atPath: destination.path) else { continue }

            do {
                try FileManager.default.createDirectory(
                    at: dataRootDirectory,
                    withIntermediateDirectories: true
                )
                try FileManager.default.moveItem(at: entry, to: destination)
                logger.info("\(Self.t)Migrated plugin storage directory \(name, privacy: .public) into data root")
            } catch {
                logger.error(
                    "Failed to migrate plugin storage directory \(name, privacy: .public): \(error.localizedDescription, privacy: .public)"
                )
            }
        }
    }

    private static func isDirectory(_ url: URL) -> Bool {
        (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true
    }

    private static func shouldMigrateTopLevelEntry(named name: String) -> Bool {
        if name.hasPrefix("db_") || name.hasPrefix("logs_") {
            return false
        }
        return true
    }
}
