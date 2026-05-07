import Foundation
import LanguageServerProtocol

/// WorkspaceEdit 文件操作执行器（后台 actor）
///
/// 将文件创建/重命名/删除操作从主线程移至后台 actor 执行，
/// 避免文件 I/O 阻塞 UI 线程。
///
/// ## 线程模型
/// - 自身标记 `actor`，所有文件操作在后台线程执行
/// - 仅 `fileURL(from:)` 保持静态方法（纯计算，无需隔离）
actor WorkspaceEditFileOperationsExecutor {

    // MARK: - 单例

    static let shared = WorkspaceEditFileOperationsExecutor()

    // MARK: - 公共 API

    /// 应用 CreateFile 操作（后台执行）
    func applyCreateFile(_ operation: CreateFile) async -> Bool {
        await applyCreateFile(
            uri: operation.uri,
            overwrite: operation.options?.overwrite == true,
            ignoreIfExists: operation.options?.ignoreIfExists == true
        )
    }

    /// 应用 RenameFile 操作（后台执行）
    func applyRenameFile(_ operation: RenameFile) async -> Bool {
        await applyRenameFile(
            oldURI: operation.oldUri,
            newURI: operation.newUri,
            overwrite: operation.options.overwrite == true,
            ignoreIfExists: operation.options.ignoreIfExists == true
        )
    }

    /// 应用 DeleteFile 操作（后台执行）
    func applyDeleteFile(_ operation: DeleteFile) async -> Bool {
        await applyDeleteFile(
            uri: operation.uri,
            recursive: operation.options.recursive == true,
            ignoreIfNotExists: operation.options.ignoreIfNotExists == true
        )
    }

    /// 应用 CreateFile（直接调用）
    func applyCreateFile(uri: String, overwrite: Bool, ignoreIfExists: Bool) async -> Bool {
        guard let fileURL = WorkspaceEditFileOperations.fileURL(from: uri) else { return false }
        let fm = FileManager.default
        let exists = fm.fileExists(atPath: fileURL.path)

        if exists {
            if overwrite {
                do {
                    try fm.removeItem(at: fileURL)
                } catch {
                    return false
                }
            } else if ignoreIfExists {
                return true
            } else {
                return false
            }
        }

        do {
            try fm.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        } catch {
            return false
        }
        return fm.createFile(atPath: fileURL.path, contents: nil)
    }

    /// 应用 RenameFile（直接调用）
    func applyRenameFile(
        oldURI: String,
        newURI: String,
        overwrite: Bool,
        ignoreIfExists: Bool
    ) async -> Bool {
        guard let oldURL = WorkspaceEditFileOperations.fileURL(from: oldURI),
              let newURL = WorkspaceEditFileOperations.fileURL(from: newURI) else { return false }

        let fm = FileManager.default
        let oldExists = fm.fileExists(atPath: oldURL.path)
        if !oldExists {
            return ignoreIfExists
        }

        let newExists = fm.fileExists(atPath: newURL.path)
        if newExists {
            if overwrite {
                do {
                    try fm.removeItem(at: newURL)
                } catch {
                    return false
                }
            } else if ignoreIfExists {
                return true
            } else {
                return false
            }
        }

        do {
            try fm.createDirectory(at: newURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            try fm.moveItem(at: oldURL, to: newURL)
            return true
        } catch {
            return false
        }
    }

    /// 应用 DeleteFile（直接调用）
    func applyDeleteFile(uri: String, recursive: Bool, ignoreIfNotExists: Bool) async -> Bool {
        guard let targetURL = WorkspaceEditFileOperations.fileURL(from: uri) else { return false }
        let fm = FileManager.default
        let exists = fm.fileExists(atPath: targetURL.path)
        if !exists {
            return ignoreIfNotExists
        }

        do {
            var isDirectory: ObjCBool = false
            fm.fileExists(atPath: targetURL.path, isDirectory: &isDirectory)

            if isDirectory.boolValue, !recursive {
                let entries = try fm.contentsOfDirectory(atPath: targetURL.path)
                if !entries.isEmpty {
                    return false
                }
            }

            try fm.removeItem(at: targetURL)
            return true
        } catch {
            return false
        }
    }

    /// 批量应用 WorkspaceEdit 文件操作
    /// 互不依赖的操作可以并行执行
    func applyWorkspaceEdit(_ edit: WorkspaceEdit) async throws {
        var errors: [Error] = []

        guard let documentChanges = edit.documentChanges else {
            // 如果没有 documentChanges，检查是否有 changes
            if let textEdits = edit.changes {
                for (_, edits) in textEdits {
                    // Text edits 由 EditorCoordinator 处理，不在此处处理
                    _ = edits
                }
            }
            return
        }

        // 收集各类型操作
        var createOps: [CreateFile] = []
        var deleteOps: [DeleteFile] = []
        var renameOps: [RenameFile] = []

        for change in documentChanges {
            switch change {
            case .createFile(let op):
                createOps.append(op)
            case .deleteFile(let op):
                deleteOps.append(op)
            case .renameFile(let op):
                renameOps.append(op)
            case .textDocumentEdit:
                // Text edits 由 EditorCoordinator 处理
                break
            @unknown default:
                break
            }
        }

        // 并行执行文件创建操作
        if !createOps.isEmpty {
            await withTaskGroup(of: (Int, Bool).self) { group in
                for (index, op) in createOps.enumerated() {
                    group.addTask {
                        (index, await self.applyCreateFile(op))
                    }
                }
                for await (_, success) in group {
                    if !success {
                        errors.append(WorkspaceEditError.createFailed)
                    }
                }
            }
        }

        // 并行执行文件删除操作
        if !deleteOps.isEmpty {
            await withTaskGroup(of: (Int, Bool).self) { group in
                for (index, op) in deleteOps.enumerated() {
                    group.addTask {
                        (index, await self.applyDeleteFile(op))
                    }
                }
                for await (_, success) in group {
                    if !success {
                        errors.append(WorkspaceEditError.deleteFailed)
                    }
                }
            }
        }

        // 按顺序执行文件重命名操作（重命名可能有依赖关系）
        if !renameOps.isEmpty {
            for op in renameOps {
                let success = await applyRenameFile(op)
                if !success {
                    errors.append(WorkspaceEditError.renameFailed)
                }
            }
        }

        if !errors.isEmpty {
            throw WorkspaceEditError.partialFailure(errors: errors)
        }
    }

    // MARK: - 错误类型

    enum WorkspaceEditError: Error, LocalizedError {
        case createFailed
        case deleteFailed
        case renameFailed
        case partialFailure(errors: [Error])

        var errorDescription: String? {
            switch self {
            case .createFailed: return "Failed to create file"
            case .deleteFailed: return "Failed to delete file"
            case .renameFailed: return "Failed to rename file"
            case .partialFailure(let errors):
                return "Partial failure applying workspace edit: \(errors.count) operations failed"
            }
        }
    }
}

// MARK: - 静态工具方法（保持向后兼容）

enum WorkspaceEditFileOperations {
    static func applyCreateFile(_ operation: CreateFile) -> Bool {
        applyCreateFile(
            uri: operation.uri,
            overwrite: operation.options?.overwrite == true,
            ignoreIfExists: operation.options?.ignoreIfExists == true
        )
    }

    static func applyRenameFile(_ operation: RenameFile) -> Bool {
        applyRenameFile(
            oldURI: operation.oldUri,
            newURI: operation.newUri,
            overwrite: operation.options.overwrite == true,
            ignoreIfExists: operation.options.ignoreIfExists == true
        )
    }

    static func applyDeleteFile(_ operation: DeleteFile) -> Bool {
        applyDeleteFile(
            uri: operation.uri,
            recursive: operation.options.recursive == true,
            ignoreIfNotExists: operation.options.ignoreIfNotExists == true
        )
    }

    static func applyCreateFile(uri: String, overwrite: Bool, ignoreIfExists: Bool) -> Bool {
        guard let fileURL = fileURL(from: uri) else { return false }
        let fm = FileManager.default
        let exists = fm.fileExists(atPath: fileURL.path)

        if exists {
            if overwrite {
                do {
                    try fm.removeItem(at: fileURL)
                } catch {
                    return false
                }
            } else if ignoreIfExists {
                return true
            } else {
                return false
            }
        }

        do {
            try fm.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        } catch {
            return false
        }
        return fm.createFile(atPath: fileURL.path, contents: nil)
    }

    static func applyRenameFile(
        oldURI: String,
        newURI: String,
        overwrite: Bool,
        ignoreIfExists: Bool
    ) -> Bool {
        guard let oldURL = fileURL(from: oldURI),
              let newURL = fileURL(from: newURI) else { return false }

        let fm = FileManager.default
        let oldExists = fm.fileExists(atPath: oldURL.path)
        if !oldExists {
            return ignoreIfExists
        }

        let newExists = fm.fileExists(atPath: newURL.path)
        if newExists {
            if overwrite {
                do {
                    try fm.removeItem(at: newURL)
                } catch {
                    return false
                }
            } else if ignoreIfExists {
                return true
            } else {
                return false
            }
        }

        do {
            try fm.createDirectory(at: newURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            try fm.moveItem(at: oldURL, to: newURL)
            return true
        } catch {
            return false
        }
    }

    static func applyDeleteFile(uri: String, recursive: Bool, ignoreIfNotExists: Bool) -> Bool {
        guard let targetURL = fileURL(from: uri) else { return false }
        let fm = FileManager.default
        let exists = fm.fileExists(atPath: targetURL.path)
        if !exists {
            return ignoreIfNotExists
        }

        do {
            var isDirectory: ObjCBool = false
            fm.fileExists(atPath: targetURL.path, isDirectory: &isDirectory)

            if isDirectory.boolValue, !recursive {
                let entries = try fm.contentsOfDirectory(atPath: targetURL.path)
                if !entries.isEmpty {
                    return false
                }
            }

            try fm.removeItem(at: targetURL)
            return true
        } catch {
            return false
        }
    }

    static func fileURL(from uri: String) -> URL? {
        if uri.hasPrefix("/") {
            return URL(fileURLWithPath: uri).standardizedFileURL
        }
        guard let url = URL(string: uri) else { return nil }
        if url.isFileURL {
            return url.standardizedFileURL
        }
        return nil
    }
}
