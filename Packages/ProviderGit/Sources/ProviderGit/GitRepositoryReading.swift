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
}

public extension GitRepositoryReading {
    /// 便捷重载：读取当前 HEAD 的最近提交。
    func recentCommits(atPath path: String?, count: Int) async throws -> [GitCommitLog] {
        try await log(atPath: path, count: count, branch: nil, file: nil)
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

        init(statuses: [String: GitStatus], commits: [String: [GitCommitLog]]) {
            self.statuses = statuses
            self.commits = commits
        }
    }

    private let queue = DispatchQueue(label: "com.coffic.lumi.provider-git.in-memory")
    private let storage: Storage

    public init(
        statuses: [String: GitStatus] = [:],
        commits: [String: [GitCommitLog]] = [:]
    ) {
        storage = Storage(statuses: statuses, commits: commits)
    }

    public func setStatus(_ status: GitStatus, forPath path: String) {
        queue.sync { storage.statuses[path] = status }
    }

    public func setCommits(_ commits: [GitCommitLog], forPath path: String) {
        queue.sync { storage.commits[path] = commits }
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
