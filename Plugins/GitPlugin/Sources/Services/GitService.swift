import Foundation
import SuperLogKit
import LibGit2Swift
import os
import SwiftUI

/// Git 服务
///
/// 完全基于 LibGit2Swift 的原生 Git 操作，不使用任何命令行调用。
/// 参考 GitOK 的 Project+File 实现。
///
/// ## 线程安全
///
/// 所有 LibGit2 操作通过串行队列 `gitQueue` 保护，避免并发访问 libgit2 C 库
/// 导致的竞态崩溃（`EXC_BAD_ACCESS` / `SIGSEGV`）。
/// 这是因为 libgit2 的 `git_repository` 对象不是线程安全的，
/// 并发打开同一仓库或并发读取 index 可能导致 C 层内存错误。
public final class GitService: @unchecked Sendable, SuperLog {
    public nonisolated static let verbose: Bool = true
    public nonisolated static let emoji = "🌿"
    public static let shared = GitService()

    /// 串行队列，保护所有 LibGit2 操作不被并发执行。
    /// libgit2 的 git_repository / git_index 等对象不是线程安全的，
    /// 必须串行化所有调用。
    private let gitQueue = DispatchQueue(label: "com.lumi.gitservice.libgit2", qos: .userInitiated)

    private init() {}

    /// 在 gitQueue 上执行 LibGit2 操作，并安全地将结果传回 async 调用方。
    ///
    /// 在调用 body 之前先验证路径是否为有效 Git 仓库，
    /// 避免 libgit2 C 层在无效仓库上触发 abort() 导致 EXC_BREAKPOINT 崩溃。
    private func performOnGitQueue<T: Sendable>(
        repoPath: String,
        body: @escaping @Sendable () throws -> T
    ) async throws -> T {
        try await GitAsyncBridge.perform(on: gitQueue) {
            guard LibGit2.isGitRepository(at: repoPath) else {
                throw GitServiceError.repositoryNotGit(path: repoPath)
            }
            return try body()
        }
    }

    // MARK: - Git Status

    public func getStatus(path: String?) async throws -> GitStatus {
        let repoPath = Self.resolvePath(path)

        return try await performOnGitQueue(repoPath: repoPath) {
            // 获取当前分支
            let branch = (try? LibGit2.getCurrentBranch(at: repoPath)) ?? ""

            // 获取变更文件列表
            let unstagedFiles = try LibGit2.getDiffFileList(at: repoPath, staged: false)
            let stagedFiles = try LibGit2.getDiffFileList(at: repoPath, staged: true)

            var modified: [String] = []
            var added: [String] = []
            var deleted: [String] = []
            var renamed: [String] = []
            var staged: [String] = []

            for file in unstagedFiles {
                switch file.changeType {
                case "M": modified.append(file.file)
                case "A": added.append(file.file)
                case "D": deleted.append(file.file)
                case "R": renamed.append(file.file)
                case "?": modified.append(file.file)
                default: modified.append(file.file)
                }
            }

            for file in stagedFiles {
                switch file.changeType {
                case "M", "A", "D", "R": staged.append(file.file)
                default: break
                }
            }

            // 获取远程 upstream
            let remote = try? LibGit2.getCurrentBranchInfo(at: repoPath)?.upstream

            return GitStatus(
                branch: branch,
                remote: remote,
                modified: modified,
                added: added,
                deleted: deleted,
                renamed: renamed,
                staged: staged
            )
        }
    }

    // MARK: - Git Diff

    public func getDiff(path: String?, staged: Bool, file: String?) async throws -> GitDiff {
        let repoPath = Self.resolvePath(path)

        return try await performOnGitQueue(repoPath: repoPath) {
            // 获取 diff 内容
            let content: String
            if let file = file {
                content = try LibGit2.getFileDiff(for: file, at: repoPath, staged: staged)
            } else {
                let files = try LibGit2.getDiffFileList(at: repoPath, staged: staged)
                content = files.map { $0.diff }.joined()
            }

            // 统计
            let files = try LibGit2.getDiffFileList(at: repoPath, staged: staged)
            let (insertions, deletions) = GitDiffStats.countInsertionsDeletions(in: content)

            let stats = !files.isEmpty ? GitDiffStats(filesChanged: files.count, insertions: insertions, deletions: deletions) : nil
            return GitDiff(content: content, stats: stats)
        }
    }

