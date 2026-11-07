import Foundation
import Clibgit2
import OSLog

private final class StashListPayload {
    var stashes: [GitStashEntry] = []
}

/// 增强的 stash 条目模型
public struct GitStashEntry: Identifiable, Equatable, Hashable, Sendable {
    public let index: Int
    public let message: String
    public let commitHash: String
    /// stash 创建时间
    public let date: Date
    /// 变更文件数量
    public let changedFileCount: Int
    /// diff 预览（第一个文件的 diff 头部，截断到 200 字符）
    public let diffPreview: String

    public init(
        index: Int,
        message: String,
        commitHash: String,
        date: Date = Date(),
        changedFileCount: Int = 0,
        diffPreview: String = ""
    ) {
        self.index = index
        self.message = message
        self.commitHash = commitHash
        self.date = date
        self.changedFileCount = changedFileCount
        self.diffPreview = diffPreview
    }

    public var id: String { commitHash }
}

extension LibGit2 {
    /// 获取增强的暂存列表（包含日期、文件数、diff 预览）。
    public static func getStashListEnhanced(at path: String) throws -> [GitStashEntry] {
        return try LibGit2.serialized(at: path) {
            let repo = try openRepository(at: path)
            defer { git_repository_free(repo) }

            let payload = StashListPayload()
            let payloadPointer = Unmanaged.passUnretained(payload).toOpaque()

            let result = git_stash_foreach(repo, stashForeachCallback, payloadPointer)

            if result != 0 {
                throw LibGit2Error.commitFailed
            }

            return payload.stashes
        }
    }

    private static let stashForeachCallback: git_stash_cb = { index, message, stashID, payload in
        guard let payload, let stashID else { return -1 }

        let box = Unmanaged<StashListPayload>.fromOpaque(payload).takeUnretainedValue()
        let stashMessage = message.map { String(cString: $0) } ?? ""
        let shortMessage = stashMessage.components(separatedBy: "\n").first ?? stashMessage
        let commitHash = LibGit2.oidToString(stashID.pointee)

        box.stashes.append(GitStashEntry(
            index: Int(index),
            message: shortMessage,
            commitHash: commitHash
        ))

        return 0
    }
}

// MARK: - Stash Operations

/// LibGit2 暂存操作扩展
extension LibGit2 {
    /// 暂存当前变更
    /// - Parameters:
    ///   - message: 暂存信息（可选）
    ///   - path: 仓库路径
    ///   - verbose: 是否输出详细日志，默认为true
    /// - Returns: 暂存索引
    public static func stash(message: String? = nil, at path: String, verbose: Bool = true) throws -> Int {
        return try LibGit2.serialized(at: path) {
            if verbose { os_log("🐚 LibGit2: Stashing changes") }

            let repo = try openRepository(at: path)
            defer { git_repository_free(repo) }

            // 创建签名
            let signature = try createSignature(at: path, verbose: verbose)
            defer { git_signature_free(signature) }

            var commitOID = git_oid()

            let result = git_stash_save(
                &commitOID,
                repo,
                signature,
                message ?? "WIP",
                UInt32(GIT_STASH_INCLUDE_UNTRACKED.rawValue)
            )

            if result == GIT_ENOTFOUND.rawValue {
                if verbose { os_log("🐚 LibGit2: No changes to stash") }
                return -1
            }

            if result != 0 {
                throw LibGit2Error.commitFailed
            }

            if verbose { os_log("🐚 LibGit2: Changes stashed at index: 0") }

            return 0
        }
    }

    /// 恢复暂存的变更
    /// - Parameters:
    ///   - index: 暂存索引（默认 0，即最近的 stash）
    ///   - path: 仓库路径
    ///   - verbose: 是否输出详细日志，默认为true
    public static func stashPop(index: Int = 0, at path: String, verbose: Bool = true) throws {
        try LibGit2.serialized(at: path) {
            if verbose { os_log("🐚 LibGit2: Popping stash at index: %d", index) }

            let repo = try openRepository(at: path)
            defer { git_repository_free(repo) }

            var stashOpts = git_stash_apply_options()
            git_stash_apply_init_options(&stashOpts, UInt32(GIT_STASH_APPLY_OPTIONS_VERSION))

            let result = git_stash_pop(repo, index, &stashOpts)

            if result != 0 {
                throw LibGit2Error.commitFailed
            }

            if verbose { os_log("🐚 LibGit2: Stash popped successfully") }
        }
    }

