import Foundation

public struct PlanFileInfo: Sendable, Equatable {
    public let name: String
    public let path: String
    public let size: Int64
    public let modifiedAt: Date

    public init(name: String, path: String, size: Int64, modifiedAt: Date) {
        self.name = name
        self.path = path
        self.size = size
        self.modifiedAt = modifiedAt
    }
}

public enum PlanFileStorageError: LocalizedError, Equatable {
    case invalidFilename
    case pathTraversal
    case fileNotFound(String)
    case notAFile(String)
    case readFailed(String)

    public var errorDescription: String? {
        switch self {
        case .invalidFilename:
            "Plan filename must be a non-empty relative path."
        case .pathTraversal:
            "Plan filename must stay within the plan storage directory."
        case .fileNotFound(let filename):
            "Plan file not found: \(filename)"
        case .notAFile(let filename):
            "Plan path is not a regular file: \(filename)"
        case .readFailed(let reason):
            "Failed to read plan file: \(reason)"
        }
    }
}

/// Actor-isolated storage for agent-created plan documents.
public actor PlanFileStorageService {
    private let fileManager = FileManager.default
    private let plansDirectory: URL
    private let retentionDaysOverride: Int?

    public init(directory: URL, retentionDays: Int? = nil) throws {
        self.plansDirectory = directory.standardizedFileURL
        self.retentionDaysOverride = retentionDays.map { max(1, $0) }
        try fileManager.createDirectory(at: plansDirectory, withIntermediateDirectories: true)
    }

    public var storageDirectoryPath: String {
        plansDirectory.resolvingSymlinksInPath().standardizedFileURL.path
    }

    public var retentionDays: Int {
        retentionDaysOverride ?? AgentPlanStoragePluginLocalStore.shared.retentionDays
    }

    @discardableResult
    public func purgeExpiredFiles(now: Date = Date()) -> Int {
        guard let cutoff = Calendar.current.date(byAdding: .day, value: -retentionDays, to: now) else {
            return 0
        }

        var removedCount = 0
        for file in regularFiles() {
            guard file.modifiedAt < cutoff else { continue }
            do {
                try fileManager.removeItem(at: file.url)
                removedCount += 1
            } catch {
                // A failed cleanup should not make the next Agent operation fail.
            }
        }
        return removedCount
    }

    public func write(filename: String, content: String) throws -> String {
        _ = purgeExpiredFiles()
        let url = try resolveSafeURL(for: filename)
        try fileManager.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try content.write(to: url, atomically: true, encoding: .utf8)
        return url.path
    }

    public func read(filename: String) throws -> String {
        _ = purgeExpiredFiles()
        let url = try resolveSafeURL(for: filename)
        guard fileManager.fileExists(atPath: url.path) else {
            throw PlanFileStorageError.fileNotFound(filename)
        }
        guard isRegularFile(url) else {
            throw PlanFileStorageError.notAFile(filename)
        }

        do {
            return try String(contentsOf: url, encoding: .utf8)
        } catch {
            throw PlanFileStorageError.readFailed(error.localizedDescription)
        }
    }

    public func listFiles() -> [PlanFileInfo] {
        _ = purgeExpiredFiles()
        return regularFiles().map { file in
            PlanFileInfo(
                name: relativePath(for: file.url),
                path: file.url.path,
                size: file.size,
                modifiedAt: file.modifiedAt
            )
        }
        .sorted { $0.modifiedAt > $1.modifiedAt }
    }

    public func delete(filename: String) throws {
        _ = purgeExpiredFiles()
        let url = try resolveSafeURL(for: filename)
        guard fileManager.fileExists(atPath: url.path) else {
            throw PlanFileStorageError.fileNotFound(filename)
        }
        guard isRegularFile(url) else {
            throw PlanFileStorageError.notAFile(filename)
        }
        try fileManager.removeItem(at: url)
    }

    private struct RegularFile: Sendable {
        let url: URL
        let size: Int64
        let modifiedAt: Date
    }

    private func regularFiles() -> [RegularFile] {
        guard let enumerator = fileManager.enumerator(
            at: plansDirectory,
            includingPropertiesForKeys: [.isDirectoryKey, .fileSizeKey, .contentModificationDateKey],
            options: []
        ) else {
            return []
        }

        return enumerator.compactMap { item in
            guard let url = item as? URL,
                  let values = try? url.resourceValues(forKeys: [.isDirectoryKey, .fileSizeKey, .contentModificationDateKey]),
                  values.isDirectory != true else {
                return nil
            }
            return RegularFile(
                url: url,
                size: Int64(values.fileSize ?? 0),
                modifiedAt: values.contentModificationDate ?? .distantPast
            )
        }
    }

    private func isRegularFile(_ url: URL) -> Bool {
        guard let values = try? url.resourceValues(forKeys: [.isDirectoryKey]) else {
            return false
        }
        return values.isDirectory == false
    }

    private func relativePath(for url: URL) -> String {
        let rootPath = plansDirectory.resolvingSymlinksInPath().standardizedFileURL.path
        let prefix = rootPath.hasSuffix("/") ? rootPath : rootPath + "/"
        let resolvedPath = url.resolvingSymlinksInPath().standardizedFileURL.path
        return resolvedPath.hasPrefix(prefix) ? String(resolvedPath.dropFirst(prefix.count)) : url.lastPathComponent
    }

    private func resolveSafeURL(for filename: String) throws -> URL {
        let trimmed = filename.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !trimmed.hasPrefix("/") else {
            throw PlanFileStorageError.invalidFilename
        }

        let components = trimmed.split(separator: "/", omittingEmptySubsequences: false).map(String.init)
        guard !components.contains("..") else {
            throw PlanFileStorageError.pathTraversal
        }

        let root = plansDirectory.resolvingSymlinksInPath().standardizedFileURL
        let candidate = plansDirectory.appendingPathComponent(trimmed)
        let resolved = candidate.resolvingSymlinksInPath().standardizedFileURL
        guard resolved.path == root.path || resolved.path.hasPrefix(root.path + "/") else {
            throw PlanFileStorageError.pathTraversal
        }
        return resolved
    }
}
