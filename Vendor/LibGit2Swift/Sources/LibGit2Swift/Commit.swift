import Foundation
import Clibgit2
import OSLog


/// LibGit2 提交历史操作扩展
extension LibGit2 {
    /// 提交遍历范围。
    public enum CommitTraversalScope: Sendable {
        /// 只遍历当前 HEAD 可达的提交，保持传统提交列表语义。
        case head
        /// 遍历所有本地分支、远程分支和标签可达的提交，用于提交拓扑图。
        case allReferences
    }

    /// 获取提交列表
    /// - Parameters:
    ///   - path: 仓库路径
    ///   - limit: 最大返回数量
    ///   - skip: 跳过的提交数量
    /// - Returns: 提交列表
    /// 获取提交列表
    /// - Parameters:
    ///   - path: 仓库路径
    ///   - limit: 最大返回数量
    ///   - skip: 跳过的提交数量
    /// - Returns: 提交列表
    public static func getCommitList(at path: String, limit: Int = Int.max, skip: Int = 0) throws -> [GitCommit] {
        return try LibGit2.serialized(at: path) {
            try getCommitList(at: path, scope: .head, limit: limit, skip: skip)
        }
    }

    /// 统计指定遍历范围内的提交数量，不把提交对象全部加载到内存。
    public static func getCommitCount(
        at path: String,
        scope: CommitTraversalScope = .head,
        cancellation: GitCancellationToken? = nil
    ) throws -> Int {
        try LibGit2.serialized(at: path) {
            try checkCancellation(cancellation)
            let repo = try openRepositoryUnlocked(at: path)
            defer { git_repository_free(repo) }

            var revwalk: OpaquePointer?
            guard git_revwalk_new(&revwalk, repo) == 0, let walker = revwalk else {
                throw LibGit2Error.cannotCreateRevwalk
            }
            defer { git_revwalk_free(walker) }
            git_revwalk_sorting(walker, GIT_SORT_TOPOLOGICAL.rawValue | GIT_SORT_TIME.rawValue)

            switch scope {
            case .head:
                guard git_revwalk_push_head(walker) == 0 else { return 0 }
            case .allReferences:
                if pushAllGraphReferences(repo: repo, walker: walker) == 0,
                   git_revwalk_push_head(walker) != 0 {
                    return 0
                }
            }

            var count = 0
            var oid = git_oid()
            while git_revwalk_next(&oid, walker) == 0 {
                try checkCancellation(cancellation)
                count += 1
            }
            return count
        }
    }

    /// 当前 HEAD 可达历史中最早 root commit 的作者日期。
    public static func getFirstCommitDate(
        at path: String,
        cancellation: GitCancellationToken? = nil
    ) throws -> Date? {
        try LibGit2.serialized(at: path) {
            let commits = try getCommitList(at: path, limit: Int.max, skip: 0)
            try checkCancellation(cancellation)
            return commits
                .filter { $0.parentHashes.isEmpty }
                .map(\.date)
                .min()
        }
    }

    /// 获取用于提交拓扑图的提交列表。
    ///
    /// 返回结果按拓扑优先、时间倒序遍历，并包含本地分支、远程分支和标签引用。
    /// GitOK 可基于 `parentHashes` 和 `refs` 在 UI 层计算 lane 与绘制连线。
    public static func getCommitGraphList(at path: String, limit: Int = Int.max, skip: Int = 0) throws -> [GitCommit] {
        return try LibGit2.serialized(at: path) {
            try getCommitList(at: path, scope: .allReferences, limit: limit, skip: skip)
        }
    }

    /// 分页获取用于提交拓扑图的提交列表。
    public static func getCommitGraphListWithPagination(at path: String, page: Int, size: Int) throws -> [GitCommit] {
        return try LibGit2.serialized(at: path) {
            try getCommitGraphList(at: path, limit: size, skip: page * size)
        }
    }

