import Foundation
import LumiKernel
import XcodeKit

/// Resolves the EditorSwiftPlugin storage directory per plugin-storage-rules.
enum EditorSwiftBuildServerStore {
    static let pluginDirectoryName = "EditorSwiftPlugin"
    private static let legacyPluginDirectoryName = "EditorXcodePlugin"

    static func makeStore() -> XcodeBuildServerStore {
        let pluginDirectory = EditorSwiftPluginRuntimeBridge.pluginSubdirectory
            ?? EditorSwiftPluginRuntimeBridge.fallbackRootDirectory.appendingPathComponent(pluginDirectoryName, isDirectory: true)
        migrateLegacyStorageIfNeeded(to: pluginDirectory)
        try? FileManager.default.createDirectory(
            at: pluginDirectory,
            withIntermediateDirectories: true
        )
        return XcodeBuildServerStore(pluginDirectoryURL: pluginDirectory)
    }

    static func migrateLegacyStorageForTesting(legacyDirectory: URL, pluginDirectory: URL) {
        migrateLegacyStorage(from: legacyDirectory, to: pluginDirectory)
    }

    private static func migrateLegacyStorageIfNeeded(to pluginDirectory: URL) {
        let dataRoot = EditorSwiftPluginRuntimeBridge.dataRootDirectory ?? EditorSwiftPluginRuntimeBridge.fallbackRootDirectory
        let appDirectory = dataRoot.deletingLastPathComponent()
        let legacyCandidates = [
            appDirectory.appendingPathComponent(legacyPluginDirectoryName, isDirectory: true),
            dataRoot.appendingPathComponent(legacyPluginDirectoryName, isDirectory: true),
        ]

        for legacyDirectory in legacyCandidates where legacyDirectory != pluginDirectory {
            migrateLegacyStorage(from: legacyDirectory, to: pluginDirectory)
        }
    }

    private static func migrateLegacyStorage(from legacyDirectory: URL, to pluginDirectory: URL) {
        let fileManager = FileManager.default

        guard legacyDirectory != pluginDirectory,
              fileManager.fileExists(atPath: legacyDirectory.path) else {
            return
        }

        guard let legacyEntries = try? fileManager.contentsOfDirectory(
            at: legacyDirectory,
            includingPropertiesForKeys: nil
        ) else {
            return
        }

        for entry in legacyEntries {
            let destination = pluginDirectory.appendingPathComponent(entry.lastPathComponent, isDirectory: true)
            guard !fileManager.fileExists(atPath: destination.path) else { continue }
            do {
                try fileManager.createDirectory(at: pluginDirectory, withIntermediateDirectories: true)
                try fileManager.moveItem(at: entry, to: destination)
            } catch {
                SwiftPluginLog.logger.error(
                    "Failed to migrate build server data from \(legacyDirectory.path) to \(pluginDirectory.path): \(error.localizedDescription)"
                )
            }
        }

        if let remaining = try? fileManager.contentsOfDirectory(at: legacyDirectory, includingPropertiesForKeys: nil),
           remaining.isEmpty {
            try? fileManager.removeItem(at: legacyDirectory)
        }
    }
}
