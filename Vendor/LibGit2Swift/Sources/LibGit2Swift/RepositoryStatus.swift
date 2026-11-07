import Clibgit2
import Foundation
import OSLog

/// 一条工作区状态记录。
///
/// `stagedStatus` 和 `worktreeStatus` 分别对应 Git porcelain 状态的 X/Y
/// 两列。路径始终优先使用工作区侧的新路径，因而重命名和复制可以直接交给
/// UI 或上层 provider 展示。
public struct GitRepositoryStatusEntry: Equatable, Sendable, Identifiable {
    public let path: String
    public let stagedStatus: Character
    public let worktreeStatus: Character

    public init(path: String, stagedStatus: Character, worktreeStatus: Character) {
        self.path = path
        self.stagedStatus = stagedStatus
        self.worktreeStatus = worktreeStatus
    }

    public var id: String { path }
    public var isUntracked: Bool { stagedStatus == "?" && worktreeStatus == "?" }
    public var isStaged: Bool { stagedStatus != " " && stagedStatus != "?" }
    public var isWorktreeModified: Bool { worktreeStatus != " " && worktreeStatus != "?" }
}

/// 工作区状态快照。
public struct GitRepositoryStatus: Equatable, Sendable {
    public let isClean: Bool
    public let changeCount: Int
    public let branch: String?

    public init(isClean: Bool, changeCount: Int, branch: String?) {
        self.isClean = isClean
        self.changeCount = changeCount
        self.branch = branch
    }
}

extension LibGit2 {
    /// 读取工作区中的文件级状态，不依赖系统 `git` 命令。
    public static func getStatusEntries(
        at path: String,
        cancellation: GitCancellationToken? = nil,
        detectRenames: Bool = true
    ) throws -> [GitRepositoryStatusEntry] {
        if let cancellation {
            return try LibGit2.serialized(at: path, cancellation: cancellation) {
                try getStatusEntriesUnlocked(
                    at: path,
                    cancellation: cancellation,
                    detectRenames: detectRenames
                )
            }
        }

        return try LibGit2.serialized(at: path) {
            try getStatusEntriesUnlocked(
                at: path,
                cancellation: nil,
                detectRenames: detectRenames
            )
        }
    }

    private static func getStatusEntriesUnlocked(
        at path: String,
        cancellation: GitCancellationToken?,
        detectRenames: Bool
    ) throws -> [GitRepositoryStatusEntry] {
        if let cancellation {
            let repo = try openRepositoryUnlocked(at: path)
            defer { git_repository_free(repo) }
            return try getCancellableStatusEntriesUnlocked(
                repo: repo,
                cancellation: cancellation,
                detectRenames: detectRenames
            )
        }

        let repo = try openRepositoryUnlocked(at: path)
        defer { git_repository_free(repo) }

        var options = git_status_options()
        guard git_status_init_options(&options, UInt32(GIT_STATUS_OPTIONS_VERSION)) == 0 else {
            throw LibGit2Error.cannotGetStatus
        }
        options.flags = GIT_STATUS_OPT_INCLUDE_UNTRACKED.rawValue
            | GIT_STATUS_OPT_RECURSE_UNTRACKED_DIRS.rawValue
        if detectRenames {
            options.flags |= GIT_STATUS_OPT_RENAMES_HEAD_TO_INDEX.rawValue
                | GIT_STATUS_OPT_RENAMES_INDEX_TO_WORKDIR.rawValue
        }

        var list: OpaquePointer?
        guard git_status_list_new(&list, repo, &options) == 0, let list else {
            throw LibGit2Error.cannotGetStatus
        }
        defer { git_status_list_free(list) }

        var entries: [GitRepositoryStatusEntry] = []
        let count = git_status_list_entrycount(list)
        entries.reserveCapacity(count)

        for index in 0..<count {
            guard let entry = git_status_byindex(list, index) else { continue }

            let rawStatus = entry.pointee.status.rawValue
            let staged = stagedStatus(from: rawStatus)
            let worktree = worktreeStatus(from: rawStatus)
            let delta = entry.pointee.index_to_workdir ?? entry.pointee.head_to_index
            let pathPointer = delta?.pointee.new_file.path ?? delta?.pointee.old_file.path
            guard let pathPointer else { continue }

            entries.append(
                GitRepositoryStatusEntry(
                    path: String(cString: pathPointer),
                    stagedStatus: staged,
                    worktreeStatus: worktree
                )
            )
        }

        return entries
    }