    /// 获取提交列表
    /// - Parameters:
    ///   - path: 仓库路径
    ///   - scope: 遍历范围
    ///   - limit: 最大返回数量
    ///   - skip: 跳过的提交数量
    /// - Returns: 提交列表
    public static func getCommitList(at path: String, scope: CommitTraversalScope, limit: Int = Int.max, skip: Int = 0) throws -> [GitCommit] {
        return try LibGit2.serialized(at: path) {
            let repo = try openRepository(at: path)
            defer { git_repository_free(repo) }

            var revwalk: OpaquePointer? = nil
            defer { if revwalk != nil { git_revwalk_free(revwalk) } }

            let result = git_revwalk_new(&revwalk, repo)

            guard result == 0, let walker = revwalk else {
                throw LibGit2Error.cannotCreateRevwalk
            }

            git_revwalk_sorting(walker, GIT_SORT_TOPOLOGICAL.rawValue | GIT_SORT_TIME.rawValue)

            let refIndex = buildCommitReferenceIndex(repo: repo)

            switch scope {
            case .head:
                let pushResult = git_revwalk_push_head(walker)
                if pushResult != 0 {
                    return []
                }
            case .allReferences:
                let pushed = pushAllGraphReferences(repo: repo, walker: walker)
                if pushed == 0 {
                    let pushResult = git_revwalk_push_head(walker)
                    if pushResult != 0 {
                        return []
                    }
                }
            }

            var commits: [GitCommit] = []
            var oid = git_oid()
            var count = 0
            var skipped = 0

            // 跳过指定数量的提交
            while skipped < skip && git_revwalk_next(&oid, walker) == 0 {
                skipped += 1
            }

            // 遍历提交
            while git_revwalk_next(&oid, walker) == 0 && count < limit {
                var commit: OpaquePointer? = nil
                defer { if commit != nil { git_commit_free(commit) } }

                let lookupResult = git_commit_lookup(&commit, repo, &oid)

                if lookupResult == 0, let commitPtr = commit {
                    if let gitCommit = parseCommit(commitPtr, repo: repo, refsByCommitHash: refIndex) {
                        commits.append(gitCommit)
                        count += 1
                    }
                }
            }

            return commits
        }
    }

    /// 分页获取提交列表
    /// - Parameters:
    ///   - path: 仓库路径
    ///   - page: 页码（从 0 开始）
    ///   - size: 每页大小
    /// - Returns: 提交列表
    public static func getCommitListWithPagination(at path: String, page: Int, size: Int) throws -> [GitCommit] {
        return try LibGit2.serialized(at: path) {
            return try getCommitList(at: path, limit: size, skip: page * size)
        }
    }

    /// 获取指定分支的提交列表
    /// - Parameters:
    ///   - path: 仓库路径
    ///   - branch: 分支名称
    ///   - limit: 最大返回数量
    /// - Returns: 提交列表
    public static func getCommitList(on branch: String, at path: String, limit: Int = Int.max) throws -> [GitCommit] {
        return try LibGit2.serialized(at: path) {
            let repo = try openRepository(at: path)
            defer { git_repository_free(repo) }

            var revwalk: OpaquePointer? = nil
            defer { if revwalk != nil { git_revwalk_free(revwalk) } }

            let result = git_revwalk_new(&revwalk, repo)

            guard result == 0, let walker = revwalk else {
                throw LibGit2Error.cannotCreateRevwalk
            }

            git_revwalk_sorting(walker, GIT_SORT_TOPOLOGICAL.rawValue | GIT_SORT_TIME.rawValue)
            let refIndex = buildCommitReferenceIndex(repo: repo)

            // 推送分支引用
            let branchRef = "refs/heads/\(branch)"
            var oid = git_oid()

            if git_reference_name_to_id(&oid, repo, branchRef) != 0 {
                throw LibGit2Error.invalidReference
            }

            git_revwalk_push(walker, &oid)

            var commits: [GitCommit] = []
            var commitOid = git_oid()
            var count = 0

            while git_revwalk_next(&commitOid, walker) == 0 && count < limit {
                var commit: OpaquePointer? = nil
                defer { if commit != nil { git_commit_free(commit) } }

                if git_commit_lookup(&commit, repo, &commitOid) == 0, let commitPtr = commit {
                    if let gitCommit = parseCommit(commitPtr, repo: repo, refsByCommitHash: refIndex) {
                        commits.append(gitCommit)
                        count += 1
                    }
                }
            }

            return commits
        }
    }

