import Clibgit2
import Foundation

private final class SubmoduleListPayload {
    var values: [GitSubmoduleInfo] = []
}

private let collectSubmoduleCallback: git_submodule_cb = { submodule, name, rawPayload in
    guard let submodule, let rawPayload else { return -1 }
    let payload = Unmanaged<SubmoduleListPayload>.fromOpaque(rawPayload).takeUnretainedValue()

    let path = git_submodule_path(submodule).map { String(cString: $0) }
        ?? name.map { String(cString: $0) }
        ?? ""

    var status: UInt32 = 0
    _ = git_submodule_status(&status, git_submodule_owner(submodule), path, GIT_SUBMODULE_IGNORE_NONE)

    let commitHash = submoduleCommitHash(submodule)
    let url = git_submodule_url(submodule).map { String(cString: $0) }
    payload.values.append(
        GitSubmoduleInfo(
            path: path,
            commitHash: commitHash,
            status: submoduleStatus(from: status),
            description: url
        )
    )
    return 0
}

private func submoduleCommitHash(_ submodule: OpaquePointer) -> String {
    if let indexID = git_submodule_index_id(submodule) {
        return LibGit2.oidToString(indexID.pointee)
    }
    if let headID = git_submodule_head_id(submodule) {
        return LibGit2.oidToString(headID.pointee)
    }
    if let wdID = git_submodule_wd_id(submodule) {
        return LibGit2.oidToString(wdID.pointee)
    }
    return ""
}

private func submoduleStatus(from rawStatus: UInt32) -> GitSubmoduleInfo.Status {
    if rawStatus & UInt32(GIT_SUBMODULE_STATUS_WD_UNINITIALIZED.rawValue) != 0
        || rawStatus & UInt32(GIT_SUBMODULE_STATUS_IN_WD.rawValue) == 0 {
        return .uninitialized
    }

    let modifiedMask = UInt32(GIT_SUBMODULE_STATUS_INDEX_ADDED.rawValue)
        | UInt32(GIT_SUBMODULE_STATUS_INDEX_DELETED.rawValue)
        | UInt32(GIT_SUBMODULE_STATUS_INDEX_MODIFIED.rawValue)
        | UInt32(GIT_SUBMODULE_STATUS_WD_ADDED.rawValue)
        | UInt32(GIT_SUBMODULE_STATUS_WD_DELETED.rawValue)
        | UInt32(GIT_SUBMODULE_STATUS_WD_MODIFIED.rawValue)
        | UInt32(GIT_SUBMODULE_STATUS_WD_INDEX_MODIFIED.rawValue)
        | UInt32(GIT_SUBMODULE_STATUS_WD_WD_MODIFIED.rawValue)
        | UInt32(GIT_SUBMODULE_STATUS_WD_UNTRACKED.rawValue)

    return rawStatus & modifiedMask == 0 ? .initialized : .modified
}

extension LibGit2 {
    public static func submodules(at path: String) throws -> [GitSubmoduleInfo] {
        return try LibGit2.serialized(at: path) {
            let repo = try openRepository(at: path)
            defer { git_repository_free(repo) }

            let payload = SubmoduleListPayload()
            let payloadPointer = Unmanaged.passUnretained(payload).toOpaque()

            let result = git_submodule_foreach(repo, collectSubmoduleCallback, payloadPointer)

            guard result == 0 else {
                throw LibGit2Error.invalidReference
            }

            return payload.values.sorted { $0.path < $1.path }
        }
    }

    public static func initializeSubmodules(paths: [String] = [], at path: String, recursive: Bool = true, verbose: Bool = true) throws {
        try LibGit2.serialized(at: path) {
            try updateSubmodules(paths: paths, at: path, initialize: true, recursive: recursive, verbose: verbose)
        }
    }

    public static func updateSubmodules(
        paths: [String] = [],
        at path: String,
        initialize: Bool = false,
        recursive: Bool = true,
        verbose: Bool = true
    ) throws {
        try LibGit2.serialized(at: path) {
            let repo = try openRepository(at: path)
            defer { git_repository_free(repo) }

            let selectedPaths = Set(paths.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { $0.isEmpty == false })
            let targets = selectedPaths.isEmpty ? try submodules(at: path).map(\.path) : Array(selectedPaths)

            for submodulePath in targets {
                var submodule: OpaquePointer?
                defer { if submodule != nil { git_submodule_free(submodule) } }

                guard git_submodule_lookup(&submodule, repo, submodulePath) == 0, let submodule else {
                    throw LibGit2Error.invalidReference
                }

                if initialize {
                    let initResult = git_submodule_init(submodule, 0)
                    if initResult != 0 && initResult != GIT_EEXISTS.rawValue {
                        throw LibGit2Error.checkoutFailed(submodulePath)
                    }
                }

                var options = git_submodule_update_options()
                git_submodule_update_options_init(&options, UInt32(GIT_SUBMODULE_UPDATE_OPTIONS_VERSION))
                options.checkout_opts.checkout_strategy = GIT_CHECKOUT_SAFE.rawValue
                options.fetch_opts.callbacks.credentials = gitCredentialCallback

                let result = git_submodule_update(submodule, initialize ? 1 : 0, &options)
                if result != 0 {
                    throw LibGit2Error.checkoutFailed(submodulePath)
                }
            }
        }
    }

    public static func submoduleDiff(path submodulePath: String, at path: String) throws -> String {
        return try LibGit2.serialized(at: path) {
            guard let submodule = try submodules(at: path).first(where: { $0.path == submodulePath }) else {
                throw LibGit2Error.invalidReference
            }

            var lines = ["Submodule \(submodule.path) \(submodule.status.rawValue)"]
            if submodule.commitHash.isEmpty == false {
                lines.append("Commit: \(submodule.commitHash)")
            }
            if let description = submodule.description, description.isEmpty == false {
                lines.append("URL: \(description)")
            }
            return lines.joined(separator: "\n")
        }
    }
}
