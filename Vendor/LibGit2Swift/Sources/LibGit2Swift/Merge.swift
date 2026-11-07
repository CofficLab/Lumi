import Foundation
import Clibgit2
import OSLog

/// LibGit2 合并操作扩展
extension LibGit2 {
    /// 合并分支
    /// - Parameters:
    ///   - branchName: 要合并的分支名称
    ///   - path: 仓库路径
    ///   - verbose: 是否输出详细日志，默认为true
    public static func merge(branchName: String, at path: String, verbose: Bool) throws {
        try LibGit2.serialized(at: path) {
            if verbose { os_log("\(self.t)Merging branch: \(branchName)") }

            let repo = try openRepository(at: path)
            defer { git_repository_free(repo) }

            // 查找要合并的分支
            let branchRef = "refs/heads/\(branchName)"
            var branchRefPtr: OpaquePointer? = nil
            defer { if branchRefPtr != nil { git_reference_free(branchRefPtr) } }

            let lookupResult = git_reference_lookup(&branchRefPtr, repo, branchRef)

            if lookupResult != 0 {
                throw LibGit2Error.checkoutFailed(branchName)
            }

            guard branchRefPtr != nil else {
                throw LibGit2Error.invalidReference
            }

            // 获取分支的 annotated commit
            var branchOID = git_oid()
            git_reference_name_to_id(&branchOID, repo, branchRef)

            var annotatedCommit: OpaquePointer? = nil
            defer { if annotatedCommit != nil { git_annotated_commit_free(annotatedCommit) } }

            if git_annotated_commit_lookup(&annotatedCommit, repo, &branchOID) != 0 {
                throw LibGit2Error.mergeConflict
            }

            // 分析合并
            var analysis = git_merge_analysis_t.init(0)
            var preference = git_merge_preference_t.init(0)

            var headOID = git_oid()
            git_reference_name_to_id(&headOID, repo, "HEAD")

            var headAnnotatedCommit: OpaquePointer? = nil
            defer { if headAnnotatedCommit != nil { git_annotated_commit_free(headAnnotatedCommit) } }

            git_annotated_commit_lookup(&headAnnotatedCommit, repo, &headOID)

            git_merge_analysis(&analysis, &preference, repo, &annotatedCommit, 1)

            // 检查是否已经是最新
            if analysis.rawValue & GIT_MERGE_ANALYSIS_UP_TO_DATE.rawValue != 0 {
                if verbose { os_log("\(self.t)Already up to date") }
                return
            }

            // 执行合并
            var mergeOpts = git_merge_options()
            git_merge_init_options(&mergeOpts, UInt32(GIT_MERGE_OPTIONS_VERSION))

            var checkoutOpts = git_checkout_options()
            git_checkout_init_options(&checkoutOpts, UInt32(GIT_CHECKOUT_OPTIONS_VERSION))
            checkoutOpts.checkout_strategy = GIT_CHECKOUT_SAFE.rawValue

            let mergeResult = git_merge(repo, &annotatedCommit, 1, &mergeOpts, &checkoutOpts)

            if mergeResult != 0 {
                throw LibGit2Error.mergeConflict
            }

            // 检查是否有冲突
            if try hasMergeConflicts(at: path) {
                if verbose { os_log("\(self.t)Merge conflicts detected") }
                throw LibGit2Error.mergeConflict
            }

            // 创建合并提交
            try createMergeCommit(branchName: branchName, at: path, verbose: verbose)

            if verbose { os_log("\(self.t)Merge completed successfully") }
        }
    }