    /// 获取未推送的提交列表
    /// - Parameters:
    ///   - path: 仓库路径
    ///   - remote: 远程仓库名称
    ///   - branch: 分支名称
    /// - Returns: 未推送的提交列表
    static func getUnpushedCommitList(at path: String, remote: String, branch: String) throws -> [GitCommit] {
        let repo = try openRepository(at: path)
        defer { git_repository_free(repo) }

        var revwalk: OpaquePointer? = nil
        defer { if revwalk != nil { git_revwalk_free(revwalk) } }

        let result = git_revwalk_new(&revwalk, repo)

        guard result == 0, let walker = revwalk else {
            throw LibGit2Error.cannotCreateRevwalk
        }

        git_revwalk_sorting(walker, GIT_SORT_TOPOLOGICAL.rawValue | GIT_SORT_TIME.rawValue)
        let refIndex = buildCommitReferenceIndex(repo: repo)

        // 获取本地分支
        let localBranchRef = "refs/heads/\(branch)"
        var localOid = git_oid()

        if git_reference_name_to_id(&localOid, repo, localBranchRef) != 0 {
            throw LibGit2Error.invalidReference
        }

        // 获取远程分支
        let remoteBranchRef = "refs/remotes/\(remote)/\(branch)"
        var remoteOid = git_oid()

        var hasRemote = false
        if git_reference_name_to_id(&remoteOid, repo, remoteBranchRef) == 0 {
            hasRemote = true
        }

        // 推送本地分支，隐藏远程分支之前的提交
        git_revwalk_push(walker, &localOid)

        if hasRemote {
            git_revwalk_hide(walker, &remoteOid)
        }

        var commits: [GitCommit] = []
        var commitOid = git_oid()

        while git_revwalk_next(&commitOid, walker) == 0 {
            var commit: OpaquePointer? = nil
            defer { if commit != nil { git_commit_free(commit) } }

            if git_commit_lookup(&commit, repo, &commitOid) == 0, let commitPtr = commit {
                if let gitCommit = parseCommit(commitPtr, repo: repo, refsByCommitHash: refIndex) {
                    commits.append(gitCommit)
                }
            }
        }

        return commits
    }

    /// 获取指定提交的详细信息
    /// - Parameters:
    ///   - commitHash: 提交哈希
    ///   - path: 仓库路径
    /// - Returns: 提交详细信息
    public static func getCommitDetail(commitHash: String, at path: String) throws -> GitCommit? {
        return try LibGit2.serialized(at: path) {
            let repo = try openRepository(at: path)
            defer { git_repository_free(repo) }

            var oid = git_oid()
            let result = git_oid_fromstr(&oid, commitHash)

            if result != 0 {
                throw LibGit2Error.invalidValue
            }

            var commit: OpaquePointer? = nil
            defer { if commit != nil { git_commit_free(commit) } }

            if git_commit_lookup(&commit, repo, &oid) == 0, let commitPtr = commit {
                let refIndex = buildCommitReferenceIndex(repo: repo)
                return parseCommit(commitPtr, repo: repo, refsByCommitHash: refIndex)
            }

            return nil
        }
    }

    // MARK: - 私有辅助方法

    /// 解析 commit 指针为 GitCommit 结构体
    private static func parseCommit(
        _ commit: OpaquePointer,
        repo: OpaquePointer,
        refsByCommitHash: [String: [String]]
    ) -> GitCommit? {
        // 获取提交 ID
        let oid = git_commit_id(commit)
        guard let oid else { return nil }
        let hash = oidToString(oid.pointee)

        // 获取作者信息
        let authorPtr = git_commit_author(commit)
        guard let author = authorPtr else { return nil }

        let authorName = String(cString: author.pointee.name)
        let authorEmail = String(cString: author.pointee.email)

        // 获取提交时间
        let time = author.pointee.when.time
        let date = Date(timeIntervalSince1970: TimeInterval(time))

        // 获取提交信息
        let messagePtr = git_commit_message(commit)
        let message = messagePtr != nil ? String(cString: messagePtr!) : ""
        let bodyPtr = git_commit_body(commit)
        let body = bodyPtr != nil ? String(cString: bodyPtr!) : ""
        let shortMessage = message.components(separatedBy: "\n").first ?? message

        let refs = refsByCommitHash[hash] ?? []

        // 获取标签
        var tags: [String] = []
        for ref in refs {
            if ref.hasPrefix("refs/tags/") {
                let tagName = ref.replacingOccurrences(of: "refs/tags/", with: "")
                tags.append(tagName)
            }
        }

        // 获取父提交哈希列表
        let parentCount = git_commit_parentcount(commit)
        var parentHashes: [String] = []
        for i in 0..<parentCount {
            if let parentOid = git_commit_parent_id(commit, i) {
                parentHashes.append(oidToString(parentOid.pointee))
            }
        }

        return GitCommit(
            id: hash,
            hash: hash,
            author: authorName,
            email: authorEmail,
            date: date,
            message: shortMessage,
            body: body,
            refs: refs,
            tags: tags,
            parentHashes: parentHashes
        )
    }

