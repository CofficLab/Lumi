import Foundation

// MARK: - Git 读取契约

/// Git 仓库只读访问能力的 Provider 契约。
///
/// 插件需要 Git 数据时依赖本契约包，而不是反向依赖 `PluginGit`——插件之间
/// 不得互相依赖（见 docs/editor-kernel-plugin-rearchitecture-plan.md §6）。
/// 真实实现由 `PluginGit` 在 `onBoot` 通过
/// `registerProvider((any GitRepositoryReading).self, ...)` 发布。
///
/// 所有方法都是只读的；写操作（commit / stage 等）不属于本契约。
public protocol GitRepositoryReading: Sendable {
    /// 读取仓库状态：分支、远程与变更文件分类。
    ///
    /// - Parameter path: 仓库内或仓库下的任意路径；`nil` 表示使用进程当前目录。
    func status(atPath path: String?) async throws -> GitStatus

    /// 读取最近的提交历史。
    ///
    /// - Parameters:
    ///   - path: 仓库路径。
    ///   - count: 最多返回的提交数。
    ///   - branch: 可选分支名；`nil` 表示当前 HEAD。
    ///   - file: 可选文件路径；仅返回触及该文件的提交。
    func log(atPath path: String?,
             count: Int,
             branch: String?,
             file: String?) async throws -> [GitCommitLog]

    /// 分页读取提交历史，用于逐页加载长历史。
    ///
    /// - Parameters:
    ///   - path: 仓库路径。
    ///   - count: 本页最多返回的提交数。
    ///   - skip: 跳过的提交数。
    func log(atPath path: String?,
             count: Int,
             skip: Int) async throws -> [GitCommitLog]

    /// 判断给定路径是否位于 Git 仓库内。
    ///
    /// 用于「非 Git 项目不显示 Git UI」这类判定，应始终返回 `false`
    /// 而不抛错。
    ///
    /// 默认实现按文件系统向上查找 `.git`，实现方可按自身实现覆盖。
    ///
    /// - Parameter path: 任意路径；`nil` 表示使用进程当前目录。
    func isRepository(atPath path: String?) async -> Bool

    /// 读取某个 commit 的变更文件列表。
    ///
    /// 用于在 commit 列表中选中一条记录后，展示该 commit 修改了哪些文件。
    ///
    /// - Parameters:
    ///   - path: 仓库路径。
    ///   - hash: commit hash（完整或前缀均可，由实现方解析）。
    func commitChanges(atPath path: String?, hash: String) async throws -> [GitCommitChange]

    /// 读取仓库的远程地址（remote URL）。
    ///
    /// 用于「在浏览器中打开项目远程仓库」这类能力：消费方拿到 remote URL 后
    /// 自行转换为 HTTPS web 链接。契约层只负责**读取原始 URL**，不做任何
    /// 协议转换，避免把「Git 事实」与「Web 链接规则」耦合在一起。
    ///
    /// - Parameters:
    ///   - path: 仓库路径。
    ///   - remote: 远程名称，默认 `origin`。
    /// - Returns: 远程地址；仓库不存在、没有该 remote 或读取失败时返回 `nil`。
    ///
    /// - Note: 返回的可能是 scp-like（`git@github.com:user/repo.git`）、
    ///   `ssh://` 或 `https://` 形式，消费方需自行处理。
    func remoteURL(atPath path: String?, remote: String) async -> String?
}

public extension GitRepositoryReading {
    /// 便捷重载：读取当前 HEAD 的最近提交。
    func recentCommits(atPath path: String?, count: Int) async throws -> [GitCommitLog] {
        try await log(atPath: path, count: count, branch: nil, file: nil)
    }

    /// 便捷重载：读取 `origin` 的远程地址。
    func remoteURL(atPath path: String?) async -> String? {
        await remoteURL(atPath: path, remote: "origin")
    }

    /// 默认实现：沿路径向上查找 `.git`，命中即认为是 Git 仓库。
    ///
    /// 真实实现（`PluginGit` 的 `GitService`）会覆盖为 libgit2 判定，
    /// 性能更好且语义一致；本默认实现保证未实现契约的替身也能工作。
    func isRepository(atPath path: String?) async -> Bool {
        var candidate = (path ?? FileManager.default.currentDirectoryPath)
        for _ in 0..<128 {
            let gitURL = URL(fileURLWithPath: candidate).appendingPathComponent(".git")
            if FileManager.default.fileExists(atPath: gitURL.path) { return true }
            let parent = URL(fileURLWithPath: candidate).deletingLastPathComponent().path
            guard parent != candidate else { return false }
            candidate = parent
        }
        return false
    }
}

// MARK: - 内存实现

