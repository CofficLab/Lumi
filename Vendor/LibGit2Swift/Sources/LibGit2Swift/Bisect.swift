import Clibgit2
import Foundation

/// Bisect 状态
public struct GitBisectState: Equatable, Sendable {
    public let isBisecting: Bool
    public let startHash: String?
    public let currentHash: String?
    public let remainingSteps: Int?
    public let stepCount: Int?

    public init(
        isBisecting: Bool,
        startHash: String? = nil,
        currentHash: String? = nil,
        remainingSteps: Int? = nil,
        stepCount: Int? = nil
    ) {
        self.isBisecting = isBisecting
        self.startHash = startHash
        self.currentHash = currentHash
        self.remainingSteps = remainingSteps
        self.stepCount = stepCount
    }

    public static let inactive = GitBisectState(isBisecting: false)
}

extension LibGit2 {
    /// 检查当前是否在 bisect 过程中。
    public static func bisectState(at path: String) throws -> GitBisectState {
        return try LibGit2.serialized(at: path) {
            let gitDir = try gitDirectory(at: path)
            let bisectLogPath = (gitDir as NSString).appendingPathComponent("BISECT_LOG")

            guard FileManager.default.fileExists(atPath: bisectLogPath) else {
                return .inactive
            }

            let startHash = try? readFileString((gitDir as NSString).appendingPathComponent("BISECT_START"))
            let currentHash = try? readFileString((gitDir as NSString).appendingPathComponent("BISECT_EXPECTED_REV"))

            return GitBisectState(
                isBisecting: true,
                startHash: startHash,
                currentHash: currentHash
            )
        }
    }

    /// 开始 bisect，等价于 `git bisect start`。
    public static func bisectStart(
        badCommitHash: String? = nil,
        goodCommitHash: String? = nil,
        at path: String
    ) throws {
        try LibGit2.serialized(at: path) {
            let repo = try openRepository(at: path)
            defer { git_repository_free(repo) }

            let gitDir = try gitDirectory(at: path)
            cleanupBisectFiles(gitDir: gitDir)

            var startOID = git_oid()
            if let badCommitHash {
                guard git_oid_fromstr(&startOID, badCommitHash) == 0 else {
                    throw LibGit2Error.invalidValue
                }
            } else {
                guard git_reference_name_to_id(&startOID, repo, "HEAD") == 0 else {
                    throw LibGit2Error.cannotGetHEAD
                }
            }

            let startHash = oidToString(startOID)
            try startHash.write(
                toFile: (gitDir as NSString).appendingPathComponent("BISECT_START"),
                atomically: true, encoding: .utf8
            )
            try "git bisect start\n".write(
                toFile: (gitDir as NSString).appendingPathComponent("BISECT_LOG"),
                atomically: true, encoding: .utf8
            )

            // checkout 到 bad commit
            var commit: OpaquePointer?
            defer { if commit != nil { git_commit_free(commit) } }
            guard git_commit_lookup(&commit, repo, &startOID) == 0, let commit else {
                throw LibGit2Error.invalidValue
            }

            var tree: OpaquePointer?
            defer { if tree != nil { git_tree_free(tree) } }
            guard git_commit_tree(&tree, commit) == 0, let tree else {
                throw LibGit2Error.invalidValue
            }

            var checkoutOpts = git_checkout_options()
            git_checkout_init_options(&checkoutOpts, UInt32(GIT_CHECKOUT_OPTIONS_VERSION))
            checkoutOpts.checkout_strategy = GIT_CHECKOUT_SAFE.rawValue | GIT_CHECKOUT_RECREATE_MISSING.rawValue

            guard git_checkout_tree(repo, tree, &checkoutOpts) == 0 else {
                throw LibGit2Error.checkoutFailed("bisect checkout")
            }

            git_repository_set_head_detached(repo, &startOID)

            if let goodCommitHash {
                try bisectGood(goodCommitHash, at: path)
            }
        }
    }