    // MARK: - Git Log

    public func getLog(path: String?, count: Int, branch: String?, file: String?) async throws -> [GitCommitLog] {
        let repoPath = Self.resolvePath(path)

        return try await performOnGitQueue(repoPath: repoPath) {
            let gitCommits = try LibGit2.getCommitList(at: repoPath, limit: count)

            let dateFormatter = ISO8601DateFormatter()

            return gitCommits.map { commit in
                GitCommitLog(
                    hash: commit.hash,
                    author: commit.author,
                    email: commit.email,
                    date: dateFormatter.string(from: commit.date),
                    message: commit.message.components(separatedBy: "\n").first ?? commit.message
                )
            }
        }
    }

    // MARK: - Log With Skip (for pagination)

    /// 带跳过的日志获取（分页加载）
    public func getLogWithSkip(path: String?, count: Int, skip: Int) async throws -> [GitCommitLog] {
        let repoPath = Self.resolvePath(path)

        return try await performOnGitQueue(repoPath: repoPath) {
            let gitCommits = try LibGit2.getCommitList(at: repoPath, limit: count, skip: skip)

            let dateFormatter = ISO8601DateFormatter()

            return gitCommits.map { commit in
                GitCommitLog(
                    hash: commit.hash,
                    author: commit.author,
                    email: commit.email,
                    date: dateFormatter.string(from: commit.date),
                    message: commit.message.components(separatedBy: "\n").first ?? commit.message
                )
            }
        }
    }

    // MARK: - Commit Detail

    /// 获取指定 commit 的详细信息
    ///
    /// 使用 `LibGit2.getCommitDetail` 直接按 hash 查找，避免遍历大量 commit。
    public func getCommitDetail(path: String?, hash: String) async throws -> GitCommitDetail {
        let repoPath = Self.resolvePath(path)

        return try await performOnGitQueue(repoPath: repoPath) {
            // 直接按 hash 查找 commit，不再遍历 500 个 commit
            guard let commit = try LibGit2.getCommitDetail(commitHash: hash, at: repoPath) else {
                throw NSError(domain: "GitService", code: -1, userInfo: [NSLocalizedDescriptionKey: "无法找到 commit \(hash.prefix(7))"])
            }

            // 使用 LibGit2Swift 获取变更文件列表（含精确变更类型和 diff）
            let diffFiles = try LibGit2.getCommitDiffFiles(atCommit: hash, at: repoPath)

            var insertions = 0, deletions = 0
            for file in diffFiles {
                let (ins, dels) = GitDiffStats.countInsertionsDeletions(in: file.diff)
                insertions += ins
                deletions += dels
            }

            let stats = !diffFiles.isEmpty ? GitDiffStats(
                filesChanged: diffFiles.count, insertions: insertions, deletions: deletions
            ) : nil

            let dateFormatter = ISO8601DateFormatter()

            return GitCommitDetail(
                hash: commit.hash,
                author: commit.author,
                email: commit.email,
                date: dateFormatter.string(from: commit.date),
                message: commit.message.components(separatedBy: "\n").first ?? commit.message,
                body: commit.body,
                stats: stats,
                changedFiles: diffFiles.map { $0.file }
            )
        }
    }

    // MARK: - Commit Changed Files

    /// 获取 commit 的变更文件列表（含精确变更类型）
    public func getCommitChangedFiles(path: String?, hash: String) throws -> [GitChangedFile] {
        let repoPath = Self.resolvePath(path)
        return try gitQueue.sync {
            let diffFiles = try LibGit2.getCommitDiffFiles(atCommit: hash, at: repoPath)
            return diffFiles.map { file in
                GitChangedFile(path: file.file, changeType: .fromString(file.changeType))
            }
        }
    }

    // MARK: - Working State