/// 测试、预览与无真实 Git 实现时使用的内存替身。
///
/// 与 `ProviderGitRepositoryWatch.DefaultGitRepositoryWatching` 同一定位：
/// 让消费者可在不依赖 `PluginGit` 的情况下完成装配与测试。
///
/// 状态放在串行队列保护的可变盒子里：契约方法是 `async`，不能用 `NSLock`
/// 直接跨 await 加锁（Swift 6 禁止）。
public final class InMemoryGitRepositoryReading: GitRepositoryReading, @unchecked Sendable {
    private final class Storage: @unchecked Sendable {
        var statuses: [String: GitStatus]
        var commits: [String: [GitCommitLog]]
        var commitChanges: [String: [String: [GitCommitChange]]]
        var repositories: Set<String>
        /// 远程地址：仓库路径 → (remote 名称 → URL)。
        var remoteURLs: [String: [String: String]]

        init(
            statuses: [String: GitStatus],
            commits: [String: [GitCommitLog]],
            commitChanges: [String: [String: [GitCommitChange]]],
            repositories: Set<String>,
            remoteURLs: [String: [String: String]] = [:]
        ) {
            self.statuses = statuses
            self.commits = commits
            self.commitChanges = commitChanges
            self.repositories = repositories
            self.remoteURLs = remoteURLs
        }
    }

    private let queue = DispatchQueue(label: "com.coffic.lumi.provider-git.in-memory")
    private let storage: Storage

    public init(
        statuses: [String: GitStatus] = [:],
        commits: [String: [GitCommitLog]] = [:],
        commitChanges: [String: [String: [GitCommitChange]]] = [:],
        repositories: Set<String> = [],
        remoteURLs: [String: [String: String]] = [:]
    ) {
        storage = Storage(
            statuses: statuses,
            commits: commits,
            commitChanges: commitChanges,
            repositories: repositories,
            remoteURLs: remoteURLs
        )
    }

    public func setStatus(_ status: GitStatus, forPath path: String) {
        queue.sync { storage.statuses[path] = status }
    }

    public func setCommits(_ commits: [GitCommitLog], forPath path: String) {
        queue.sync { storage.commits[path] = commits }
    }

    /// 设置某个 commit 的变更文件列表（测试用）。
    public func setCommitChanges(_ changes: [GitCommitChange], forPath path: String, hash: String) {
        queue.sync {
            var repo = storage.commitChanges[path] ?? [:]
            repo[hash] = changes
            storage.commitChanges[path] = repo
        }
    }

    /// 把某个路径标记为 Git 仓库（测试用）。
    public func addRepository(atPath path: String) {
        queue.sync { _ = storage.repositories.insert(path) }
    }

    /// 设置某个仓库的远程地址（测试用）。
    public func setRemoteURL(_ url: String, forPath path: String, remote: String = "origin") {
        queue.sync {
            storage.remoteURLs[path, default: [:]][remote] = url
        }
    }

    public func isRepository(atPath path: String?) async -> Bool {
        guard let path else { return false }
        return queue.sync { storage.repositories.contains(path) }
    }

    public func status(atPath path: String?) async throws -> GitStatus {
        guard let path else { throw GitReadError.repositoryNotFound(path: nil) }
        let status = queue.sync { storage.statuses[path] }
        guard let status else { throw GitReadError.repositoryNotFound(path: path) }
        return status
    }

    public func log(atPath path: String?,
                    count: Int,
                    branch: String?,
                    file: String?) async throws -> [GitCommitLog] {
        try await log(atPath: path, count: count, skip: 0)
    }

    public func log(atPath path: String?,
                    count: Int,
                    skip: Int) async throws -> [GitCommitLog] {
        guard let path else { throw GitReadError.repositoryNotFound(path: nil) }
        let all = queue.sync { storage.commits[path] } ?? []
        guard skip < all.count else { return [] }
        return Array(all[skip..<min(skip + count, all.count)])
    }

    public func commitChanges(atPath path: String?, hash: String) async throws -> [GitCommitChange] {
        guard let path else { throw GitReadError.repositoryNotFound(path: nil) }
        let changes = queue.sync { storage.commitChanges[path]?[hash] }
        guard changes != nil else { throw GitReadError.repositoryNotFound(path: path) }
        return changes ?? []
    }

    public func remoteURL(atPath path: String?, remote: String) async -> String? {
        guard let path else { return nil }
        return queue.sync { storage.remoteURLs[path]?[remote] }
    }
}

// MARK: - 错误

/// 契约层的读取错误。实现可抛出自身错误，消费者应同时处理两者。
public enum GitReadError: LocalizedError, Equatable {
    case repositoryNotFound(path: String?)
    case notAGitRepository(path: String)

    public var errorDescription: String? {
        switch self {
        case .repositoryNotFound(let path):
            "No Git repository for path: \(path ?? "<nil>")"
        case .notAGitRepository(let path):
            "Not a Git repository: \(path)"
        }
    }
}
