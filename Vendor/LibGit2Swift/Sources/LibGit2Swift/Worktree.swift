import Clibgit2
import Foundation

/// Worktree 条目
public struct GitWorktree: Identifiable, Equatable, Hashable, Sendable {
    public let name: String
    public let path: String
    public let branch: String?
    public let headCommitHash: String
    public let isDetached: Bool

    public init(name: String, path: String, branch: String?, headCommitHash: String, isDetached: Bool) {
        self.name = name
        self.path = path
        self.branch = branch
        self.headCommitHash = headCommitHash
        self.isDetached = isDetached
    }

    public var id: String { path }
}

extension LibGit2 {
    /// 获取所有 worktree 列表，等价于 `git worktree list`。
    public static func listWorktrees(at path: String) throws -> [GitWorktree] {
        return try LibGit2.serialized(at: path) {
            let repo = try openRepository(at: path)
            defer { git_repository_free(repo) }

            var wtList = git_strarray()
            defer { git_strarray_free(&wtList) }

            guard git_worktree_list(&wtList, repo) == 0 else {
                return []
            }

            var worktrees: [GitWorktree] = []

            for i in 0..<wtList.count {
                guard let namePtr = wtList.strings[Int(i)] else { continue }
                let name = String(cString: namePtr)

                var wt: OpaquePointer?
                defer { if wt != nil { git_worktree_free(wt) } }

                guard git_worktree_lookup(&wt, repo, namePtr) == 0, let wtPtr = wt else {
                    continue
                }

                let wtPath = git_worktree_path(wtPtr).map { String(cString: $0) } ?? ""

                var wtRepo: OpaquePointer?
                var headHash = ""
                var branchName: String?
                var isDetached = false

                if git_worktree_open_from_repository(&wtRepo, wtPtr) == 0, let wtRepo {
                    defer { git_repository_free(wtRepo) }

                    isDetached = git_repository_head_detached(wtRepo) == 1

                    var headOID = git_oid()
                    if git_reference_name_to_id(&headOID, wtRepo, "HEAD") == 0 {
                        headHash = oidToString(headOID)
                    }

                    if isDetached == false {
                        var headRef: OpaquePointer?
                        defer { if headRef != nil { git_reference_free(headRef) } }
                        if git_repository_head(&headRef, wtRepo) == 0 {
                            let refName = git_reference_name(headRef).map { String(cString: $0) } ?? ""
                            if refName.hasPrefix("refs/heads/") {
                                branchName = String(refName.dropFirst(11))
                            }
                        }
                    }
                }

                worktrees.append(GitWorktree(
                    name: name,
                    path: wtPath,
                    branch: branchName,
                    headCommitHash: headHash,
                    isDetached: isDetached
                ))
            }

            return worktrees
        }
    }

    /// 创建新的 worktree。
    /// 注意：此函数会调用系统 git CLI 创建 worktree，因为 libgit2 的 git_worktree_add
    /// 在 1.x 中参数签名不固定。
    public static func addWorktree(
        at worktreePath: String,
        branchName: String,
        createBranch: Bool = false,
        in mainRepoPath: String
    ) throws {
        try LibGit2.serialized(at: mainRepoPath) {
            var repo = try openRepository(at: mainRepoPath)
            defer { git_repository_free(repo) }

            // 如果需要创建分支
            if createBranch {
                var headOID = git_oid()
                guard git_reference_name_to_id(&headOID, repo, "HEAD") == 0 else {
                    throw LibGit2Error.cannotGetHEAD
                }

                var headCommit: OpaquePointer?
                defer { if headCommit != nil { git_commit_free(headCommit) } }
                guard git_commit_lookup(&headCommit, repo, &headOID) == 0, let headCommit else {
                    throw LibGit2Error.cannotGetHEAD
                }

                var newBranchRef: OpaquePointer?
                defer { if newBranchRef != nil { git_reference_free(newBranchRef) } }
                guard git_branch_create(&newBranchRef, repo, branchName, headCommit, 0) == 0 else {
                    throw LibGit2Error.checkoutFailed(branchName)
                }
            }

            var opts = git_worktree_add_options()
            git_worktree_add_options_init(&opts, UInt32(GIT_WORKTREE_ADD_OPTIONS_VERSION))

            var wt: OpaquePointer?
            let result = worktreePath.withCString { pathC in
                branchName.withCString { nameC in
                    var out: OpaquePointer?
                    let r = git_worktree_add(&out, repo, nameC, pathC, &opts)
                    wt = out
                    return r
                }
            }

            if result != 0 {
                throw LibGit2Error.checkoutFailed("worktree add \(worktreePath)")
            }

            if let wtPtr = wt {
                git_worktree_free(wtPtr)
            }

            // checkout 到指定分支
            try checkout(branch: branchName, at: worktreePath)
        }
    }

    /// 删除 worktree。
    public static func removeWorktree(named name: String, at path: String, force: Bool = false) throws {
        try LibGit2.serialized(at: path) {
            let repo = try openRepository(at: path)
            defer { git_repository_free(repo) }

            var wt: OpaquePointer?
            defer { if wt != nil { git_worktree_free(wt) } }

            guard git_worktree_lookup(&wt, repo, name) == 0, let wtPtr = wt else {
                throw LibGit2Error.invalidReference
            }

            var opts = git_worktree_prune_options()
            git_worktree_prune_options_init(&opts, UInt32(GIT_WORKTREE_PRUNE_OPTIONS_VERSION))
            if force {
                opts.flags = UInt32(GIT_WORKTREE_PRUNE_LOCKED.rawValue) | UInt32(GIT_WORKTREE_PRUNE_VALID.rawValue)
            }

            let result = git_worktree_prune(wtPtr, &opts)
            if result != 0 {
                throw LibGit2Error.checkoutFailed("worktree remove \(name)")
            }
        }
    }

    /// 锁定 worktree。
    public static func lockWorktree(named name: String, at path: String) throws {
        try LibGit2.serialized(at: path) {
            let repo = try openRepository(at: path)
            defer { git_repository_free(repo) }

            var wt: OpaquePointer?
            defer { if wt != nil { git_worktree_free(wt) } }

            guard git_worktree_lookup(&wt, repo, name) == 0, let wtPtr = wt else {
                throw LibGit2Error.invalidReference
            }

            let result = git_worktree_lock(wtPtr, "Locked by GitOK")
            if result != 0 {
                throw LibGit2Error.checkoutFailed("worktree lock \(name)")
            }
        }
    }

    /// 解锁 worktree。
    public static func unlockWorktree(named name: String, at path: String) throws {
        try LibGit2.serialized(at: path) {
            let repo = try openRepository(at: path)
            defer { git_repository_free(repo) }

            var wt: OpaquePointer?
            defer { if wt != nil { git_worktree_free(wt) } }

            guard git_worktree_lookup(&wt, repo, name) == 0, let wtPtr = wt else {
                throw LibGit2Error.invalidReference
            }

            let result = git_worktree_unlock(wtPtr)
            if result != 0 {
                throw LibGit2Error.checkoutFailed("worktree unlock \(name)")
            }
        }
    }
}
