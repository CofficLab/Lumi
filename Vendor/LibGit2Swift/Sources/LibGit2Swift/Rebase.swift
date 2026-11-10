import Clibgit2
import Foundation

/// libgit2 原生 rebase 操作。
///
/// 非交互式 rebase 会自动逐个应用提交；遇到冲突时保留仓库的 rebase 状态，
/// 上层可以解决冲突后调用 `continueRebase`，或调用 `abortRebase` 回滚。
extension LibGit2 {
    /// 将当前分支从 `upstream` 之后的提交变基到 `onto`。
    public static func rebase(
        at path: String,
        branch: String? = nil,
        upstream: String? = nil,
        onto: String? = nil,
        verbose: Bool = true
    ) throws {
        try LibGit2.serialized(at: path) {
            let repo = try openRepositoryUnlocked(at: path)
            defer { git_repository_free(repo) }

            var branchCommit: OpaquePointer?
            var upstreamCommit: OpaquePointer?
            var ontoCommit: OpaquePointer?
            defer {
                if branchCommit != nil { git_annotated_commit_free(branchCommit) }
                if upstreamCommit != nil { git_annotated_commit_free(upstreamCommit) }
                if ontoCommit != nil { git_annotated_commit_free(ontoCommit) }
            }

            if let branch {
                branchCommit = try annotatedCommit(for: branch, in: repo)
            }
            if let upstream {
                upstreamCommit = try annotatedCommit(for: upstream, in: repo)
            }
            if let onto {
                ontoCommit = try annotatedCommit(for: onto, in: repo)
            }

            var options = git_rebase_options()
            guard git_rebase_options_init(&options, UInt32(GIT_REBASE_OPTIONS_VERSION)) == 0 else {
                throw LibGit2Error.invalidRepositoryState("Failed to initialize rebase options.")
            }
            options.quiet = verbose ? 0 : 1
            options.checkout_options.checkout_strategy = GIT_CHECKOUT_SAFE.rawValue

            var rebaseObject: OpaquePointer?
            let result = git_rebase_init(
                &rebaseObject,
                repo,
                branchCommit,
                upstreamCommit,
                ontoCommit,
                &options
            )
            guard result == 0, let rebaseObject else {
                throw LibGit2Error.invalidRepositoryState(lastGitError("Failed to initialize rebase."))
            }
            defer { git_rebase_free(rebaseObject) }

            try applyRebaseOperations(rebaseObject, repo: repo)
        }
    }

    /// 继续一个已经解决冲突的 rebase。
    public static func continueRebase(at path: String, verbose: Bool = true) throws {
        try LibGit2.serialized(at: path) {
            let repo = try openRepositoryUnlocked(at: path)
            defer { git_repository_free(repo) }
            var options = git_rebase_options()
            guard git_rebase_options_init(&options, UInt32(GIT_REBASE_OPTIONS_VERSION)) == 0 else {
                throw LibGit2Error.invalidRepositoryState("Failed to initialize rebase options.")
            }
            options.quiet = verbose ? 0 : 1

            var rebaseObject: OpaquePointer?
            let result = git_rebase_open(&rebaseObject, repo, &options)
            guard result == 0, let rebaseObject else {
                throw LibGit2Error.invalidRepositoryState("No rebase is in progress.")
            }
            defer { git_rebase_free(rebaseObject) }
            try applyRebaseOperations(rebaseObject, repo: repo, commitCurrentOperation: true)
        }
    }

    /// 中止当前 rebase，并恢复到开始前的 HEAD 与工作区。
    public static func abortRebase(at path: String, verbose: Bool = true) throws {
        try LibGit2.serialized(at: path) {
            let repo = try openRepositoryUnlocked(at: path)
            defer { git_repository_free(repo) }
            var options = git_rebase_options()
            guard git_rebase_options_init(&options, UInt32(GIT_REBASE_OPTIONS_VERSION)) == 0 else {
                throw LibGit2Error.invalidRepositoryState("Failed to initialize rebase options.")
            }

            var rebaseObject: OpaquePointer?
            let openResult = git_rebase_open(&rebaseObject, repo, &options)
            guard openResult == 0, let rebaseObject else {
                throw LibGit2Error.invalidRepositoryState("No rebase is in progress.")
            }
            defer { git_rebase_free(rebaseObject) }
            let result = git_rebase_abort(rebaseObject)
            guard result == 0 else {
                throw LibGit2Error.invalidRepositoryState(lastGitError("Failed to abort rebase."))
            }
        }
    }