    /// 读取工作区摘要，不依赖系统 `git` 命令。
    public static func getRepositoryStatus(
        at path: String,
        cancellation: GitCancellationToken? = nil,
        detectRenames: Bool = true
    ) throws -> GitRepositoryStatus {
        let entries = try getStatusEntries(
            at: path,
            cancellation: cancellation,
            detectRenames: detectRenames
        )
        let branch: String?
        try checkCancellation(cancellation)
        if let current = try currentBranchName(at: path) {
            branch = current
        } else if try isHeadDetached(at: path) {
            branch = "HEAD"
        } else {
            branch = nil
        }
        try checkCancellation(cancellation)
        return GitRepositoryStatus(
            isClean: entries.isEmpty,
            changeCount: entries.count,
            branch: branch
        )
    }

    /// 丢弃当前工作区的全部非 ignored 改动。
    ///
    /// 先记录未跟踪路径，再用 libgit2 重置索引和工作区，最后删除这些路径。
    /// 这样不会把 `.gitignore` 中的构建产物误删，也不依赖 `git clean`。
    public static func discardAllChanges(at path: String, verbose: Bool = true) throws {
        try LibGit2.serialized(at: path) {
            let repo = try openRepositoryUnlocked(at: path)
            defer { git_repository_free(repo) }

            let entries = try getStatusEntriesUnlocked(repo: repo, cancellation: nil)
            let untrackedPaths = entries
                .filter { $0.stagedStatus == "A" || $0.isUntracked }
                .map(\.path)

            var headOID = git_oid()
            if git_reference_name_to_id(&headOID, repo, "HEAD") == 0 {
                guard let head = git_commitishLookup(repo: repo, oid: &headOID) else {
                    throw LibGit2Error.invalidReference
                }
                defer { git_commit_free(head) }

                let resetResult = git_reset(repo, head, GIT_RESET_MIXED, nil)
                guard resetResult == 0 else { throw LibGit2Error.invalidRepositoryState("Failed to reset the index.") }

                var checkoutOptions = git_checkout_options()
                guard git_checkout_init_options(&checkoutOptions, UInt32(GIT_CHECKOUT_OPTIONS_VERSION)) == 0 else {
                    throw LibGit2Error.checkoutFailed("HEAD")
                }
                checkoutOptions.checkout_strategy = GIT_CHECKOUT_FORCE.rawValue | GIT_CHECKOUT_RECREATE_MISSING.rawValue
                guard git_checkout_tree(repo, head, &checkoutOptions) == 0 else {
                    throw LibGit2Error.checkoutFailed("HEAD")
                }
            } else {
                var index: OpaquePointer?
                guard git_repository_index(&index, repo) == 0, let index else {
                    throw LibGit2Error.cannotGetIndex
                }
                defer { git_index_free(index) }
                git_index_clear(index)
                guard git_index_write(index) == 0 else { throw LibGit2Error.cannotGetIndex }
            }

            guard let workdirPointer = git_repository_workdir(repo) else { return }
            let workdir = URL(fileURLWithPath: String(cString: workdirPointer), isDirectory: true).standardizedFileURL
            for relativePath in untrackedPaths {
                let target = URL(fileURLWithPath: relativePath, relativeTo: workdir).standardizedFileURL
                guard target.path != workdir.path, target.path.hasPrefix(workdir.path + "/") else { continue }
                if FileManager.default.fileExists(atPath: target.path) {
                    try FileManager.default.removeItem(at: target)
                }
            }

            if verbose { os_log("LibGit2: discarded worktree changes") }
        }
    }

