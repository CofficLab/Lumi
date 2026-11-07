import Foundation
import Clibgit2
import OSLog


/// LibGit2 分支操作扩展
extension LibGit2 {
    /// 获取分支列表
    /// - Parameters:
    ///   - path: 仓库路径
    ///   - includeRemote: 是否包含远程分支
    /// - Returns: 分支列表
    /// 获取分支列表
    /// - Parameters:
    ///   - path: 仓库路径
    ///   - includeRemote: 是否包含远程分支
    /// - Returns: 分支列表
    public static func getBranchList(at path: String, includeRemote: Bool = false) throws -> [GitBranch] {
        return try LibGit2.serialized(at: path) {
            let repo = try openRepository(at: path)
            defer { git_repository_free(repo) }

            var branches: [GitBranch] = []
            var branchIterator: OpaquePointer? = nil
            defer { git_branch_iterator_free(branchIterator) }

            let branchType = includeRemote ? GIT_BRANCH_ALL : GIT_BRANCH_LOCAL
            let result = git_branch_iterator_new(&branchIterator, repo, branchType)

            guard result == 0, let iterator = branchIterator else {
                return branches
            }

            var branchRef: OpaquePointer? = nil
            var branchTypeValue = git_branch_t.init(0)

            // 遍历所有分支
            while git_branch_next(&branchRef, &branchTypeValue, iterator) == 0 {
                guard let ref = branchRef else { continue }

                defer { git_reference_free(ref) }

                // 获取分支名
                var namePtr: UnsafePointer<Int8>? = nil
                if git_branch_name(&namePtr, ref) == 0, let name = namePtr {
                    _ = String(cString: name)

                    // 检查是否为当前分支
                    let isHead = git_branch_is_head(ref) == 1

                    // 获取分支的最新提交
                    var latestCommitHash = ""
                    var latestCommitMessage = ""

                    if let target = git_reference_target(ref) {
                        var commit: OpaquePointer? = nil
                        defer { if commit != nil { git_commit_free(commit) } }

                        if git_commit_lookup(&commit, repo, target) == 0, let commitPtr = commit {
                            let messagePtr = git_commit_message(commitPtr)
                            if let msg = messagePtr {
                                latestCommitMessage = String(cString: msg).components(separatedBy: "\n").first ?? ""
                            }

                            // 获取提交hash
                            let oid = git_commit_id(commitPtr)
                            let hashPtr = git_oid_tostr_s(oid)
                            if let hash = hashPtr {
                                latestCommitHash = String(cString: hash)
                            }
                        }
                    }

                    // 获取上游分支
                    var upstream: String? = nil
                    var upstreamRef: OpaquePointer? = nil
                    defer { if upstreamRef != nil { git_reference_free(upstreamRef) } }

                    if git_branch_upstream(&upstreamRef, ref) == 0, let us = upstreamRef {
                        var upstreamNamePtr: UnsafePointer<Int8>? = nil
                        if git_branch_name(&upstreamNamePtr, us) == 0, let usName = upstreamNamePtr {
                            // 添加远程前缀（如果需要）
                            if branchTypeValue == GIT_BRANCH_LOCAL {
                                upstream = String(cString: usName)
                            } else {
                                upstream = String(cString: usName)
                            }
                        }
                    }

                    // 添加分支类型前缀（远程分支）
                    let displayName = branchTypeValue == GIT_BRANCH_REMOTE ? String(cString: name) : String(cString: name)

                    branches.append(GitBranch(
                        id: displayName,
                        name: displayName,
                        isCurrent: isHead,
                        upstream: upstream,
                        latestCommitHash: latestCommitHash,
                        latestCommitMessage: latestCommitMessage
                    ))
                }
            }

            return branches
        }
    }

    /// 获取本地分支列表
    public static func getLocalBranches(at path: String) throws -> [GitBranch] {
        return try LibGit2.serialized(at: path) {
            return try getBranchList(at: path, includeRemote: false)
        }
    }