    private static func applyRebaseOperations(
        _ rebase: OpaquePointer,
        repo: OpaquePointer,
        commitCurrentOperation: Bool = false
    ) throws {
        var signature: UnsafeMutablePointer<git_signature>?
        guard git_signature_default(&signature, repo) == 0, let signature else {
            throw LibGit2Error.commitFailed
        }
        defer { git_signature_free(signature) }

        if commitCurrentOperation {
            let currentIndex = git_rebase_operation_current(rebase)
            if currentIndex != GIT_REBASE_NO_OPERATION,
               let operation = git_rebase_operation_byindex(rebase, currentIndex) {
                try commitRebaseOperation(operation, rebase: rebase, repo: repo, signature: signature)
            }
        }

        while true {
            var operation: UnsafeMutablePointer<git_rebase_operation>?
            let nextResult = git_rebase_next(&operation, rebase)
            if nextResult == GIT_ITEROVER.rawValue { break }
            if nextResult != 0 {
                throw nextResult == GIT_ECONFLICT.rawValue
                    ? LibGit2Error.mergeConflict
                    : LibGit2Error.invalidRepositoryState(lastGitError("Failed to apply rebase operation."))
            }
            guard let operation else { throw LibGit2Error.invalidRepositoryState("Rebase operation is missing.") }

            try commitRebaseOperation(operation, rebase: rebase, repo: repo, signature: signature)
        }

        let finishResult = git_rebase_finish(rebase, signature)
        guard finishResult == 0 else {
            throw LibGit2Error.invalidRepositoryState(lastGitError("Failed to finish rebase."))
        }
    }

    private static func commitRebaseOperation(
        _ operation: UnsafeMutablePointer<git_rebase_operation>,
        rebase: OpaquePointer,
        repo: OpaquePointer,
        signature: UnsafeMutablePointer<git_signature>
    ) throws {
        switch operation.pointee.type {
        case GIT_REBASE_OPERATION_EXEC:
            return
        default:
            var commit: OpaquePointer?
            var operationOID = operation.pointee.id
            guard git_commit_lookup(&commit, repo, &operationOID) == 0, let commit else {
                throw LibGit2Error.invalidReference
            }
            defer { git_commit_free(commit) }

            var newOID = git_oid()
            let message = git_commit_message(commit)
            let commitResult = git_rebase_commit(
                &newOID,
                rebase,
                nil,
                signature,
                nil,
                message
            )
            if commitResult == GIT_EAPPLIED.rawValue { return }
            if commitResult == GIT_EUNMERGED.rawValue || commitResult == GIT_ECONFLICT.rawValue {
                throw LibGit2Error.mergeConflict
            }
            guard commitResult == 0 else {
                throw LibGit2Error.commitFailed
            }
        }
    }

    private static func annotatedCommit(for revision: String, in repo: OpaquePointer) throws -> OpaquePointer {
        var oid = git_oid()
        guard git_revparse_single_oid(&oid, repo: repo, revision: revision) else {
            throw LibGit2Error.invalidReference
        }
        var annotated: OpaquePointer?
        guard git_annotated_commit_lookup(&annotated, repo, &oid) == 0, let annotated else {
            throw LibGit2Error.invalidReference
        }
        return annotated
    }

    private static func git_revparse_single_oid(
        _ oid: UnsafeMutablePointer<git_oid>,
        repo: OpaquePointer,
        revision: String
    ) -> Bool {
        var object: OpaquePointer?
        let result = revision.withCString { git_revparse_single(&object, repo, $0) }
        defer { if object != nil { git_object_free(object) } }
        guard result == 0, let object else { return false }
        guard let objectID = git_object_id(object) else { return false }
        oid.pointee = objectID.pointee
        return true
    }

    private static func lastGitError(_ fallback: String) -> String {
        git_error_last().map { String(cString: $0.pointee.message) } ?? fallback
    }
}