    /// 快进合并
    /// - Parameters:
    ///   - branchName: 要合并的分支名称
    ///   - path: 仓库路径
    static func mergeFastForward(branchName: String, at path: String, verbose: Bool = true) throws {
        if verbose { os_log("\(self.t)Fast-forward merging branch: \(branchName)") }

        let repo = try openRepository(at: path)
        defer { git_repository_free(repo) }

        let branchRef = "refs/heads/\(branchName)"
        var branchOID = git_oid()

        guard git_reference_name_to_id(&branchOID, repo, branchRef) == 0 else {
            throw LibGit2Error.checkoutFailed(branchName)
        }

        // 分析是否可以快进
        var annotatedCommit: OpaquePointer? = nil
        defer { if annotatedCommit != nil { git_annotated_commit_free(annotatedCommit) } }

        git_annotated_commit_lookup(&annotatedCommit, repo, &branchOID)

        var analysis = git_merge_analysis_t.init(0)
        var preference = git_merge_preference_t.init(0)

        git_merge_analysis(&analysis, &preference, repo, &annotatedCommit, 1)

        if analysis.rawValue & GIT_MERGE_ANALYSIS_FASTFORWARD.rawValue == 0 {
            throw LibGit2Error.mergeConflict
        }

        var mergeOpts = git_merge_options()
        git_merge_init_options(&mergeOpts, UInt32(GIT_MERGE_OPTIONS_VERSION))

        var checkoutOpts = makeSafeCheckoutOptions()
        let mergeResult = git_merge(repo, &annotatedCommit, 1, &mergeOpts, &checkoutOpts)
        if mergeResult != 0 {
            throw errorFromCheckoutResult(mergeResult, context: branchName)
        }
        git_repository_state_cleanup(repo)

        if verbose { os_log("\(self.t)Fast-forward merge completed") }
    }

    /// 获取合并冲突文件列表
    /// - Parameter path: 仓库路径
    /// - Returns: 冲突文件路径列表
    static func getMergeConflictFiles(at path: String) throws -> [String] {
        let repo = try openRepository(at: path)
        defer { git_repository_free(repo) }

        var index: OpaquePointer? = nil
        defer { if index != nil { git_index_free(index) } }

        guard git_repository_index(&index, repo) == 0 else {
            throw LibGit2Error.cannotGetIndex
        }

        var conflictFiles: [String] = []
        guard let index else { return [] }
        let count = git_index_entrycount(index)

        for i in 0..<count {
            let entry = git_index_get_byindex(index, i)

            if entry != nil && git_index_entry_is_conflict(entry!) == 1 {
                if let path = entry?.pointee.path {
                    conflictFiles.append(String(cString: path))
                }
            }
        }

        return conflictFiles
    }

    /// 检查是否有合并冲突
    /// - Parameter path: 仓库路径
    /// - Returns: 如果有冲突返回 true
    static func hasMergeConflicts(at path: String) throws -> Bool {
        let conflicts = try getMergeConflictFiles(at: path)
        return !conflicts.isEmpty
    }

    /// 列出索引中存在未合并条目的路径（去重并排序）。
    ///
    /// 这是合并冲突的权威来源，覆盖所有冲突类型：内容冲突（UU）、双方
    /// 新增/删除（AA/DD）、一方新增或删除（AU/UA/DU/UD）等，不依赖
    /// 工作区状态遍历的 XY 状态码映射。
    /// - Parameter path: 仓库路径
    /// - Returns: 冲突文件相对仓库根的路径列表
    public static func getConflictedPaths(at path: String) throws -> [String] {
        var seen = Set<String>()
        var paths: [String] = []
        // 同一个冲突路径在索引中最多有 stage 1/2/3 三个条目，需要去重。
        for conflict in try getMergeConflictFiles(at: path) where seen.insert(conflict).inserted {
            paths.append(conflict)
        }
        return paths.sorted()
    }

    /// 检查是否正在合并。
    ///
    /// 使用 `LibGit2.repositoryState(at:)` 判定，而不是探测 `.git/MERGE_HEAD`。
    /// 后者在 worktree（`.git` 是文件而非目录）与 seqencer 状态下不可靠。
    /// - Parameter path: 仓库路径
    /// - Returns: 如果正在合并返回 true
    static func isMerging(at path: String) throws -> Bool {
        try repositoryState(at: path) == .merge
    }