    private static func getStatusEntriesUnlocked(
        repo: OpaquePointer,
        cancellation: GitCancellationToken?
    ) throws -> [GitRepositoryStatusEntry] {
        var options = git_status_options()
        guard git_status_init_options(&options, UInt32(GIT_STATUS_OPTIONS_VERSION)) == 0 else {
            throw LibGit2Error.cannotGetStatus
        }
        options.flags = GIT_STATUS_OPT_INCLUDE_UNTRACKED.rawValue
            | GIT_STATUS_OPT_RECURSE_UNTRACKED_DIRS.rawValue
            | GIT_STATUS_OPT_RENAMES_HEAD_TO_INDEX.rawValue
            | GIT_STATUS_OPT_RENAMES_INDEX_TO_WORKDIR.rawValue

        var list: OpaquePointer?
        guard git_status_list_new(&list, repo, &options) == 0, let list else {
            throw LibGit2Error.cannotGetStatus
        }
        defer { git_status_list_free(list) }

        var entries: [GitRepositoryStatusEntry] = []
        for index in 0..<git_status_list_entrycount(list) {
            try checkCancellation(cancellation)
            guard let entry = git_status_byindex(list, index) else { continue }
            let rawStatus = entry.pointee.status.rawValue
            let delta = entry.pointee.index_to_workdir ?? entry.pointee.head_to_index
            guard let pathPointer = delta?.pointee.new_file.path ?? delta?.pointee.old_file.path else { continue }
            entries.append(
                GitRepositoryStatusEntry(
                    path: String(cString: pathPointer),
                    stagedStatus: stagedStatus(from: rawStatus),
                    worktreeStatus: worktreeStatus(from: rawStatus)
                )
            )
        }
        return entries
    }

    /// 用 diff 的 progress callback 构建可取消的状态快照。
    ///
    /// `git_status_foreach_ext` 只能在已经发现一个状态条目后回调；当 libgit2
    /// 正在递归枚举一个很大的未跟踪目录时，目录为空或尚未发现条目的阶段仍然
    /// 无法响应取消。`git_diff_*` 在每个文件比较前都会调用 progress callback，
    /// 因而可以在扫描过程中及时终止。
    private static func getCancellableStatusEntriesUnlocked(
        repo: OpaquePointer,
        cancellation: GitCancellationToken,
        detectRenames: Bool
    ) throws -> [GitRepositoryStatusEntry] {
        try checkCancellation(cancellation)

        var index: OpaquePointer?
        guard git_repository_index(&index, repo) == 0, let index else {
            throw LibGit2Error.cannotGetIndex
        }
        defer { git_index_free(index) }

        var headTree: OpaquePointer?
        var headCommit: OpaquePointer?
        defer {
            if let headTree { git_tree_free(headTree) }
            if let headCommit { git_commit_free(headCommit) }
        }

        var headOID = git_oid()
        if git_reference_name_to_id(&headOID, repo, "HEAD") == 0,
           git_commit_lookup(&headCommit, repo, &headOID) == 0,
           let headCommit {
            _ = git_commit_tree(&headTree, headCommit)
        }

        var stagedDiff: OpaquePointer?
        defer { if let stagedDiff { git_diff_free(stagedDiff) } }
        var stagedOptions = makeCancellableDiffOptions(cancellation: cancellation)
        let stagedResult = git_diff_tree_to_index(
            &stagedDiff,
            repo,
            headTree,
            index,
            &stagedOptions
        )
        try checkDiffResult(stagedResult, cancellation: cancellation)
        if detectRenames, let stagedDiff {
            try findSimilarChanges(in: stagedDiff, cancellation: cancellation)
        }

        var worktreeDiff: OpaquePointer?
        defer { if let worktreeDiff { git_diff_free(worktreeDiff) } }
        var worktreeOptions = makeCancellableDiffOptions(cancellation: cancellation)
        worktreeOptions.flags = GIT_DIFF_INCLUDE_UNTRACKED.rawValue
            | GIT_DIFF_RECURSE_UNTRACKED_DIRS.rawValue
        let worktreeResult = git_diff_index_to_workdir(
            &worktreeDiff,
            repo,
            index,
            &worktreeOptions
        )
        try checkDiffResult(worktreeResult, cancellation: cancellation)
        if detectRenames, let worktreeDiff {
            try findSimilarChanges(in: worktreeDiff, cancellation: cancellation)
        }

        var statuses: [String: (staged: Character, worktree: Character)] = [:]
        var order: [String] = []

        if let stagedDiff {
            try appendDiffStatuses(
                from: stagedDiff,
                staged: true,
                statuses: &statuses,
                order: &order,
                cancellation: cancellation
            )
        }
        if let worktreeDiff {
            try appendDiffStatuses(
                from: worktreeDiff,
                staged: false,
                statuses: &statuses,
                order: &order,
                cancellation: cancellation
            )
        }

        return order.compactMap { path in
            guard let status = statuses[path] else { return nil }
            return GitRepositoryStatusEntry(
                path: path,
                stagedStatus: status.staged,
                worktreeStatus: status.worktree
            )
        }
    }