    /// 获取远程分支列表
    public static func getRemoteBranches(at path: String) throws -> [GitBranch] {
        return try LibGit2.serialized(at: path) {
            let repo = try openRepository(at: path)
            defer { git_repository_free(repo) }

            var branches: [GitBranch] = []
            var branchIterator: OpaquePointer? = nil
            defer { git_branch_iterator_free(branchIterator) }

            let result = git_branch_iterator_new(&branchIterator, repo, GIT_BRANCH_REMOTE)

            guard result == 0, let iterator = branchIterator else {
                return branches
            }

            var branchRef: OpaquePointer? = nil
            var branchTypeValue = git_branch_t.init(0)

            while git_branch_next(&branchRef, &branchTypeValue, iterator) == 0 {
                guard let ref = branchRef else { continue }

                defer { git_reference_free(ref) }

                var namePtr: UnsafePointer<Int8>? = nil
                if git_branch_name(&namePtr, ref) == 0, let name = namePtr {
                    let branchName = String(cString: name)

                    // 移除 "origin/" 前缀
                    let shortName = branchName.replacingOccurrences(of: "^[^/]+/", with: "", options: .regularExpression)

                    var commitOid = git_oid()
                    var latestCommitHash = ""
                    var latestCommitMessage = ""

                    if let target = git_reference_target(ref) {
                        commitOid = target.pointee
                        latestCommitHash = oidToString(commitOid)

                        var commit: OpaquePointer? = nil
                        defer { if commit != nil { git_commit_free(commit) } }

                        if git_commit_lookup(&commit, repo, &commitOid) == 0, let commitPtr = commit {
                            let messagePtr = git_commit_message(commitPtr)
                            if let msg = messagePtr {
                                latestCommitMessage = String(cString: msg).components(separatedBy: "\n").first ?? ""
                            }
                        }
                    }

                    branches.append(GitBranch(
                        id: branchName,
                        name: shortName,
                        isCurrent: false,
                        upstream: nil,
                        latestCommitHash: latestCommitHash,
                        latestCommitMessage: latestCommitMessage
                    ))
                }
            }

            return branches
        }
    }

    /// 获取当前分支信息
    public static func getCurrentBranchInfo(at path: String) throws -> GitBranch? {
        return try LibGit2.serialized(at: path) {
            let branches = try getBranchList(at: path, includeRemote: false)
            return branches.first { $0.isCurrent }
        }
    }

    /// 创建新分支
    /// - Parameters:
    ///   - name: 分支名称
    ///   - path: 仓库路径
    ///   - checkout: 是否立即切换到新分支
    /// - Returns: 创建的分支名称
    public static func createBranch(named name: String, at path: String, checkout: Bool = false) throws -> String {
        return try LibGit2.serialized(at: path) {
            let repo = try openRepository(at: path)
            defer { git_repository_free(repo) }

            // 获取 HEAD commit
            var headCommit: OpaquePointer? = nil
            defer { if headCommit != nil { git_commit_free(headCommit) } }

            var headOid = git_oid()
            let result = git_reference_name_to_id(&headOid, repo, "HEAD")

            if result != 0 {
                throw LibGit2Error.cannotGetHEAD
            }

            git_commit_lookup(&headCommit, repo, &headOid)

            guard let commit = headCommit else {
                throw LibGit2Error.cannotGetHEAD
            }

            // 检查分支是否已存在
            var existingBranch: OpaquePointer? = nil
            let lookupResult = git_reference_lookup(&existingBranch, repo, "refs/heads/\(name)")
            if lookupResult == 0 {
                git_reference_free(existingBranch)
                throw LibGit2Error.checkoutFailed(name) // 分支已存在
            }

            // 创建分支
            var branch: OpaquePointer? = nil
            defer { if branch != nil { git_reference_free(branch) } }

            let createResult = git_branch_create(&branch, repo, name, commit, 0)

            if createResult != 0 {
                throw LibGit2Error.checkoutFailed(name)
            }

            // 如果需要，切换到新分支
            if checkout {
                try LibGit2.checkout(branch: name, at: path)
            }

            return name
        }
    }

    /// 删除分支
    /// - Parameters:
    ///   - name: 分支名称
    ///   - path: 仓库路径
    ///   - force: 是否强制删除
    public static func deleteBranch(named name: String, at path: String, force: Bool = false) throws {
        try LibGit2.serialized(at: path) {
            let repo = try openRepository(at: path)
            defer { git_repository_free(repo) }

            var branchRef: OpaquePointer? = nil
            defer { if branchRef != nil { git_reference_free(branchRef) } }

            let result = git_branch_lookup(&branchRef, repo, name, GIT_BRANCH_LOCAL)

            if result != 0 {
                throw LibGit2Error.invalidReference
            }

            guard let branchRef else { throw LibGit2Error.invalidReference }
            let deleteResult = git_branch_delete(branchRef)

            if deleteResult != 0 {
                throw LibGit2Error.checkoutFailed(name)
            }
        }
    }

