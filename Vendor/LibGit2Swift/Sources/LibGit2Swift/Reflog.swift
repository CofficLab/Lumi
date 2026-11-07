import Clibgit2
import Foundation

/// 单条 reflog 记录，等价于 `git reflog` 输出中的一行。
public struct GitReflogEntry: Identifiable, Codable, Hashable, Sendable {
    /// 操作前的 commit hash
    public let oldCommitHash: String
    /// 操作后的 commit hash
    public let newCommitHash: String
    /// 操作者签名
    public let author: String
    /// 操作者邮箱
    public let authorEmail: String
    /// 操作时间
    public let date: Date
    /// 操作描述（如 "commit: Fix bug"）
    public let message: String

    public init(
        oldCommitHash: String,
        newCommitHash: String,
        author: String,
        authorEmail: String,
        date: Date,
        message: String
    ) {
        self.oldCommitHash = oldCommitHash
        self.newCommitHash = newCommitHash
        self.author = author
        self.authorEmail = authorEmail
        self.date = date
        self.message = message
    }

    public var id: String { "\(newCommitHash)-\(date.timeIntervalSince1970)" }
}

extension LibGit2 {
    /// 获取 HEAD 的 reflog 记录，等价于 `git reflog`。
    ///
    /// 返回按时间倒序排列的操作历史（最新在前）。
    ///
    /// - Parameter path: 仓库路径
    /// - Returns: reflog 条目列表
    public static func getReflog(at path: String) throws -> [GitReflogEntry] {
        return try LibGit2.serialized(at: path) {
            let repo = try openRepository(at: path)
            defer { git_repository_free(repo) }

            var reflog: OpaquePointer?
            defer { if reflog != nil { git_reflog_free(reflog) } }

            guard git_reflog_read(&reflog, repo, "HEAD") == 0, let reflogPtr = reflog else {
                return []
            }

            let count = git_reflog_entrycount(reflogPtr)
            var entries: [GitReflogEntry] = []

            for i in 0..<count {
                guard let entry = git_reflog_entry_byindex(reflogPtr, i) else { continue }

                let oldHash: String
                if let oldOID = git_reflog_entry_id_old(entry) {
                    oldHash = oidToString(oldOID.pointee)
                } else {
                    oldHash = ""
                }

                let newHash: String
                if let newOID = git_reflog_entry_id_new(entry) {
                    newHash = oidToString(newOID.pointee)
                } else {
                    newHash = ""
                }

                let author: String
                let authorEmail: String
                let date: Date

                if let sig = git_reflog_entry_committer(entry) {
                    author = sig.pointee.name.map { String(cString: $0) } ?? ""
                    authorEmail = sig.pointee.email.map { String(cString: $0) } ?? ""
                    date = Date(timeIntervalSince1970: TimeInterval(sig.pointee.when.time))
                } else {
                    author = ""
                    authorEmail = ""
                    date = Date(timeIntervalSince1970: 0)
                }

                let message: String
                if let msgPtr = git_reflog_entry_message(entry) {
                    message = String(cString: msgPtr)
                } else {
                    message = ""
                }

                entries.append(GitReflogEntry(
                    oldCommitHash: oldHash,
                    newCommitHash: newHash,
                    author: author,
                    authorEmail: authorEmail,
                    date: date,
                    message: message
                ))
            }

            return entries
        }
    }

    /// 删除指定 reflog 条目，等价于 `git reflog delete HEAD@{index}`。
    public static func deleteReflogEntry(at index: Int, path: String) throws {
        try LibGit2.serialized(at: path) {
            let repo = try openRepository(at: path)
            defer { git_repository_free(repo) }

            var reflog: OpaquePointer?
            defer { if reflog != nil { git_reflog_free(reflog) } }

            guard git_reflog_read(&reflog, repo, "HEAD") == 0, let reflogPtr = reflog else {
                throw LibGit2Error.invalidReference
            }

            let result = git_reflog_drop(reflogPtr, index, 0)
            if result != 0 {
                throw LibGit2Error.invalidReference
            }

            // 写回 reflog
            git_reflog_write(reflogPtr)
        }
    }

    /// 清空 reflog，等价于 `git reflog expire --expire=now --all`。
    public static func clearReflog(at path: String) throws {
        try LibGit2.serialized(at: path) {
            let repo = try openRepository(at: path)
            defer { git_repository_free(repo) }

            var reflog: OpaquePointer?
            defer { if reflog != nil { git_reflog_free(reflog) } }

            guard git_reflog_read(&reflog, repo, "HEAD") == 0, let reflogPtr = reflog else {
                return
            }

            let count = git_reflog_entrycount(reflogPtr)
            // 从后往前删除避免索引偏移
            for i in stride(from: size_t(count), through: 1, by: -1) {
                git_reflog_entrycount(reflogPtr) // ensure count is fresh
                if i > 0 {
                    git_reflog_drop(reflogPtr, i - 1, 0)
                }
            }

            git_reflog_write(reflogPtr)
        }
    }
}