    /// 获取未提交变更的文件列表
    public func getUncommittedChanges(path: String?) async throws -> [GitChangedFile] {
        let repoPath = Self.resolvePath(path)

        return try await performOnGitQueue(repoPath: repoPath) {
            let unstagedFiles = try LibGit2.getDiffFileList(at: repoPath, staged: false)
            let stagedFiles = try LibGit2.getDiffFileList(at: repoPath, staged: true)

            // 合并去重（staged 优先）
            var merged: [String: GitChangedFile] = [:]
            for file in stagedFiles {
                merged[file.file] = GitChangedFile(path: file.file, changeType: .fromString(file.changeType))
            }
            for file in unstagedFiles {
                if merged[file.file] == nil {
                    merged[file.file] = GitChangedFile(path: file.file, changeType: .fromString(file.changeType))
                }
            }

            return Array(merged.values).sorted { $0.path < $1.path }
        }
    }

    // MARK: - File Content Change

    /// 获取未提交文件的内容差异
    public func getUncommittedFileContentChange(path: String?, file: String) async throws -> (before: String?, after: String?) {
        let repoPath = Self.resolvePath(path)
        return try await performOnGitQueue(repoPath: repoPath) {
            try LibGit2.getUncommittedFileContentChange(for: file, at: repoPath)
        }
    }

    /// 获取指定 commit 中某个文件的变更前后内容
    public func getCommitFileContentChange(path: String?, hash: String, file: String) async throws -> (before: String?, after: String?) {
        let repoPath = Self.resolvePath(path)
        return try await performOnGitQueue(repoPath: repoPath) {
            try LibGit2.getFileContentChange(atCommit: hash, file: file, at: repoPath)
        }
    }

    // MARK: - Is Git Repository

    public func isGitRepository(at path: String) -> Bool {
        gitQueue.sync {
            LibGit2.isGitRepository(at: path)
        }
    }

    // MARK: - Unpushed Commits

    /// 获取未推送到远程的 commit 哈希列表
    /// 使用 LibGit2Swift 原生实现，参考 GitOK 的 Project.getUnPushedCommits()
    public func getUnpushedCommitHashes(path: String?) -> [String] {
        let repoPath = Self.resolvePath(path)
        return gitQueue.sync {
            do {
                let unpushedCommits = try LibGit2.getUnPushedCommits(at: repoPath, verbose: false)
                return unpushedCommits.map { $0.hash }
            } catch {
                if Self.verbose {
                    GitPlugin.logger.error("\(Self.t)❌ 获取未推送 commit 失败: \(error.localizedDescription)")
                }
                return []
            }
        }
    }

    // MARK: - Git Commit

    public func commit(path: String?, message: String, files: [String], amend: Bool) async throws -> GitCommitResult {
        let repoPath = Self.resolvePath(path)

        // 将绝对路径转换为相对路径（相对于仓库根目录）
        // LibGit2 的 index 操作需要相对路径，绝对路径会导致 stage 静默失败
        let resolvedFiles: [String]
        if files.isEmpty {
            resolvedFiles = files
        } else {
            resolvedFiles = files.map { filePath -> String in
                let resolved = Self.resolvePath(filePath)
                // 如果路径以仓库根目录开头，转换为相对路径
                if resolved.hasPrefix(repoPath) {
                    let relative = String(resolved.dropFirst(repoPath.count))
                    // 移除开头的 /
                    return relative.hasPrefix("/") ? String(relative.dropFirst()) : relative
                }
                return filePath
            }
        }

        let commitHash: String = try await performOnGitQueue(repoPath: repoPath) {
            if amend {
                return try LibGit2.amendCommit(message: message, at: repoPath, verbose: Self.verbose)
            }
            // addAndCommit with empty files correctly stages ALL changes then commits.
            // Direct createCommit would only commit what's already staged, leaving working tree changes behind.
            return try LibGit2.addAndCommit(files: resolvedFiles, message: message, at: repoPath, verbose: Self.verbose)
        }

        // 获取提交详情
        let detail = try await getCommitDetail(path: path, hash: commitHash)
        return GitCommitResult(
            hash: commitHash,
            message: detail.message,
            author: detail.author,
            email: detail.email,
            date: detail.date,
            changedFiles: detail.changedFiles
        )
    }