    /// 重命名分支
    /// - Parameters:
    ///   - name: 原分支名称
    ///   - newName: 新分支名称
    ///   - path: 仓库路径
    ///   - force: 是否强制重命名
    public static func renameBranch(named name: String, to newName: String, at path: String, force: Bool = false) throws {
        try LibGit2.serialized(at: path) {
            let repo = try openRepository(at: path)
            defer { git_repository_free(repo) }

            var branchRef: OpaquePointer? = nil
            defer { if branchRef != nil { git_reference_free(branchRef) } }

            let result = git_branch_lookup(&branchRef, repo, name, GIT_BRANCH_LOCAL)

            if result != 0 {
                throw LibGit2Error.invalidReference
            }

            var newRef: OpaquePointer? = nil
            defer { if newRef != nil { git_reference_free(newRef) } }

            guard let branchRef else { throw LibGit2Error.invalidReference }
            let renameResult = git_branch_move(&newRef, branchRef, newName, force ? 1 : 0)

            if renameResult != 0 {
                throw LibGit2Error.checkoutFailed(newName)
            }
        }
    }

    /// 检查分支名是否符合 Git 的分支命名规则。
    public static func isValidBranchName(_ name: String) -> Bool {
        return LibGit2.serialized {
            let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
            guard trimmedName.isEmpty == false else { return false }

            var valid: Int32 = 0
            return git_branch_name_is_valid(&valid, trimmedName) == 0 && valid == 1
        }
    }

    /// 检查标签名是否符合 Git 单段引用命名规则。
    public static func isValidTagName(_ name: String) -> Bool {
        return LibGit2.serialized {
            let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
            guard trimmedName.isEmpty == false else { return false }

            var buffer = [CChar](repeating: 0, count: 1024)
            return git_reference_normalize_name(
                &buffer,
                buffer.count,
                "refs/tags/\(trimmedName)",
                GIT_REFERENCE_FORMAT_NORMAL.rawValue
            ) == 0
        }
    }

    /// 获取远程分支短名称，等价于 `git branch -r --format=%(refname:short)`。
    public static func getRemoteBranchNames(at path: String, remote: String? = nil) throws -> [String] {
        return try LibGit2.serialized(at: path) {
            let trimmedRemote = remote?.trimmingCharacters(in: .whitespacesAndNewlines)
            return try getRemoteBranches(at: path)
                .map(\.id)
                .filter { $0.isEmpty == false && $0.hasSuffix("/HEAD") == false }
                .filter { branch in
                    guard let trimmedRemote, trimmedRemote.isEmpty == false else { return true }
                    return branch.hasPrefix(trimmedRemote + "/")
                }
                .sorted()
        }
    }

    /// 设置本地分支 upstream，upstreamBranch 使用 `origin/main` 这种短名称。
    public static func setUpstream(localBranch: String, upstreamBranch: String, at path: String) throws {
        try LibGit2.serialized(at: path) {
            let trimmedLocalBranch = localBranch.trimmingCharacters(in: .whitespacesAndNewlines)
            let trimmedUpstreamBranch = upstreamBranch.trimmingCharacters(in: .whitespacesAndNewlines)

            guard trimmedLocalBranch.isEmpty == false, trimmedUpstreamBranch.isEmpty == false else {
                throw LibGit2Error.invalidReference
            }

            let repo = try openRepository(at: path)
            defer { git_repository_free(repo) }

            var branchRef: OpaquePointer?
            defer { if branchRef != nil { git_reference_free(branchRef) } }

            guard git_branch_lookup(&branchRef, repo, trimmedLocalBranch, GIT_BRANCH_LOCAL) == 0,
                  let branchRef else {
                throw LibGit2Error.invalidReference
            }

            let result = git_branch_set_upstream(branchRef, trimmedUpstreamBranch)
            if result != 0 {
                throw LibGit2Error.invalidReference
            }
        }
    }

    /// 清除本地分支 upstream。
    public static func unsetUpstream(localBranch: String, at path: String) throws {
        try LibGit2.serialized(at: path) {
            let trimmedLocalBranch = localBranch.trimmingCharacters(in: .whitespacesAndNewlines)
            guard trimmedLocalBranch.isEmpty == false else {
                throw LibGit2Error.invalidReference
            }

            let repo = try openRepository(at: path)
            defer { git_repository_free(repo) }

            var branchRef: OpaquePointer?
            defer { if branchRef != nil { git_reference_free(branchRef) } }

            guard git_branch_lookup(&branchRef, repo, trimmedLocalBranch, GIT_BRANCH_LOCAL) == 0,
                  let branchRef else {
                throw LibGit2Error.invalidReference
            }

            let result = git_branch_set_upstream(branchRef, nil)
            if result != 0 {
                throw LibGit2Error.invalidReference
            }
        }
    }