    private static func makeCancellableDiffOptions(
        cancellation: GitCancellationToken
    ) -> git_diff_options {
        var options = git_diff_options()
        git_diff_init_options(&options, UInt32(GIT_DIFF_OPTIONS_VERSION))
        let payload = Unmanaged.passUnretained(cancellation).toOpaque()
        options.progress_cb = statusDiffProgressCallback
        options.payload = payload
        return options
    }

    private static func checkDiffResult(
        _ result: Int32,
        cancellation: GitCancellationToken
    ) throws {
        try checkCancellation(cancellation)
        guard result == 0 else { throw LibGit2Error.cannotGetStatus }
    }

    private static func findSimilarChanges(
        in diff: OpaquePointer,
        cancellation: GitCancellationToken
    ) throws {
        try checkCancellation(cancellation)
        var options = git_diff_find_options()
        guard git_diff_find_options_init(&options, UInt32(GIT_DIFF_FIND_OPTIONS_VERSION)) == 0 else {
            throw LibGit2Error.cannotGetStatus
        }
        options.flags = GIT_DIFF_FIND_RENAMES.rawValue
        let result = git_diff_find_similar(diff, &options)
        try checkDiffResult(result, cancellation: cancellation)
    }

    private static func appendDiffStatuses(
        from diff: OpaquePointer,
        staged: Bool,
        statuses: inout [String: (staged: Character, worktree: Character)],
        order: inout [String],
        cancellation: GitCancellationToken
    ) throws {
        let count = git_diff_num_deltas(diff)
        for index in 0..<count {
            try checkCancellation(cancellation)
            guard let delta = git_diff_get_delta(diff, index) else { continue }
            guard let path = statusPath(for: delta.pointee) else { continue }

            if statuses[path] == nil {
                statuses[path] = (" ", " ")
                order.append(path)
            }

            if staged {
                var status = statuses[path] ?? (" ", " ")
                status.staged = stagedStatus(from: delta.pointee.status)
                statuses[path] = status
            } else {
                var status = statuses[path] ?? (" ", " ")
                if delta.pointee.status == GIT_DELTA_UNTRACKED, status.staged == " " {
                    status.staged = "?"
                }
                status.worktree = worktreeStatus(
                    from: delta.pointee.status,
                    stagedStatus: status.staged
                )
                statuses[path] = status
            }
        }
    }