    /// 应用暂存的变更（不从 stash 列表中删除）
    /// - Parameters:
    ///   - index: 暂存索引（默认 0，即最近的 stash）
    ///   - path: 仓库路径
    ///   - verbose: 是否输出详细日志，默认为true
    public static func stashApply(index: Int = 0, at path: String, verbose: Bool = true) throws {
        try LibGit2.serialized(at: path) {
            if verbose { os_log("🐚 LibGit2: Applying stash at index: %d", index) }

            let repo = try openRepository(at: path)
            defer { git_repository_free(repo) }

            var stashOpts = git_stash_apply_options()
            git_stash_apply_init_options(&stashOpts, UInt32(GIT_STASH_APPLY_OPTIONS_VERSION))

            stashOpts.checkout_options.checkout_strategy = GIT_CHECKOUT_SAFE.rawValue

            let result = git_stash_apply(repo, index, &stashOpts)

            if result != 0 {
                throw LibGit2Error.commitFailed
            }

            if verbose { os_log("🐚 LibGit2: Stash applied successfully") }
        }
    }

    /// 获取暂存列表
    /// - Parameter path: 仓库路径
    /// - Returns: 暂存信息列表
    public static func getStashList(at path: String) throws -> [(index: Int, message: String, commitHash: String)] {
        return try LibGit2.serialized(at: path) {
            let enhanced = try getStashListEnhanced(at: path)
            return enhanced.map { ($0.index, $0.message, $0.commitHash) }
        }
    }

    /// 删除暂存
    /// - Parameters:
    ///   - index: 暂存索引（默认 0，即最近的 stash）
    ///   - path: 仓库路径
    ///   - verbose: 是否输出详细日志，默认为true
    public static func stashDrop(index: Int = 0, at path: String, verbose: Bool = true) throws {
        try LibGit2.serialized(at: path) {
            if verbose { os_log("🐚 LibGit2: Dropping stash at index: %d", index) }

            let repo = try openRepository(at: path)
            defer { git_repository_free(repo) }

            let result = git_stash_drop(repo, index)

            if result != 0 {
                throw LibGit2Error.commitFailed
            }

            if verbose { os_log("🐚 LibGit2: Stash dropped successfully") }
        }
    }

    /// Create a branch at the stash base commit, check it out, apply the stash, then drop it.
    public static func stashBranch(name branchName: String, index: Int, at path: String, verbose: Bool = true) throws {
        try LibGit2.serialized(at: path) {
            let trimmedName = branchName.trimmingCharacters(in: .whitespacesAndNewlines)
            guard trimmedName.isEmpty == false else {
                throw LibGit2Error.invalidReference
            }

            let stashes = try getStashList(at: path)
            guard let stash = stashes.first(where: { $0.index == index }) else {
                throw LibGit2Error.invalidReference
            }

            let repo = try openRepository(at: path)
            defer { git_repository_free(repo) }

            var stashOID = git_oid()
            guard git_oid_fromstr(&stashOID, stash.commitHash) == 0 else {
                throw LibGit2Error.invalidReference
            }

            var stashCommit: OpaquePointer?
            defer { if stashCommit != nil { git_commit_free(stashCommit) } }
            guard git_commit_lookup(&stashCommit, repo, &stashOID) == 0, let stashCommit else {
                throw LibGit2Error.invalidReference
            }

            var baseCommit: OpaquePointer?
            defer { if baseCommit != nil { git_commit_free(baseCommit) } }
            guard git_commit_parent(&baseCommit, stashCommit, 0) == 0, let baseCommit else {
                throw LibGit2Error.invalidReference
            }

            var branchRef: OpaquePointer?
            defer { if branchRef != nil { git_reference_free(branchRef) } }
            guard git_branch_create(&branchRef, repo, trimmedName, baseCommit, 0) == 0 else {
                throw LibGit2Error.invalidReference
            }

            try checkout(branch: trimmedName, at: path, verbose: verbose)
            try stashApply(index: index, at: path, verbose: verbose)
            try stashDrop(index: index, at: path, verbose: verbose)
        }
    }

    /// 清空所有暂存
    /// - Parameters:
    ///   - path: 仓库路径
    ///   - verbose: 是否输出详细日志，默认为true
    public static func stashClear(at path: String, verbose: Bool = true) throws {
        try LibGit2.serialized(at: path) {
            if verbose { os_log("🐚 LibGit2: Clearing all stashes") }

            let repo = try openRepository(at: path)
            defer { git_repository_free(repo) }

            let count = try getStashCount(at: path)

            // 从后往前删除，避免索引问题
            for i in stride(from: count - 1, through: 0, by: -1) {
                git_stash_drop(repo, i)
            }

            if verbose { os_log("🐚 LibGit2: All stashes cleared") }
        }
    }

    /// 获取暂存数量
    /// - Parameter path: 仓库路径
    /// - Returns: 暂存数量
    public static func getStashCount(at path: String) throws -> Int {
        return try LibGit2.serialized(at: path) {
            let stashes = try getStashList(at: path)
            return stashes.count
        }
    }

    /// 检查是否有暂存
    /// - Parameter path: 仓库路径
    /// - Returns: 如果有暂存返回 true
    public static func hasStash(at path: String) throws -> Bool {
        return try LibGit2.serialized(at: path) {
            return try getStashCount(at: path) > 0
        }
    }
}
