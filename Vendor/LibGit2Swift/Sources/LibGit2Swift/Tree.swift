import Clibgit2
import Foundation

/// Read-only helpers for the tree reachable from `HEAD`.
extension LibGit2 {
    /// Returns all regular files tracked by `HEAD`, using libgit2 tree objects.
    ///
    /// Paths use Git's forward-slash separator and are relative to the
    /// repository root. The working tree and index are intentionally ignored;
    /// callers that need worktree changes should use the status APIs instead.
    public static func getTrackedFilePaths(
        at path: String,
        cancellation: GitCancellationToken? = nil
    ) throws -> [String] {
        try LibGit2.serialized(at: path) {
            try checkCancellation(cancellation)
            let repository = try openRepositoryUnlocked(at: path)
            defer { git_repository_free(repository) }

            var headOID = git_oid()
            guard git_reference_name_to_id(&headOID, repository, "HEAD") == 0 else {
                throw LibGit2Error.invalidReference
            }

            var commit: OpaquePointer?
            guard git_commit_lookup(&commit, repository, &headOID) == 0, let commit else {
                throw LibGit2Error.invalidReference
            }
            defer { git_commit_free(commit) }

            var tree: OpaquePointer?
            guard git_commit_tree(&tree, commit) == 0, let tree else {
                throw LibGit2Error.invalidReference
            }
            defer { git_tree_free(tree) }

            return try trackedFilePaths(
                in: repository,
                tree: tree,
                prefix: "",
                cancellation: cancellation
            )
        }
    }

    private static func trackedFilePaths(
        in repository: OpaquePointer,
        tree: OpaquePointer,
        prefix: String,
        cancellation: GitCancellationToken?
    ) throws -> [String] {
        var paths: [String] = []
        let count = git_tree_entrycount(tree)
        paths.reserveCapacity(Int(count))

        for index in 0..<count {
            try checkCancellation(cancellation)
            guard let entry = git_tree_entry_byindex(tree, index),
                  let namePointer = git_tree_entry_name(entry) else {
                continue
            }

            let name = String(cString: namePointer)
            let relativePath = prefix.isEmpty ? name : "\(prefix)/\(name)"
            if git_tree_entry_type(entry) == GIT_OBJECT_TREE {
                let entryOID = git_tree_entry_id(entry)
                var childTree: OpaquePointer?
                guard let entryOID,
                      git_tree_lookup(&childTree, repository, entryOID) == 0,
                      let childTree else {
                    throw LibGit2Error.invalidReference
                }
                defer { git_tree_free(childTree) }
                paths.append(contentsOf: try trackedFilePaths(
                    in: repository,
                    tree: childTree,
                    prefix: relativePath,
                    cancellation: cancellation
                ))
            } else {
                paths.append(relativePath)
            }
        }

        return paths
    }
}
