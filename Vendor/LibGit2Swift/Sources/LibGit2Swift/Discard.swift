import Foundation
import Clibgit2
import OSLog

/// 丢弃工作区变更的操作。
extension LibGit2 {
    /// 丢弃单个文件的所有变更。
    ///
    /// 与 `checkoutFile` 不同，此操作会同时处理暂存区和工作区：
    /// HEAD 中不存在的文件会被从 index 移除并从磁盘删除。
    public static func discardFileChanges(
        _ filePath: String,
        at path: String,
        verbose: Bool = true
    ) throws {
        try discardFiles([filePath], at: path, verbose: verbose)
    }

    /// 丢弃指定文件的所有变更，同时保留未选中文件的变更。
    ///
    /// 已跟踪文件从 HEAD 恢复到工作区和 index；HEAD 中不存在的暂存或未跟踪
    /// 文件会从 index 移除并从工作区删除。空仓库也支持该操作。
    public static func discardFiles(
        _ filePaths: [String],
        at path: String,
        verbose: Bool = true
    ) throws {
        let paths = filePaths.filter { !$0.isEmpty }
        guard !paths.isEmpty else { return }

        try LibGit2.serialized(at: path) {
            if verbose {
                os_log("LibGit2: Discarding %{public}d selected file changes", paths.count)
            }

            let repo = try openRepositoryUnlocked(at: path)
            defer { git_repository_free(repo) }

            var index: OpaquePointer?
            guard git_repository_index(&index, repo) == 0, let index else {
                throw LibGit2Error.cannotGetIndex
            }
            defer { git_index_free(index) }

            let workdir = workdirURL(for: repo)
            let headTree = try headTreeIfAvailable(for: repo)
            defer {
                if let headTree {
                    git_tree_free(headTree)
                }
            }

            for filePath in paths {
                let trackedInHead = headTreeContains(headTree, filePath: filePath)

                if trackedInHead, let headTree {
                    try restoreHeadFile(
                        filePath,
                        repo: repo,
                        headTree: headTree,
                        index: index
                    )
                } else {
                    try removeWorktreeItem(filePath, from: workdir)

                    // 对未跟踪文件来说，remove_bypath 会返回“未找到”，这是预期的
                    // no-op；真正的 index 访问错误已经在上面打开 index 时处理。
                    _ = git_index_remove_bypath(index, filePath)
                }
            }

            guard git_index_write(index) == 0 else {
                throw LibGit2Error.cannotGetIndex
            }
        }
    }

    private static func headTreeIfAvailable(for repo: OpaquePointer) throws -> OpaquePointer? {
        var headOID = git_oid()
        guard git_reference_name_to_id(&headOID, repo, "HEAD") == 0 else {
            return nil
        }

        var commit: OpaquePointer?
        guard git_commit_lookup(&commit, repo, &headOID) == 0, let commit else {
            throw LibGit2Error.cannotGetHEAD
        }
        defer { git_commit_free(commit) }

        var tree: OpaquePointer?
        guard git_commit_tree(&tree, commit) == 0, let tree else {
            throw LibGit2Error.cannotGetHEAD
        }
        return tree
    }

    private static func headTreeContains(_ tree: OpaquePointer?, filePath: String) -> Bool {
        guard let tree else { return false }

        var entry: OpaquePointer?
        let result = git_tree_entry_bypath(&entry, tree, filePath)
        if let entry {
            git_tree_entry_free(entry)
        }
        return result == 0
    }

    private static func restoreHeadFile(
        _ filePath: String,
        repo: OpaquePointer,
        headTree: OpaquePointer,
        index: OpaquePointer
    ) throws {
        var checkoutOptions = git_checkout_options()
        guard git_checkout_init_options(&checkoutOptions, UInt32(GIT_CHECKOUT_OPTIONS_VERSION)) == 0 else {
            throw LibGit2Error.checkoutFailed(filePath)
        }
        checkoutOptions.checkout_strategy = GIT_CHECKOUT_FORCE.rawValue
            | GIT_CHECKOUT_RECREATE_MISSING.rawValue
            | GIT_CHECKOUT_DISABLE_PATHSPEC_MATCH.rawValue

        let pathCString = strdup(filePath)
        guard let pathCString else {
            throw LibGit2Error.invalidValue
        }
        defer { free(pathCString) }

        var pathStrings: [UnsafeMutablePointer<CChar>?] = [pathCString]
        let checkoutResult = pathStrings.withUnsafeMutableBufferPointer { buffer -> Int32 in
            checkoutOptions.paths = git_strarray(
                strings: buffer.baseAddress,
                count: 1
            )
            return git_checkout_tree(repo, headTree, &checkoutOptions)
        }

        guard checkoutResult == 0 else {
            throw errorFromCheckoutResult(checkoutResult, context: filePath)
        }

        // git_checkout_tree 通常会同步 index，但显式刷新一次可以保证在调用方
        // 持有同一个 index 对象时，暂存内容也与 HEAD 一致。
        guard git_index_add_bypath(index, filePath) == 0 else {
            throw LibGit2Error.cannotGetIndex
        }
    }

    private static func workdirURL(for repo: OpaquePointer) -> URL? {
        guard let workdirPointer = git_repository_workdir(repo) else { return nil }
        return URL(
            fileURLWithPath: String(cString: workdirPointer),
            isDirectory: true
        ).standardizedFileURL
    }

    private static func removeWorktreeItem(_ filePath: String, from workdir: URL?) throws {
        guard let workdir else { return }

        let target = URL(fileURLWithPath: filePath, relativeTo: workdir).standardizedFileURL
        guard target.path != workdir.path, target.path.hasPrefix(workdir.path + "/") else {
            throw LibGit2Error.invalidValue
        }

        if FileManager.default.fileExists(atPath: target.path) {
            try FileManager.default.removeItem(at: target)
        }
    }
}
