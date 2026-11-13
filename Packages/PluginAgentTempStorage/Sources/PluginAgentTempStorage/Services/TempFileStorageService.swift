import Foundation

struct TempFileInfo: Sendable {
    let name: String
    let path: String
    let size: Int64
    let modifiedAt: Date
}

enum TempFileStorageError: LocalizedError, Equatable {
    case invalidFilename
    case pathTraversal
    case fileNotFound(String)
    case readFailed(String)
    case settingsUnavailable(String)
    case purgeFailed(String)

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
        case .settingsUnavailable(let reason):
            "Failed to read temp storage settings: \(reason)"
        case .purgeFailed(let reason):
            "Failed to delete expired temp files: \(reason)"
        }
    }
}

/// 管理 Agent 临时文件目录的读写与过期清理。
actor TempFileStorageService {
    static let shared = TempFileStorageService()

    private let fileManager = FileManager.default
    private let filesDirectory: URL
    private let retentionDays: () throws -> Int

    private init() {
        let pluginDir = AgentTempStoragePluginRuntimeBridge.resolvedPluginDirectory
        filesDirectory = pluginDir.appendingPathComponent("files", isDirectory: true)
        try? FileManager.default.createDirectory(at: filesDirectory, withIntermediateDirectories: true)
        self.retentionDays = { try AgentTempStoragePluginLocalStore.shared.resolvedRetentionDays() }
    }

    /// Test-only initializer: point the service at an isolated directory with a fixed retention window.
    init(directory: URL, retentionDays: Int) {
        self.init(directory: directory, retentionDaysProvider: { retentionDays })
    }

    /// Test-only initializer with a dynamic (possibly failing) retention provider.
    init(directory: URL, retentionDaysProvider: @escaping @Sendable () throws -> Int) {
        filesDirectory = directory
        self.retentionDays = retentionDaysProvider
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    var storageDirectoryPath: String {
        filesDirectory.path
    }

    func purgeExpiredFiles(now: Date = Date()) throws {
        let retentionDays: Int
        do {
            retentionDays = try self.retentionDays()
        } catch {
            // 配置存在但不可读时不能猜测保留策略：中止清理并保留全部文件。
            throw TempFileStorageError.settingsUnavailable(error.localizedDescription)
        }
        guard let cutoff = Calendar.current.date(byAdding: .day, value: -retentionDays, to: now) else {
            return
        }

        // 写入支持嵌套相对路径，清理必须与 listFiles 一样递归枚举，
        // 否则子目录里的过期文件永远不会被删除（#200）。
        guard let enumerator = fileManager.enumerator(
            at: filesDirectory,
            includingPropertiesForKeys: [.contentModificationDateKey, .isDirectoryKey],
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        ) else {
            return
        }

        var failures: [(name: String, reason: String)] = []
        for case let entry as URL in enumerator {
            let values = try? entry.resourceValues(forKeys: [.contentModificationDateKey, .isDirectoryKey])
            if values?.isDirectory == true {
                continue
            }
            guard let modifiedAt = values?.contentModificationDate, modifiedAt < cutoff else {
                continue
            }
            do {
                try fileManager.removeItem(at: entry)
            } catch {
                // 删除失败不能静默：过期内容仍在磁盘上，随后 read/list 若照样成功
                // 就会把本该被清理的数据当作有效结果返回。记录后继续清理其他条目。
                failures.append((entry.lastPathComponent, error.localizedDescription))
            }
        }

        guard failures.isEmpty else {
            let detail = failures
                .map { "\($0.name) (\($0.reason))" }
                .joined(separator: ", ")
            throw TempFileStorageError.purgeFailed(detail)
        }
    }

    func write(filename: String, content: String) throws -> String {
        try purgeExpiredFiles()
        let url = try resolveSafeURL(for: filename)
        try fileManager.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try content.write(to: url, atomically: true, encoding: .utf8)
        return url.path
    }

    func read(filename: String) throws -> String {
        try purgeExpiredFiles()
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

    /// 递归枚举存储根目录下的所有文件。
    ///
    /// 写入与读取都支持嵌套相对路径（`notes/today.md`），因此列表也必须递归，
    /// 否则嵌套文件可读写却永远不可见。`name` 返回相对根目录的路径。
    func listFiles() throws -> [TempFileInfo] {
        try purgeExpiredFiles()
        let keys: [URLResourceKey] = [.fileSizeKey, .contentModificationDateKey, .isDirectoryKey]
        guard let enumerator = fileManager.enumerator(
            at: filesDirectory,
            includingPropertiesForKeys: keys,
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        ) else {
            return []
        }

        let rootPath = filesDirectory.resolvingSymlinksInPath().standardizedFileURL.path
        var files: [TempFileInfo] = []
        for case let url as URL in enumerator {
            let values = try? url.resourceValues(forKeys: Set(keys))
            guard values?.isDirectory != true else { continue }
            let resolvedURL = url.resolvingSymlinksInPath().standardizedFileURL
            let relativePath = resolvedURL.path.hasPrefix(rootPath + "/")
                ? String(resolvedURL.path.dropFirst(rootPath.count + 1))
                : url.lastPathComponent
            files.append(
                TempFileInfo(
                    name: relativePath,
                    path: url.path,
                    size: Int64(values?.fileSize ?? 0),
                    modifiedAt: values?.contentModificationDate ?? .distantPast
                )
            )
        }
        return files.sorted { $0.modifiedAt > $1.modifiedAt }
    }

    /// 把工具传入的相对路径映射为安全 URL。
    ///
    /// 文件名不做 trim：macOS 允许首尾空格，`report.md` 与 ` report.md ` 是两个
    /// 不同文件，裁剪会让后者静默覆盖前者。仅对「空或纯空白」这类无意义名称
    /// 明确报错，不做任何改写。
    private func resolveSafeURL(for filename: String) throws -> URL {
        guard !filename.isEmpty,
              filename.contains(where: { !$0.isWhitespace }) else {
            throw TempFileStorageError.invalidFilename
        }
        guard !filename.hasPrefix("/") else {
            throw TempFileStorageError.invalidFilename
        }

        let components = filename.split(separator: "/", omittingEmptySubsequences: false).map(String.init)
        guard !components.contains("..") else {
            throw TempFileStorageError.pathTraversal
        }

        let url = filesDirectory.appendingPathComponent(filename)
        let candidate = url.standardizedFileURL
        let root = filesDirectory.standardizedFileURL.path
        let candidatePath = candidate.path
        guard candidatePath == root || candidatePath.hasPrefix(root + "/") else {
            throw TempFileStorageError.pathTraversal
        }

        // 词法前缀检查挡不住符号链接：目录内指向外部的文件或目录链接
        // 会被 Foundation 的读写跟随，越界访问存储目录之外的内容（#232）。
        // 解析后的路径也必须留在根目录内（与 PlanFileStorageService 一致）。
        let resolvedRoot = filesDirectory.resolvingSymlinksInPath().standardizedFileURL
        let resolved = resolvedDestination(of: candidate)
        guard resolved.path == resolvedRoot.path || resolved.path.hasPrefix(resolvedRoot.path + "/") else {
            throw TempFileStorageError.pathTraversal
        }
        return candidate
    }

    /// 解析候选路径的真实落点。
    ///
    /// `resolvingSymlinksInPath` 对「不存在的路径」整体不做解析：新建文件
    /// `exports/data.json` 的叶子不存在时，中间已存在的符号链接目录 `exports`
    /// 也不会被解析。因此先回退到最近的存在祖先，解析它，再拼回不存在的尾部
    /// （尾部组件尚未创建，不可能是符号链接）。
    private func resolvedDestination(of candidate: URL) -> URL {
        var existing = candidate
        var tail: [String] = []
        // 用 lstat 语义判断存在：悬空符号链接本身也是目录项，必须参与解析，
        // 否则会被当作「不存在」跳过，写入时再被 Foundation 跟随到外部。
        while (try? fileManager.attributesOfItem(atPath: existing.path)) == nil {
            tail.append(existing.lastPathComponent)
            existing = existing.deletingLastPathComponent()
        }
        var resolved = existing.resolvingSymlinksInPath().standardizedFileURL
        for component in tail.reversed() {
            resolved = resolved.appendingPathComponent(component)
        }
        return resolved.standardizedFileURL
    }
}