    /// 比较 HEAD 与 upstream 的 ahead/behind 状态。
    public static func aheadBehind(at path: String) throws -> GitAheadBehind {
        try aheadBehind(at: path, cancellation: nil)
    }

    /// 可取消地比较 HEAD 与 upstream 的 ahead/behind 状态。
    public static func aheadBehind(
        at path: String,
        cancellation: GitCancellationToken?
    ) throws -> GitAheadBehind {
        return try LibGit2.serialized(at: path) {
            try checkCancellation(cancellation)
            let repo = try openRepository(at: path)
            defer { git_repository_free(repo) }

            var headRef: OpaquePointer?
            defer { if headRef != nil { git_reference_free(headRef) } }

            guard git_repository_head(&headRef, repo) == 0, let headRef else {
                throw LibGit2Error.cannotGetHEAD
            }

            var upstreamRef: OpaquePointer?
            defer { if upstreamRef != nil { git_reference_free(upstreamRef) } }

            guard git_branch_upstream(&upstreamRef, headRef) == 0, let upstreamRef else {
                return .noUpstream
            }

            guard let headOIDPointer = git_reference_target(headRef),
                  let upstreamOIDPointer = git_reference_target(upstreamRef) else {
                throw LibGit2Error.invalidReference
            }

            var headOID = headOIDPointer.pointee
            var upstreamOID = upstreamOIDPointer.pointee
            var ahead = 0
            var behind = 0

            try checkCancellation(cancellation)
            guard git_graph_ahead_behind(&ahead, &behind, repo, &headOID, &upstreamOID) == 0 else {
                throw LibGit2Error.invalidReference
            }
            try checkCancellation(cancellation)

            return GitAheadBehind(ahead: ahead, behind: behind, hasUpstream: true)
        }
    }

    /// 比较两个引用，等价于 GitOK 当前使用的 `rev-list` / `log` / `diff --name-status` 组合。
    public static func compareBranches(base: String, head: String, at path: String) throws -> GitBranchCompare {
        return try LibGit2.serialized(at: path) {
            let trimmedBase = base.trimmingCharacters(in: .whitespacesAndNewlines)
            let trimmedHead = head.trimmingCharacters(in: .whitespacesAndNewlines)

            guard trimmedBase.isEmpty == false, trimmedHead.isEmpty == false else {
                throw LibGit2Error.invalidReference
            }

            let repo = try openRepository(at: path)
            defer { git_repository_free(repo) }

            var baseOID = try resolveCommitOID(trimmedBase, in: repo)
            var headOID = try resolveCommitOID(trimmedHead, in: repo)

            var ahead = 0
            var behind = 0
            guard git_graph_ahead_behind(&ahead, &behind, repo, &headOID, &baseOID) == 0 else {
                throw LibGit2Error.invalidReference
            }

            let commits = try branchCompareCommits(baseOID: &baseOID, headOID: &headOID, repo: repo)
            let files = try branchCompareFiles(baseOID: &baseOID, headOID: &headOID, repo: repo)

            return GitBranchCompare(
                base: trimmedBase,
                head: trimmedHead,
                ahead: ahead,
                behind: behind,
                commits: commits,
                files: files
            )
        }
    }

    private static func resolveCommitOID(_ revision: String, in repo: OpaquePointer) throws -> git_oid {
        var object: OpaquePointer?
        defer { if object != nil { git_object_free(object) } }

        guard git_revparse_single(&object, repo, revision) == 0,
              let object,
              let oidPointer = git_object_id(object) else {
            throw LibGit2Error.invalidReference
        }

        return oidPointer.pointee
    }