    // MARK: - Path Validation

    /// 验证路径是否在允许的目录范围内
    ///
    /// - Parameters:
    ///   - path: 要验证的路径（可选，nil 表示当前工作目录）
    ///   - allowedDirectories: 允许的目录白名单
    /// - Returns: 验证通过的绝对路径
    /// - Throws: 如果路径不在允许范围内，抛出错误
    public static func validatePath(_ path: String?, allowedDirectories: [String]) throws -> String {
        let resolvedPath = Self.resolvePath(path)

        // 如果没有限制，直接返回
        guard !allowedDirectories.isEmpty else {
            return resolvedPath
        }

        // 检查路径是否在允许的目录范围内
        let isAllowed = allowedDirectories.contains { allowedDir in
            let resolvedAllowedDir = Self.resolvePath(allowedDir)
            return Self.path(resolvedPath, isInsideOrEqualTo: resolvedAllowedDir)
        }

        guard isAllowed else {
            throw GitServiceError.pathNotAllowed(
                path: resolvedPath,
                allowedDirectories: allowedDirectories
            )
        }

        return resolvedPath
    }

    // MARK: - Helper

    private static func resolvePath(_ path: String?) -> String {
        let rawPath = path ?? FileManager.default.currentDirectoryPath
        let expanded = (rawPath as NSString).expandingTildeInPath
        // 优先使用 realpath() 解析符号链接（在 macOS 上 /var -> /private/var）
        // URL.resolvingSymlinksInPath() 在某些沙箱环境下不可靠
        if let cStr = realpath(expanded, nil) {
            let resolved = String(cString: cStr)
            free(cStr)
            return resolved.hasSuffix("/") ? String(resolved.dropLast()) : resolved
        }
        // fallback：如果 realpath 失败（路径不存在等），使用 URL 解析
        let url = URL(fileURLWithPath: expanded)
        let resolved = url.resolvingSymlinksInPath().path
        return resolved.hasSuffix("/") ? String(resolved.dropLast()) : resolved
    }

    private static func path(_ path: String, isInsideOrEqualTo directory: String) -> Bool {
        if path == directory {
            return true
        }
        let directoryPrefix = directory == "/" ? "/" : directory + "/"
        return path.hasPrefix(directoryPrefix)
    }
}

// MARK: - Git Service Error

public enum GitServiceError: LocalizedError {
    case repositoryNotGit(path: String)
    case pathNotAllowed(path: String, allowedDirectories: [String])

    public var errorDescription: String? {
        switch self {
        case .repositoryNotGit(let path):
            return "Git 仓库不存在：`\(path)`。请确认路径是有效的 Git 仓库根目录。"
        case .pathNotAllowed(let path, let allowedDirectories):
            let formattedDirs = allowedDirectories.map { "`\($0)`" }.joined(separator: ", ")
            return "🚫 路径访问被拒绝：\(path)\n\n允许的目录：\(formattedDirs)\n\n此路径不在允许的访问范围内。请确保 Git 操作在允许的项目目录中执行。"
        }
    }
}

// MARK: - GitChangeType Helper

extension GitChangeType {
    public static func fromString(_ string: String) -> GitChangeType {
        switch string.uppercased() {
        case "M", "MODIFIED": return .modified
        case "A", "ADDED": return .added
        case "D", "DELETED": return .deleted
        case "R", "RENAMED": return .renamed
        case "?", "UNTRACKED": return .untracked
        case "C", "COPIED": return .renamed
        default: return .modified
        }
    }
}

// MARK: - Array Helper

extension Array {
    public func filtering(_ predicate: (Element) -> Bool) -> [Element] {
        filter(predicate)
    }
}

// MARK: - Git Commit Result

public struct GitCommitResult: Codable {
    public let hash: String
    public let message: String
    public let author: String
    public let email: String
    public let date: String
    public let changedFiles: [String]
}