    private static func statusPath(for delta: git_diff_delta) -> String? {
        switch delta.status {
        case GIT_DELTA_DELETED:
            guard let path = delta.old_file.path else { return nil }
            return String(cString: path)
        default:
            guard let path = delta.new_file.path ?? delta.old_file.path else { return nil }
            return String(cString: path)
        }
    }

    private static func stagedStatus(from delta: git_delta_t) -> Character {
        switch delta {
        case GIT_DELTA_CONFLICTED:
            return "U"
        case GIT_DELTA_ADDED, GIT_DELTA_UNTRACKED:
            return "A"
        case GIT_DELTA_MODIFIED:
            return "M"
        case GIT_DELTA_DELETED:
            return "D"
        case GIT_DELTA_RENAMED, GIT_DELTA_COPIED:
            return "R"
        case GIT_DELTA_TYPECHANGE:
            return "T"
        default:
            return " "
        }
    }

    private static func worktreeStatus(
        from delta: git_delta_t,
        stagedStatus: Character
    ) -> Character {
        switch delta {
        case GIT_DELTA_CONFLICTED:
            return "U"
        case GIT_DELTA_UNTRACKED:
            return "?"
        case GIT_DELTA_ADDED:
            return stagedStatus == "A" ? "M" : "?"
        case GIT_DELTA_MODIFIED:
            return "M"
        case GIT_DELTA_DELETED:
            return "D"
        case GIT_DELTA_RENAMED, GIT_DELTA_COPIED:
            return "R"
        case GIT_DELTA_TYPECHANGE:
            return "T"
        default:
            return " "
        }
    }

    private static let statusDiffProgressCallback: @convention(c) (
        OpaquePointer?,
        UnsafePointer<CChar>?,
        UnsafePointer<CChar>?,
        UnsafeMutableRawPointer?
    ) -> Int32 = { _, _, _, payload in
        guard let payload else { return 0 }
        let cancellation = Unmanaged<GitCancellationToken>
            .fromOpaque(payload)
            .takeUnretainedValue()
        return cancellation.isCancelled ? GIT_EUSER.rawValue : 0
    }

    private static func git_commitishLookup(repo: OpaquePointer, oid: UnsafeMutablePointer<git_oid>) -> OpaquePointer? {
        var commit: OpaquePointer?
        guard git_commit_lookup(&commit, repo, oid) == 0 else { return nil }
        return commit
    }

    private static func stagedStatus(from rawStatus: UInt32) -> Character {
        if rawStatus & GIT_STATUS_CONFLICTED.rawValue != 0 { return "U" }
        if rawStatus & GIT_STATUS_INDEX_NEW.rawValue != 0 { return "A" }
        if rawStatus & GIT_STATUS_INDEX_MODIFIED.rawValue != 0 { return "M" }
        if rawStatus & GIT_STATUS_INDEX_DELETED.rawValue != 0 { return "D" }
        if rawStatus & GIT_STATUS_INDEX_RENAMED.rawValue != 0 { return "R" }
        if rawStatus & GIT_STATUS_INDEX_TYPECHANGE.rawValue != 0 { return "T" }
        if rawStatus & GIT_STATUS_WT_NEW.rawValue != 0 { return "?" }
        return " "
    }

    private static func worktreeStatus(from rawStatus: UInt32) -> Character {
        if rawStatus & GIT_STATUS_CONFLICTED.rawValue != 0 { return "U" }
        if rawStatus & GIT_STATUS_WT_NEW.rawValue != 0 { return "?" }
        if rawStatus & GIT_STATUS_WT_MODIFIED.rawValue != 0 { return "M" }
        if rawStatus & GIT_STATUS_WT_DELETED.rawValue != 0 { return "D" }
        if rawStatus & GIT_STATUS_WT_RENAMED.rawValue != 0 { return "R" }
        if rawStatus & GIT_STATUS_WT_TYPECHANGE.rawValue != 0 { return "T" }
        return " "
    }

}
