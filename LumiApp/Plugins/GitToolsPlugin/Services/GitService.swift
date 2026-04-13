import Foundation
import LibGit2Swift
import MagicKit
import OSLog
import SwiftUI

/// Git 服务
///
/// 完全基于 LibGit2Swift 的原生 Git 操作，不使用任何命令行调用。
/// 参考 GitOK 的 Project+File 实现。
final class GitService: @unchecked Sendable, SuperLog {
    nonisolated static let verbose: Bool = false
    nonisolated static let emoji = "📦"
    static let shared = GitService()

    private init() {}

    // MARK: - Git Status

    func getStatus(path: String?) async throws -> GitStatus {
        let repoPath = resolvePath(path)

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

    // MARK: - Git Diff

    func getDiff(path: String?, staged: Bool, file: String?) async throws -> GitDiff {
        let repoPath = resolvePath(path)

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
        var insertions = 0, deletions = 0
        for line in content.components(separatedBy: "\n") {
            if line.hasPrefix("+") && !line.hasPrefix("++") { insertions += 1 }
            else if line.hasPrefix("-") && !line.hasPrefix("--") { deletions += 1 }
        }

        let stats = !files.isEmpty ? GitDiffStats(filesChanged: files.count, insertions: insertions, deletions: deletions) : nil
        return GitDiff(content: content, stats: stats)
    }

    // MARK: - Git Log

    func getLog(path: String?, count: Int, branch: String?, file: String?) async throws -> [GitCommitLog] {
        let repoPath = resolvePath(path)

        let gitCommits = try LibGit2.getCommitList(at: repoPath, limit: count)

        // LibGit2Swift 的 GitCommit 已经有完整信息，直接映射
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

    // MARK: - Commit Detail

    /// 获取指定 commit 的详细信息
    func getCommitDetail(path: String?, hash: String) async throws -> GitCommitDetail {
        let repoPath = resolvePath(path)

        // 使用 getCommitList 找到目标 commit（从列表中查找）
        // 先尝试获取最近的 commit 列表
        let allCommits = try LibGit2.getCommitList(at: repoPath, limit: 500, skip: 0)
        guard let commit = allCommits.first(where: { $0.hash == hash }) else {
            throw NSError(domain: "GitService", code: -1, userInfo: [NSLocalizedDescriptionKey: "无法找到 commit \(hash.prefix(7))"])
        }

        // 使用 LibGit2Swift 获取变更文件列表（含精确变更类型和 diff）
        let diffFiles = try LibGit2.getCommitDiffFiles(atCommit: hash, at: repoPath)

        var insertions = 0, deletions = 0
        for file in diffFiles {
            for line in file.diff.components(separatedBy: "\n") {
                if line.hasPrefix("+") && !line.hasPrefix("++") { insertions += 1 }
                else if line.hasPrefix("-") && !line.hasPrefix("--") { deletions += 1 }
            }
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

    // MARK: - Commit Changed Files

    /// 获取 commit 的变更文件列表（含精确变更类型）
    func getCommitChangedFiles(path: String?, hash: String) throws -> [GitChangedFile] {
        let repoPath = resolvePath(path)
        let diffFiles = try LibGit2.getCommitDiffFiles(atCommit: hash, at: repoPath)
        return diffFiles.map { file in
            GitChangedFile(path: file.file, changeType: .fromString(file.changeType))
        }
    }

    // MARK: - Working State

    /// 获取未提交变更的文件列表
    func getUncommittedChanges(path: String?) async throws -> [GitChangedFile] {
        let repoPath = resolvePath(path)

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

    // MARK: - File Content Change

    /// 获取未提交文件的内容差异
    func getUncommittedFileContentChange(path: String?, file: String) async throws -> (before: String?, after: String?) {
        let repoPath = resolvePath(path)
        return try LibGit2.getUncommittedFileContentChange(for: file, at: repoPath)
    }

    /// 获取指定 commit 中某个文件的变更前后内容
    func getCommitFileContentChange(path: String?, hash: String, file: String) async throws -> (before: String?, after: String?) {
        let repoPath = resolvePath(path)
        return try LibGit2.getFileContentChange(atCommit: hash, file: file, at: repoPath)
    }

    // MARK: - Is Git Repository

    func isGitRepository(at path: String) -> Bool {
        LibGit2.isGitRepository(at: path)
    }

    // MARK: - Unpushed Commits

    /// 获取未推送到远程的 commit 哈希列表
    /// 使用 LibGit2Swift 原生实现，参考 GitOK 的 Project.getUnPushedCommits()
    func getUnpushedCommitHashes(path: String?) -> [String] {
        let repoPath = resolvePath(path)

        do {
            let unpushedCommits = try LibGit2.getUnPushedCommits(at: repoPath, verbose: false)
            return unpushedCommits.map { $0.hash }
        } catch {
            if Self.verbose {
                AppLogger.core.error("\(Self.t)❌ 获取未推送 commit 失败: \(error.localizedDescription)")
            }
            return []
        }
    }

    // MARK: - Helper

    private func resolvePath(_ path: String?) -> String {
        path ?? FileManager.default.currentDirectoryPath
    }
}

// MARK: - GitChangeType Helper

extension GitChangeType {
    static func fromString(_ string: String) -> GitChangeType {
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
    func filtering(_ predicate: (Element) -> Bool) -> [Element] {
        filter(predicate)
    }
}