    /// 标记当前 commit 为 good。
    @discardableResult
    public static func bisectGood(_ commitHash: String? = nil, at path: String) throws -> String? {
        return try LibGit2.serialized(at: path) {
            let gitDir = try gitDirectory(at: path)
            try? "good\nbad\n".write(
                toFile: (gitDir as NSString).appendingPathComponent("BISECT_TERMS"),
                atomically: true, encoding: .utf8
            )

            if let hash = commitHash {
                appendBisectLog(gitDir: gitDir, action: "good", hash: hash)
            }

            let refsDir = (gitDir as NSString).appendingPathComponent("refs/bisect")
            try? FileManager.default.createDirectory(atPath: refsDir, withIntermediateDirectories: true)

            let currentHash = commitHash ?? (try? currentHEADHash(at: path)) ?? ""
            try currentHash.write(
                toFile: (refsDir as NSString).appendingPathComponent("good-\(currentHash.prefix(8))"),
                atomically: true, encoding: .utf8
            )

            return nil
        }
    }

    /// 标记当前 commit 为 bad。
    @discardableResult
    public static func bisectBad(_ commitHash: String? = nil, at path: String) throws -> String? {
        return try LibGit2.serialized(at: path) {
            let gitDir = try gitDirectory(at: path)

            if let hash = commitHash {
                appendBisectLog(gitDir: gitDir, action: "bad", hash: hash)
            }

            let refsDir = (gitDir as NSString).appendingPathComponent("refs/bisect")
            try? FileManager.default.createDirectory(atPath: refsDir, withIntermediateDirectories: true)

            let currentHash = commitHash ?? (try? currentHEADHash(at: path)) ?? ""
            try currentHash.write(
                toFile: (refsDir as NSString).appendingPathComponent("bad"),
                atomically: true, encoding: .utf8
            )

            return nil
        }
    }

    /// 跳过当前 commit。
    public static func bisectSkip(at path: String) throws {
        try LibGit2.serialized(at: path) {
            let gitDir = try gitDirectory(at: path)
            let currentHash = try currentHEADHash(at: path)
            appendBisectLog(gitDir: gitDir, action: "skip", hash: currentHash)
        }
    }

    /// 结束 bisect，切换回原分支。
    public static func bisectReset(at path: String) throws {
        try LibGit2.serialized(at: path) {
            let gitDir = try gitDirectory(at: path)
            let startHash = try? readFileString((gitDir as NSString).appendingPathComponent("BISECT_START"))

            let branchName = try? getCurrentBranch(at: path)
            if let branch = branchName, branch.isEmpty == false {
                try? checkout(branch: branch, at: path)
            } else if let hash = startHash, hash.isEmpty == false {
                let branches = (try? getBranchList(at: path, includeRemote: false)) ?? []
                if let containingBranch = branches.first(where: { $0.latestCommitHash == hash }) {
                    try? checkout(branch: containingBranch.name, at: path)
                }
            }

            cleanupBisectFiles(gitDir: gitDir)
        }
    }

    // MARK: - Private

    private static func currentHEADHash(at path: String) throws -> String {
        let repo = try openRepository(at: path)
        defer { git_repository_free(repo) }
        var oid = git_oid()
        guard git_reference_name_to_id(&oid, repo, "HEAD") == 0 else {
            throw LibGit2Error.cannotGetHEAD
        }
        return oidToString(oid)
    }

    private static func appendBisectLog(gitDir: String, action: String, hash: String) {
        let logPath = (gitDir as NSString).appendingPathComponent("BISECT_LOG")
        let entry = "git bisect \(action) \(hash)\n"
        if let data = entry.data(using: .utf8),
           FileManager.default.fileExists(atPath: logPath) {
            if let handle = try? FileHandle(forWritingTo: URL(fileURLWithPath: logPath)) {
                handle.seekToEndOfFile()
                handle.write(data)
                handle.closeFile()
            }
        }
    }

    private static func cleanupBisectFiles(gitDir: String) {
        let files = ["BISECT_LOG", "BISECT_START", "BISECT_TERMS", "BISECT_EXPECTED_REV"]
        for file in files {
            let filePath = (gitDir as NSString).appendingPathComponent(file)
            try? FileManager.default.removeItem(atPath: filePath)
        }
        let refsDir = (gitDir as NSString).appendingPathComponent("refs/bisect")
        try? FileManager.default.removeItem(atPath: refsDir)
    }

    private static func readFileString(_ path: String) throws -> String {
        try String(contentsOfFile: path, encoding: .utf8)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