    /// 中止合并
    /// - Parameter path: 仓库路径
    public static func abortMerge(at path: String, verbose: Bool = true) throws {
        try LibGit2.serialized(at: path) {
            if verbose { os_log("\(self.t)Aborting merge") }

            let repo = try openRepository(at: path)
            defer { git_repository_free(repo) }

            // 清理合并状态
            git_repository_state_cleanup(repo)

            // 重置到 HEAD
            var headOID = git_oid()
            if git_reference_name_to_id(&headOID, repo, "HEAD") == 0 {
                var headCommit: OpaquePointer? = nil
                defer { if headCommit != nil { git_commit_free(headCommit) } }

                if git_commit_lookup(&headCommit, repo, &headOID) == 0 {
                    guard let headCommit else { return }
                    git_reset(repo, headCommit, GIT_RESET_HARD, nil)
                }
            }

            if verbose { os_log("\(self.t)Merge aborted") }
        }
    }

    /// 继续合并（解决冲突后创建合并提交）
    /// - Parameters:
    ///   - branchName: 分支名称
    ///   - path: 仓库路径
    public static func continueMerge(branchName: String, at path: String, verbose: Bool = true) throws {
        try LibGit2.serialized(at: path) {
            if verbose { os_log("\(self.t)Continuing merge") }

            if try hasMergeConflicts(at: path) {
                throw LibGit2Error.mergeConflict
            }

            // 创建合并提交
            try createMergeCommit(branchName: branchName, at: path, verbose: verbose)

            // 清理合并状态
            let repo = try openRepository(at: path)
            defer { git_repository_free(repo) }

            git_repository_state_cleanup(repo)

            if verbose { os_log("\(self.t)Merge continued") }
        }
    }

    // MARK: - 私有辅助方法

    /// 创建合并提交
    static func createMergeCommit(branchName: String, at path: String, verbose: Bool) throws {
        let repo = try openRepository(at: path)
        defer { git_repository_free(repo) }

        // 获取 MERGE_HEAD
        var mergeHeadOID = git_oid()
        guard git_reference_name_to_id(&mergeHeadOID, repo, "MERGE_HEAD") == 0 else {
            throw LibGit2Error.mergeConflict
        }

        var mergeHeadCommit: OpaquePointer? = nil

        guard git_commit_lookup(&mergeHeadCommit, repo, &mergeHeadOID) == 0 else {
            throw LibGit2Error.mergeConflict
        }

        // 获取 HEAD
        var headOID = git_oid()
        guard git_reference_name_to_id(&headOID, repo, "HEAD") == 0 else {
            throw LibGit2Error.cannotGetHEAD
        }

        var headCommit: OpaquePointer? = nil

        guard git_commit_lookup(&headCommit, repo, &headOID) == 0 else {
            throw LibGit2Error.cannotGetHEAD
        }

        // 写入 tree
        var index: OpaquePointer? = nil
        defer { if index != nil { git_index_free(index) } }

        guard git_repository_index(&index, repo) == 0 else {
            throw LibGit2Error.cannotGetIndex
        }

        var treeOID = git_oid()
        guard git_index_write_tree(&treeOID, index) == 0 else {
            throw LibGit2Error.cannotWriteTree
        }

        var tree: OpaquePointer? = nil
        defer { if tree != nil { git_tree_free(tree) } }

        guard git_tree_lookup(&tree, repo, &treeOID) == 0 else {
            throw LibGit2Error.cannotWriteTree
        }

        // 创建签名
        let signature = try createSignature(at: path, verbose: verbose)
        defer { git_signature_free(signature) }

        // 构建合并提交信息
        let message = "Merge branch '\(branchName)'"

        // 创建提交（两个父提交）
        var parents = [headCommit, mergeHeadCommit]
        defer {
            for parent in parents {
                if parent != nil {
                    if let parent { git_commit_free(parent) }
                }
            }
        }

        var commitOID = git_oid()

        let result = parents.withUnsafeMutableBufferPointer { buffer in
            git_commit_create(
                &commitOID,
                repo,
                "HEAD",
                signature,
                signature,
                nil,
                message,
                tree,
                buffer.count,
                buffer.baseAddress
            )
        }

        if result != 0 {
            throw LibGit2Error.commitFailed
        }
    }
}
