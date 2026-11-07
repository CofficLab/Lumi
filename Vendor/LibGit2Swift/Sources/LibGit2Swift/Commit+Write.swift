import Clibgit2
import Foundation
import OSLog

/// LibGit2 提交写入操作扩展
extension LibGit2 {
    /// 创建提交
    /// - Parameters:
    ///   - message: 提交信息
    ///   - path: 仓库路径
    ///   - verbose: 是否输出详细日志，默认为true
    /// - Returns: 创建的提交哈希
    public static func createCommit(message: String, at path: String, verbose: Bool) throws -> String {
        return try LibGit2.serialized(at: path) {
            if verbose { os_log("\(self.t)Creating commit with message: \(message)") }

            let repo = try openRepository(at: path)
            defer { git_repository_free(repo) }

            // 1. 获取 index
            var index: OpaquePointer?
            defer { if index != nil { git_index_free(index) } }

            guard git_repository_index(&index, repo) == 0,
                  let indexPtr = index else {
                throw LibGit2Error.cannotGetIndex
            }

            // 2. 检查是否有变更
            if git_index_entrycount(indexPtr) == 0 {
                // 检查是否有未提交的变更
                let hasChanges = try hasUncommittedChanges(at: path)
                if !hasChanges {
                    throw LibGit2Error.nothingToCommit
                }
            }

            // 3. 写入 tree
            var treeOID = git_oid()
            let treeResult = git_index_write_tree(&treeOID, indexPtr)

            if treeResult != 0 {
                throw LibGit2Error.cannotWriteTree
            }

            var tree: OpaquePointer?
            defer { if tree != nil { git_tree_free(tree) } }

            guard git_tree_lookup(&tree, repo, &treeOID) == 0 else {
                throw LibGit2Error.cannotWriteTree
            }

            // 4. 获取 HEAD commit 作为父提交
            var headCommit: OpaquePointer?
            var parents = [OpaquePointer?]()
            defer {
                for parent in parents {
                    if parent != nil {
                        if let parent { git_commit_free(parent) }
                    }
                }
            }

            var headOID = git_oid()
            if git_reference_name_to_id(&headOID, repo, "HEAD") == 0 {
                if git_commit_lookup(&headCommit, repo, &headOID) == 0, let commit = headCommit {
                    parents.append(commit)
                    headCommit = nil // set to nil for deferred free list to take over
                }
            }

            // 5. 创建签名
            let signature = try createSignature(at: path, verbose: verbose)
            defer { git_signature_free(signature) }

            // 6. 创建提交
            var commitOID = git_oid()
            let commitResult = parents.withUnsafeMutableBufferPointer { buffer in
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

            if commitResult != 0 {
                throw LibGit2Error.commitFailed
            }

            let commitHash = oidToString(commitOID)
            if verbose { os_log("\(self.t)Commit created successfully: \(commitHash)") }

            return commitHash
        }
    }

    /// 添加文件并提交
    /// - Parameters:
    ///   - files: 要添加的文件路径列表（空数组表示添加所有变更）
    ///   - message: 提交信息
    ///   - path: 仓库路径
    /// - Returns: 创建的提交哈希
    public static func addAndCommit(files: [String], message: String, at path: String, verbose: Bool = true) throws -> String {
        return try LibGit2.serialized(at: path) {
            if verbose { os_log("\(self.t)Adding and committing files: \(files)") }
            try addFiles(files, at: path, verbose: verbose)
            return try createCommit(message: message, at: path, verbose: verbose)
        }
    }

    /// 修改最后一次提交（amend）
    /// - Parameters:
    ///   - message: 新的提交信息（nil 表示不修改）
    ///   - path: 仓库路径
    /// - Returns: 新的提交哈希
    public static func amendCommit(message: String? = nil, at path: String, verbose: Bool) throws -> String {
        return try LibGit2.serialized(at: path) {
            if verbose { os_log("\(self.t)Amending commit with message: \(message ?? "nil")") }
            let repo = try openRepository(at: path)
            defer { git_repository_free(repo) }

            // 获取 HEAD commit
            var headOID = git_oid()
            guard git_reference_name_to_id(&headOID, repo, "HEAD") == 0 else {
                throw LibGit2Error.cannotGetHEAD
            }

            var headCommit: OpaquePointer?
            defer { if headCommit != nil { git_commit_free(headCommit) } }

            guard git_commit_lookup(&headCommit, repo, &headOID) == 0,
                  let commit = headCommit else {
                throw LibGit2Error.cannotGetHEAD
            }

            // 获取当前 index tree
            var index: OpaquePointer?
            defer { if index != nil { git_index_free(index) } }

            guard git_repository_index(&index, repo) == 0 else {
                throw LibGit2Error.cannotGetIndex
            }

            var treeOID = git_oid()
            guard git_index_write_tree(&treeOID, index) == 0 else {
                throw LibGit2Error.cannotWriteTree
            }

            var tree: OpaquePointer?
            defer { if tree != nil { git_tree_free(tree) } }

            guard git_tree_lookup(&tree, repo, &treeOID) == 0 else {
                throw LibGit2Error.cannotWriteTree
            }

            // 创建签名
            let signature = try createSignature(at: path, verbose: verbose)
            defer { git_signature_free(signature) }

            // 修改当前 HEAD 提交
            var newCommitOID = git_oid()
            let messageToUpdate = message ?? String(cString: git_commit_message(commit))

            let result = git_commit_amend(
                &newCommitOID,
                commit,
                "HEAD",
                nil,
                signature,
                nil,
                messageToUpdate,
                tree
            )

            if result != 0 {
                throw LibGit2Error.commitFailed
            }

            return oidToString(newCommitOID)
        }
    }
}
