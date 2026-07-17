import Foundation
import LumiCoreKit

struct TempFileInfo: Sendable {
    let name: String
    let path: String
    let size: Int64
    let modifiedAt: Date
}

enum TempFileStorageError: LocalizedError {
    case invalidFilename
    case pathTraversal
    case fileNotFound(String)
    case readFailed(String)

    var errorDescription: String? {
        switch self {
        case .invalidFilename:
            "Filename must be a non-empty relative path."
        case .pathTraversal:
            "Filename must stay within the temp storage directory."
        case .fileNotFound(let name):
            "Temp file not found: \(name)"
        case .readFailed(let reason):
            "Failed to read temp file: \(reason)"
        }
    }
}

/// 管理 Agent 临时文件目录的读写与过期清理。
actor TempFileStorageService {
    static let shared = TempFileStorageService()

    private let fileManager = FileManager.default
    private let store = AgentTempStoragePluginLocalStore.shared
    private let filesDirectory: URL

    private init() {
        let pluginDir = AgentTempStoragePluginRuntimeBridge.pluginDirectory
            ?? AgentTempStoragePluginRuntimeBridge.fallbackRootDirectory.appendingPathComponent(AgentTempStoragePluginRuntimeBridge.pluginName, isDirectory: true)
        filesDirectory = pluginDir.appendingPathComponent("files", isDirectory: true)
        try? FileManager.default.createDirectory(at: filesDirectory, withIntermediateDirectories: true)
    }

    var storageDirectoryPath: String {
        filesDirectory.path
    }

    func purgeExpiredFiles() {
        let retentionDays = store.retentionDays
        guard let cutoff = Calendar.current.date(byAdding: .day, value: -retentionDays, to: Date()) else {
            return
        }

        guard let entries = try? fileManager.contentsOfDirectory(
            at: filesDirectory,
            includingPropertiesForKeys: [.contentModificationDateKey, .isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else {
            return
        }

        for entry in entries {
            let values = try? entry.resourceValues(forKeys: [.contentModificationDateKey, .isDirectoryKey])
            if values?.isDirectory == true {
                continue
            }
            guard let modifiedAt = values?.contentModificationDate, modifiedAt < cutoff else {
                continue
            }
            try? fileManager.removeItem(at: entry)
        }
    }

    func write(filename: String, content: String) throws -> String {
        purgeExpiredFiles()
        let url = try resolveSafeURL(for: filename)
        try fileManager.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try content.write(to: url, atomically: true, encoding: .utf8)
        return url.path
    }

    func read(filename: String) throws -> String {
        purgeExpiredFiles()
        let url = try resolveSafeURL(for: filename)
        guard fileManager.fileExists(atPath: url.path) else {
            throw TempFileStorageError.fileNotFound(filename)
        }
        do {
            return try String(contentsOf: url, encoding: .utf8)
        } catch {
            throw TempFileStorageError.readFailed(error.localizedDescription)
        }
    }

    func listFiles() throws -> [TempFileInfo] {
        purgeExpiredFiles()
        guard let entries = try? fileManager.contentsOfDirectory(
            at: filesDirectory,
            includingPropertiesForKeys: [.fileSizeKey, .contentModificationDateKey, .isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }

        return entries.compactMap { url in
            let values = try? url.resourceValues(forKeys: [.fileSizeKey, .contentModificationDateKey, .isDirectoryKey])
            guard values?.isDirectory != true else { return nil }
            let relativePath = url.path.replacingOccurrences(
                of: filesDirectory.path + "/",
                with: ""
            )
            return TempFileInfo(
                name: relativePath,
                path: url.path,
                size: Int64(values?.fileSize ?? 0),
                modifiedAt: values?.contentModificationDate ?? .distantPast
            )
        }
        .sorted { $0.modifiedAt > $1.modifiedAt }
    }

    private func resolveSafeURL(for filename: String) throws -> URL {
        let trimmed = filename.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw TempFileStorageError.invalidFilename
        }
        guard !trimmed.hasPrefix("/") else {
            throw TempFileStorageError.invalidFilename
        }

        let components = trimmed.split(separator: "/", omittingEmptySubsequences: false).map(String.init)
        guard !components.contains("..") else {
            throw TempFileStorageError.pathTraversal
        }

        let url = filesDirectory.appendingPathComponent(trimmed)
        let resolved = url.standardizedFileURL
        let root = filesDirectory.standardizedFileURL.path
        let resolvedPath = resolved.path
        guard resolvedPath == root || resolvedPath.hasPrefix(root + "/") else {
            throw TempFileStorageError.pathTraversal
        }
        return resolved
    }
}
