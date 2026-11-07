import Clibgit2
import Foundation

/// HEAD 与 upstream 的解析。
///
/// 历史实现有两个互相牵连的缺陷，导致 `pull` / `push` 可能操作**错误的分支**：
///
/// 1. `getCurrentBranch` 只返回分支名，detached HEAD 时返回 commit SHA，
///    调用方无法区分两种情况。
/// 2. `pull` / `push` 假定远程分支名与本地分支名相同，完全忽略
///    `branch.<name>.remote` / `branch.<name>.merge`。
///
/// 本文件提供语义明确、返回值被检查的解析入口，作为网络类操作的唯一依据。
extension LibGit2 {

    /// 本地分支与其 upstream 的绑定关系。
    public struct UpstreamBinding: Equatable, Sendable {
        /// 本地分支名（短名，如 `main`）。
        public let localBranch: String
        /// 本地分支的完整引用名（如 `refs/heads/main`）。
        public let localReference: String
        /// upstream 所属远程名（如 `origin`）。
        public let remote: String
        /// upstream 在远程上的分支名（如 `release`）。
        public let remoteBranch: String
        /// upstream 在本地缓存的完整引用名（如 `refs/remotes/origin/release`）。
        public let remoteTrackingReference: String

        /// **fetch** 用 refspec。
        ///
        /// 方向是"远程 → 本地"：左侧必须是**远程**分支引用，右侧是本地跟踪引用。
        /// 不能写成 `本地分支:跟踪引用`——那会把远程的本地同名分支抓下来，
        /// 在"本地分支名 ≠ 远程分支名"时取到错误的分支。
        public var fetchRefspec: String {
            "refs/heads/\(remoteBranch):\(remoteTrackingReference)"
        }

        /// **push** 用 refspec。
        ///
        /// 方向是"本地 → 远程"：左侧是本地分支引用，右侧是远程分支引用。
        public var pushRefspec: String {
            "\(localReference):refs/heads/\(remoteBranch)"
        }
    }

    // MARK: - HEAD 解析

    /// 当前 HEAD 指向的本地分支短名；detached HEAD 或未出生(unborn)时返回 `nil`。
    ///
    /// 与 `getCurrentBranch` 的区别：后者在 detached 状态下返回 commit SHA，
    /// 容易被误当作分支名使用。需要明确区分时请使用本方法。
    public static func currentBranchName(at path: String) throws -> String? {
        try LibGit2.serialized(at: path) {
            let repo = try openRepositoryUnlocked(at: path)
            defer { git_repository_free(repo) }

            guard git_repository_head_detached(repo) != 1 else { return nil }

            var head: OpaquePointer?
            defer { if head != nil { git_reference_free(head) } }

            guard git_repository_head(&head, repo) == 0, let head else {
                // 未出生 HEAD（空仓库）会返回 GIT_EUNBORNBRANCH。
                return nil
            }
            // HEAD 可能是指向分支的符号引用，也可能是直接 OID 引用。
            guard git_reference_is_branch(head) == 1 else { return nil }
            guard let shorthand = git_reference_shorthand(head) else { return nil }
            return String(cString: shorthand)
        }
    }

    /// HEAD 当前指向的 commit hash；未出生(unborn)时返回 `nil`。detached 时同样有效。
    public static func headCommitHash(at path: String) throws -> String? {
        try LibGit2.serialized(at: path) { () -> String? in
            let repo = try openRepositoryUnlocked(at: path)
            defer { git_repository_free(repo) }

            var oid = git_oid()
            // git_reference_name_to_id 会解析 HEAD（符号或直接引用）到具体 commit，
            // 未出生 HEAD 返回 GIT_EUNBORNBRANCH，因此无需额外检查零 OID。
            guard git_reference_name_to_id(&oid, repo, "HEAD") == 0 else { return nil }
            return oidToString(oid)
        }
    }

    /// HEAD 是否 detached。
    public static func isHeadDetached(at path: String) throws -> Bool {
        try LibGit2.serialized(at: path) {
            let repo = try openRepositoryUnlocked(at: path)
            defer { git_repository_free(repo) }
            return git_repository_head_detached(repo) == 1
        }
    }

    // MARK: - Upstream 解析