    /// 获取提交的父提交数量
    private static func getParentCount(_ commit: OpaquePointer) -> Int {
        return Int(git_commit_parentcount(commit))
    }

    private static func buildCommitReferenceIndex(repo: OpaquePointer) -> [String: [String]] {
        var referencesByCommitHash: [String: [String]] = [:]
        var referenceIterator: UnsafeMutablePointer<git_reference_iterator>?
        defer {
            if let iterator = referenceIterator {
                git_reference_iterator_free(iterator)
            }
        }

        guard git_reference_iterator_new(&referenceIterator, repo) == 0, let iterator = referenceIterator else {
            return referencesByCommitHash
        }

        var reference: OpaquePointer?
        while git_reference_next(&reference, iterator) == 0, let ref = reference {
            defer { git_reference_free(ref) }

            guard let namePointer = git_reference_name(ref) else { continue }
            let refName = String(cString: namePointer)
            guard isGraphReferenceName(refName) else { continue }
            guard let commitHash = commitHashPointedToByReference(ref, repo: repo) else { continue }

            referencesByCommitHash[commitHash, default: []].append(refName)
        }

        for hash in referencesByCommitHash.keys {
            referencesByCommitHash[hash]?.sort()
        }

        return referencesByCommitHash
    }

    @discardableResult
    private static func pushAllGraphReferences(repo: OpaquePointer, walker: OpaquePointer) -> Int {
        var pushed = 0
        var referenceIterator: UnsafeMutablePointer<git_reference_iterator>?
        defer {
            if let iterator = referenceIterator {
                git_reference_iterator_free(iterator)
            }
        }

        guard git_reference_iterator_new(&referenceIterator, repo) == 0, let iterator = referenceIterator else {
            return pushed
        }

        var reference: OpaquePointer?
        while git_reference_next(&reference, iterator) == 0, let ref = reference {
            defer { git_reference_free(ref) }

            guard let namePointer = git_reference_name(ref) else { continue }
            let refName = String(cString: namePointer)
            guard isGraphReferenceName(refName) else { continue }
            guard var oid = commitOIDPointedToByReference(ref, repo: repo) else { continue }

            if git_revwalk_push(walker, &oid) == 0 {
                pushed += 1
            }
        }

        return pushed
    }

    private static func isGraphReferenceName(_ refName: String) -> Bool {
        refName.hasPrefix("refs/heads/")
            || refName.hasPrefix("refs/remotes/")
            || refName.hasPrefix("refs/tags/")
    }

    private static func commitHashPointedToByReference(_ reference: OpaquePointer, repo: OpaquePointer) -> String? {
        guard let oid = commitOIDPointedToByReference(reference, repo: repo) else {
            return nil
        }

        return oidToString(oid)
    }

    private static func commitOIDPointedToByReference(_ reference: OpaquePointer, repo: OpaquePointer) -> git_oid? {
        if git_reference_type(reference) == GIT_REFERENCE_DIRECT,
           let targetOid = git_reference_target(reference) {
            var commit: OpaquePointer?
            defer { if commit != nil { git_commit_free(commit) } }

            if git_commit_lookup(&commit, repo, targetOid) == 0 {
                return targetOid.pointee
            }
        }

        var peeledObject: OpaquePointer?
        defer { if peeledObject != nil { git_object_free(peeledObject) } }

        guard git_reference_peel(&peeledObject, reference, GIT_OBJECT_COMMIT) == 0,
              let object = peeledObject,
              let objectID = git_object_id(object) else {
            return nil
        }

        return objectID.pointee
    }
}
