import Clibgit2
import Foundation

public enum GitConflictFileVersion {
    case base
    case ours
    case theirs
}

extension LibGit2 {
    public static func conflictFileContent(path filePath: String, version: GitConflictFileVersion, at path: String) throws -> String {
        return try LibGit2.serialized(at: path) {
            let data = try conflictFileData(path: filePath, version: version, at: path)
            return String(decoding: data, as: UTF8.self)
        }
    }

    public static func checkoutConflictFileVersion(path filePath: String, version: GitConflictFileVersion, at path: String) throws {
        try LibGit2.serialized(at: path) {
            let data = try conflictFileData(path: filePath, version: version, at: path)
            let targetURL = URL(fileURLWithPath: path, isDirectory: true).appendingPathComponent(filePath)
            try FileManager.default.createDirectory(
                at: targetURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            try data.write(to: targetURL)
        }
    }

    public static func revertCommit(_ commitHash: String, at path: String, verbose: Bool = true) throws {
        try LibGit2.serialized(at: path) {
            let repo = try openRepository(at: path)
            defer { git_repository_free(repo) }

            let commit = try lookupCommit(commitHash, in: repo)
            defer { git_commit_free(commit) }

            var options = git_revert_options()
            git_revert_options_init(&options, UInt32(GIT_REVERT_OPTIONS_VERSION))
            options.checkout_opts.checkout_strategy = GIT_CHECKOUT_SAFE.rawValue

            let result = git_revert(repo, commit, &options)
            if result != 0 {
                throw LibGit2Error.mergeConflict
            }

            if try hasMergeConflicts(at: path) {
                throw LibGit2Error.mergeConflict
            }

            let subject = commitSummary(commit)
            _ = try createCommit(message: "Revert \"\(subject)\"", at: path, verbose: verbose)
            git_repository_state_cleanup(repo)
        }
    }

    public static func cherryPick(commits commitHashes: [String], at path: String, verbose: Bool = true) throws {
        try LibGit2.serialized(at: path) {
            let trimmedHashes = commitHashes
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { $0.isEmpty == false }

            guard trimmedHashes.isEmpty == false else {
                throw LibGit2Error.invalidReference
            }

            for hash in trimmedHashes {
                try cherryPickOne(commitHash: hash, at: path, verbose: verbose)
            }
        }
    }

    public static func continueCherryPick(at path: String, verbose: Bool = true) throws {
        try LibGit2.serialized(at: path) {
            if try hasMergeConflicts(at: path) {
                throw LibGit2Error.mergeConflict
            }

            let repo = try openRepository(at: path)
            defer { git_repository_free(repo) }

            var oid = git_oid()
            guard git_reference_name_to_id(&oid, repo, "CHERRY_PICK_HEAD") == 0 else {
                throw LibGit2Error.invalidReference
            }

            var commit: OpaquePointer?
            defer { if commit != nil { git_commit_free(commit) } }
            guard git_commit_lookup(&commit, repo, &oid) == 0, let commit else {
                throw LibGit2Error.invalidReference
            }

            _ = try createCommit(message: commitMessage(commit), at: path, verbose: verbose)
            git_repository_state_cleanup(repo)
        }
    }

    public static func abortCherryPick(at path: String, verbose: Bool = true) throws {
        try LibGit2.serialized(at: path) {
            try reset(to: nil, mode: "hard", at: path, verbose: verbose)

            let repo = try openRepository(at: path)
            defer { git_repository_free(repo) }
            git_repository_state_cleanup(repo)
        }
    }

    private static func cherryPickOne(commitHash: String, at path: String, verbose: Bool) throws {
        let repo = try openRepository(at: path)
        defer { git_repository_free(repo) }

        let commit = try lookupCommit(commitHash, in: repo)
        defer { git_commit_free(commit) }

        var options = git_cherrypick_options()
        git_cherrypick_options_init(&options, UInt32(GIT_CHERRYPICK_OPTIONS_VERSION))
        options.checkout_opts.checkout_strategy = GIT_CHECKOUT_SAFE.rawValue

        let result = git_cherrypick(repo, commit, &options)
        if result != 0 {
            throw LibGit2Error.mergeConflict
        }

        if try hasMergeConflicts(at: path) {
            throw LibGit2Error.mergeConflict
        }

        _ = try createCommit(message: commitMessage(commit), at: path, verbose: verbose)
        git_repository_state_cleanup(repo)
    }

    private static func conflictFileData(path filePath: String, version: GitConflictFileVersion, at path: String) throws -> Data {
        let repo = try openRepository(at: path)
        defer { git_repository_free(repo) }

        var index: OpaquePointer?
        defer { if index != nil { git_index_free(index) } }
        guard git_repository_index(&index, repo) == 0, let index else {
            throw LibGit2Error.cannotGetIndex
        }

        var ancestor: UnsafePointer<git_index_entry>?
        var ours: UnsafePointer<git_index_entry>?
        var theirs: UnsafePointer<git_index_entry>?
        let result = git_index_conflict_get(&ancestor, &ours, &theirs, index, filePath)
        guard result == 0 else {
            throw LibGit2Error.invalidReference
        }

        let selected: UnsafePointer<git_index_entry>?
        switch version {
        case .base:
            selected = ancestor
        case .ours:
            selected = ours
        case .theirs:
            selected = theirs
        }

        guard let selected else {
            throw LibGit2Error.invalidReference
        }

        var oid = selected.pointee.id
        var blob: OpaquePointer?
        defer { if blob != nil { git_blob_free(blob) } }
        guard git_blob_lookup(&blob, repo, &oid) == 0, let blob else {
            throw LibGit2Error.invalidReference
        }

        guard let content = git_blob_rawcontent(blob) else {
            return Data()
        }

        return Data(bytes: content, count: Int(git_blob_rawsize(blob)))
    }

    private static func lookupCommit(_ revision: String, in repo: OpaquePointer) throws -> OpaquePointer {
        var object: OpaquePointer?
        defer { if object != nil { git_object_free(object) } }

        guard git_revparse_single(&object, repo, revision) == 0, let object else {
            throw LibGit2Error.invalidReference
        }

        var peeled: OpaquePointer?
        guard git_object_peel(&peeled, object, GIT_OBJECT_COMMIT) == 0, let peeled else {
            throw LibGit2Error.invalidReference
        }

        return peeled
    }

    private static func commitMessage(_ commit: OpaquePointer) -> String {
        guard let message = git_commit_message(commit) else { return "" }
        return String(cString: message)
    }

    private static func commitSummary(_ commit: OpaquePointer) -> String {
        let message = commitMessage(commit)
        let firstLine = message.split(separator: "\n", omittingEmptySubsequences: false).first.map(String.init) ?? ""
        return firstLine.isEmpty ? oidToString(git_commit_id(commit).pointee) : firstLine
    }
}