    private static func branchCompareCommits(
        baseOID: inout git_oid,
        headOID: inout git_oid,
        repo: OpaquePointer
    ) throws -> [GitBranchCompareCommit] {
        var walker: OpaquePointer?
        defer { if walker != nil { git_revwalk_free(walker) } }

        guard git_revwalk_new(&walker, repo) == 0, let walker else {
            throw LibGit2Error.cannotCreateRevwalk
        }

        git_revwalk_sorting(walker, GIT_SORT_TIME.rawValue)
        git_revwalk_push(walker, &headOID)
        git_revwalk_hide(walker, &baseOID)

        var commits: [GitBranchCompareCommit] = []
        var oid = git_oid()
        while git_revwalk_next(&oid, walker) == 0 {
            var commit: OpaquePointer?
            defer { if commit != nil { git_commit_free(commit) } }

            guard git_commit_lookup(&commit, repo, &oid) == 0, let commit else {
                continue
            }

            let hash = oidToString(oid)
            let authorPointer = git_commit_author(commit)
            let author: String
            let date: Date
            if let authorPointer {
                let name = authorPointer.pointee.name.map { String(cString: $0) } ?? ""
                let email = authorPointer.pointee.email.map { String(cString: $0) } ?? ""
                author = email.isEmpty ? name : "\(name) <\(email)>"
                date = Date(timeIntervalSince1970: TimeInterval(authorPointer.pointee.when.time))
            } else {
                author = ""
                date = Date(timeIntervalSince1970: 0)
            }

            let message = git_commit_message(commit).map { String(cString: $0) } ?? ""
            let subject = message.components(separatedBy: "\n").first ?? message
            commits.append(GitBranchCompareCommit(hash: hash, author: author, date: date, subject: subject))
        }

        return commits
    }

    private static func branchCompareFiles(
        baseOID: inout git_oid,
        headOID: inout git_oid,
        repo: OpaquePointer
    ) throws -> [GitBranchCompareFile] {
        var mergeBaseOID = git_oid()
        let baseForDiff: git_oid
        if git_merge_base(&mergeBaseOID, repo, &baseOID, &headOID) == 0 {
            baseForDiff = mergeBaseOID
        } else {
            baseForDiff = baseOID
        }

        var mutableBaseForDiff = baseForDiff
        var baseCommit: OpaquePointer?
        var headCommit: OpaquePointer?
        var baseTree: OpaquePointer?
        var headTree: OpaquePointer?
        var diff: OpaquePointer?

        defer {
            if diff != nil { git_diff_free(diff) }
            if baseTree != nil { git_tree_free(baseTree) }
            if headTree != nil { git_tree_free(headTree) }
            if baseCommit != nil { git_commit_free(baseCommit) }
            if headCommit != nil { git_commit_free(headCommit) }
        }

        guard git_commit_lookup(&baseCommit, repo, &mutableBaseForDiff) == 0,
              git_commit_lookup(&headCommit, repo, &headOID) == 0,
              let baseCommit,
              let headCommit,
              git_commit_tree(&baseTree, baseCommit) == 0,
              git_commit_tree(&headTree, headCommit) == 0 else {
            throw LibGit2Error.invalidReference
        }

        var diffOptions = git_diff_options()
        git_diff_init_options(&diffOptions, UInt32(GIT_DIFF_OPTIONS_VERSION))
        guard git_diff_tree_to_tree(&diff, repo, baseTree, headTree, &diffOptions) == 0,
              let diff else {
            throw LibGit2Error.invalidReference
        }

        var findOptions = git_diff_find_options()
        git_diff_find_options_init(&findOptions, UInt32(GIT_DIFF_FIND_OPTIONS_VERSION))
        findOptions.flags = GIT_DIFF_FIND_RENAMES.rawValue | GIT_DIFF_FIND_COPIES.rawValue
        _ = git_diff_find_similar(diff, &findOptions)

        var files: [GitBranchCompareFile] = []
        for index in 0..<git_diff_num_deltas(diff) {
            guard let delta = git_diff_get_delta(diff, index) else { continue }

            let status = branchCompareStatus(delta.pointee)
            let path = String(cString: delta.pointee.new_file.path)
            let oldPath = String(cString: delta.pointee.old_file.path)

            if delta.pointee.status == GIT_DELTA_RENAMED || delta.pointee.status == GIT_DELTA_COPIED {
                files.append(GitBranchCompareFile(status: status, path: path, oldPath: oldPath))
            } else {
                files.append(GitBranchCompareFile(status: status, path: path))
            }
        }

        return files.sorted { lhs, rhs in
            if lhs.path == rhs.path {
                return lhs.status < rhs.status
            }
            return lhs.path < rhs.path
        }
    }

    private static func branchCompareStatus(_ delta: git_diff_delta) -> String {
        switch delta.status {
        case GIT_DELTA_ADDED:
            return "A"
        case GIT_DELTA_DELETED:
            return "D"
        case GIT_DELTA_RENAMED:
            return "R\(delta.similarity)"
        case GIT_DELTA_COPIED:
            return "C\(delta.similarity)"
        case GIT_DELTA_TYPECHANGE:
            return "T"
        case GIT_DELTA_CONFLICTED:
            return "U"
        default:
            return "M"
        }
    }
}