    /// 解析指定本地分支的 upstream 绑定。
    ///
    /// 依据 `branch.<name>.remote` + `branch.<name>.merge`，这是 git 自身
    /// 判定 upstream 的唯一权威来源。缺少任一配置即视为未设置 upstream。
    ///
    /// - Parameter branch: 本地分支短名；传 `nil` 时使用当前 HEAD 分支。
    public static func upstreamBinding(
        for branch: String? = nil,
        at path: String
    ) throws -> UpstreamBinding? {
        try LibGit2.serialized(at: path) {
            let repo = try openRepositoryUnlocked(at: path)
            defer { git_repository_free(repo) }

            let localBranch: String
            if let branch {
                localBranch = branch
            } else {
                guard git_repository_head_detached(repo) != 1 else { return nil }
                var head: OpaquePointer?
                defer { if head != nil { git_reference_free(head) } }
                guard git_repository_head(&head, repo) == 0, let head,
                      git_reference_is_branch(head) == 1,
                      let shorthand = git_reference_shorthand(head) else {
                    return nil
                }
                localBranch = String(cString: shorthand)
            }

            var config: OpaquePointer?
            defer { if config != nil { git_config_free(config) } }
            guard git_repository_config(&config, repo) == 0, let config else {
                return nil
            }

            // libgit2 1.x 要求对 snapshot 读取字符串：直接读 live config 会返回
            // GIT_ERROR(-1)。这与 LibGit2.getConfig 的处理方式保持一致。
            var snapshot: OpaquePointer?
            defer { if snapshot != nil { git_config_free(snapshot) } }
            guard git_config_snapshot(&snapshot, config) == 0, let snapshot else {
                return nil
            }

            // 1. branch.<name>.remote
            //    特殊值 "." 表示 upstream 是同一仓库中的本地分支。
            var remoteBuffer: UnsafePointer<CChar>?
            let remoteKey = "branch.\(localBranch).remote"
            guard git_config_get_string(&remoteBuffer, snapshot, remoteKey) == 0,
                  let remoteBuffer else {
                return nil
            }
            let remote = String(cString: remoteBuffer)
            guard !remote.isEmpty else { return nil }

            // 2. branch.<name>.merge（存的是完整引用名 refs/heads/<name>）
            var mergeBuffer: UnsafePointer<CChar>?
            let mergeKey = "branch.\(localBranch).merge"
            guard git_config_get_string(&mergeBuffer, snapshot, mergeKey) == 0,
                  let mergeBuffer else {
                return nil
            }
            let mergeReference = String(cString: mergeBuffer)
            guard mergeReference.hasPrefix("refs/heads/") else { return nil }
            let remoteBranch = String(mergeReference.dropFirst("refs/heads/".count))

            let localReference = "refs/heads/\(localBranch)"
            let remoteTrackingReference = remote == "."
                ? mergeReference
                : "refs/remotes/\(remote)/\(remoteBranch)"

            return UpstreamBinding(
                localBranch: localBranch,
                localReference: localReference,
                remote: remote,
                remoteBranch: remoteBranch,
                remoteTrackingReference: remoteTrackingReference
            )
        }
    }

    /// 在**不获取额外锁**的前提下打开仓库。
    ///
    /// 供 `serialized(at:)` 闭包内部使用：此时当前线程已持有该仓库的执行队列，
    /// 再次走 `openRepository` 会命中重入检测（安全但语义冗余），直接裸调用
    /// 更省一层调度。
    static func openRepositoryUnlocked(at path: String) throws -> OpaquePointer {
        var repo: OpaquePointer?
        guard git_repository_open(&repo, path) == 0, let repo else {
            throw LibGit2Error.repositoryNotFound(path)
        }
        return repo
    }

    // MARK: - 合并基础 (merge base)

    /// 两个提交的合并基础 (merge base) commit hash。
    ///
    /// 合并冲突的「base」版本即来自此处：base 是双方共同的祖先，
    /// `ours` 是当前 HEAD，`theirs` 是正在被合并进来的提交。
    ///
    /// - Returns: 合并基础 commit hash；无共同祖先时返回 `nil`
    public static func mergeBase(
        between first: String,
        and second: String,
        at path: String
    ) throws -> String? {
        try LibGit2.serialized(at: path) {
            let repo = try openRepositoryUnlocked(at: path)
            defer { git_repository_free(repo) }

            var firstOID = git_oid()
            var secondOID = git_oid()
            guard git_oid_fromstr(&firstOID, first) == 0,
                  git_oid_fromstr(&secondOID, second) == 0 else {
                throw LibGit2Error.invalidValue
            }

            var mergeBaseOID = git_oid()
            guard git_merge_base(&mergeBaseOID, repo, &firstOID, &secondOID) == 0 else {
                // GIT_ENOTFOUND 表示两个提交没有共同祖先（例如不相关的历史）。
                return nil
            }
            return oidToString(mergeBaseOID)
        }
    }

    /// 合并冲突中 `base` 版本的文件内容。
    ///
    /// `base` 即 HEAD 与 MERGE_HEAD 的合并基础。此前 provider 只能对该版本
    /// 抛出"不支持"，因为库未暴露 merge-base 到文件内容的通路。
    ///
    /// - Parameters:
    ///   - filePath: 仓库内相对路径
    ///   - path: 仓库路径
    /// - Returns: base 版本内容；该文件在 base 中不存在时返回 `nil`
    public static func mergeBaseFileContent(
        path filePath: String,
        at path: String
    ) throws -> String? {
        try LibGit2.serialized(at: path) {
            let repo = try openRepositoryUnlocked(at: path)
            defer { git_repository_free(repo) }

            // HEAD 与 MERGE_HEAD 的合并基础。
            var headOID = git_oid()
            var mergeHeadOID = git_oid()
            guard git_reference_name_to_id(&headOID, repo, "HEAD") == 0,
                  git_reference_name_to_id(&mergeHeadOID, repo, "MERGE_HEAD") == 0 else {
                return nil
            }

            var mergeBaseOID = git_oid()
            guard git_merge_base(&mergeBaseOID, repo, &headOID, &mergeHeadOID) == 0 else {
                return nil
            }
            let baseHash = oidToString(mergeBaseOID)

            // 复用已实现的按提交取内容；文件在 base 中不存在时返回 nil。
            return try? getFileContent(atCommit: baseHash, file: filePath, at: path)
        }
    }
}
