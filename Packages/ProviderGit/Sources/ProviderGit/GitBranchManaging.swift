import Foundation

// MARK: - Git 分支模型

/// 一个 Git 分支的快照。
///
/// 契约层只保留 UI 与切换决策真正需要的字段：分支名、是否为当前分支、
/// 是否为远程分支、上游分支名。提交哈希等细节留在实现侧。
public struct GitBranchInfo: Codable, Sendable, Equatable, Identifiable {
    public let name: String
    /// 是否为当前 HEAD 所在分支。
    public let isCurrent: Bool
    /// 是否为远程分支。
    public let isRemote: Bool
    /// 对应的上游分支名（如 `origin/main`），无上游时为 `nil`。
    public let upstream: String?

    public var id: String { name }

    public init(name: String, isCurrent: Bool, isRemote: Bool = false, upstream: String? = nil) {
        self.name = name
        self.isCurrent = isCurrent
        self.isRemote = isRemote
        self.upstream = upstream
    }
}

// MARK: - Git 分支读写契约

/// Git 分支的读写能力契约。
///
/// 与 ``GitRepositoryReading`` 一样，本契约由 `PluginGit` 在 `onBoot` 通过
/// `registerProvider((any GitBranchManaging).self, ...)` 发布；消费插件
/// （如标题栏分支胶囊）只依赖本包，不反向依赖 `PluginGit`。
///
/// 写操作（checkout / create）会真实改变仓库状态，因此调用方需要在
/// 界面上给出明确反馈。
public protocol GitBranchManaging: Sendable {
    /// 路径是否位于一个 Git 仓库内。
    ///
    /// 用于「非 Git 项目不显示分支 UI」这类判定，应始终返回 `false`
    /// 而不抛错。
    func isRepository(atPath path: String) async -> Bool

    /// 当前分支名；处于 detached HEAD 时返回 `nil`。
    func currentBranch(atPath path: String) async throws -> String?

    /// 列出本地分支（可选包含远程分支）。
    ///
    /// - Parameter includeRemote: 是否一并返回远程分支。
    func listBranches(atPath path: String, includeRemote: Bool) async throws -> [GitBranchInfo]

    /// 切换到指定本地分支。
    func checkout(branch: String, atPath path: String) async throws

    /// 创建新分支并切换过去。
    func createBranch(named name: String, atPath path: String) async throws
}

// MARK: - 错误

/// 分支契约层的错误。
public enum GitBranchError: LocalizedError, Equatable {
    case notARepository(path: String)
    case invalidBranchName(String)
    case checkoutFailed(String)
    case createFailed(String)

    public var errorDescription: String? {
        switch self {
        case .notARepository(let path):
            "Not a Git repository: \(path)"
        case .invalidBranchName(let message):
            message
        case .checkoutFailed(let message):
            "Failed to switch branch: \(message)"
        case .createFailed(let message):
            "Failed to create branch: \(message)"
        }
    }
}

// MARK: - 内存实现

/// 测试、预览与无真实 Git 实现时使用的内存替身。
///
/// 与 ``InMemoryGitRepositoryReading`` 同一定位：让消费者可在不依赖
/// `PluginGit` 的情况下完成装配与测试。
public final class InMemoryGitBranchManaging: GitBranchManaging, @unchecked Sendable {
    private final class Storage: @unchecked Sendable {
        var repositories: Set<String>
        var currentBranch: [String: String]
        var branches: [String: [GitBranchInfo]]
        var checkoutFailures: [String: String]
        var createFailures: [String: String]

        init(
            repositories: Set<String>,
            currentBranch: [String: String],
            branches: [String: [GitBranchInfo]],
            checkoutFailures: [String: String] = [:],
            createFailures: [String: String] = [:]
        ) {
            self.repositories = repositories
            self.currentBranch = currentBranch
            self.branches = branches
            self.checkoutFailures = checkoutFailures
            self.createFailures = createFailures
        }
    }

    private let queue = DispatchQueue(label: "com.coffic.lumi.provider-git.in-memory.branch")
    private let storage: Storage

    public init(
        repositories: Set<String> = [],
        currentBranch: [String: String] = [:],
        branches: [String: [GitBranchInfo]] = [:],
        checkoutFailures: [String: String] = [:],
        createFailures: [String: String] = [:]
    ) {
        storage = Storage(
            repositories: repositories,
            currentBranch: currentBranch,
            branches: branches,
            checkoutFailures: checkoutFailures,
            createFailures: createFailures
        )
    }

    /// 把某个路径标记为 Git 仓库。
    public func addRepository(atPath path: String) {
        _ = queue.sync { storage.repositories.insert(path) }
    }

    /// 覆盖某个路径的分支列表。
    public func setBranches(_ branches: [GitBranchInfo], forPath path: String) {
        queue.sync { storage.branches[path] = branches }
    }

    /// 设置某个路径的当前分支。
    public func setCurrentBranch(_ branch: String?, forPath path: String) {
        queue.sync { storage.currentBranch[path] = branch }
    }

    public func isRepository(atPath path: String) async -> Bool {
        queue.sync { storage.repositories.contains(path) }
    }

    public func currentBranch(atPath path: String) async throws -> String? {
        try requireRepository(path)
        return queue.sync { storage.currentBranch[path] }
    }

    public func listBranches(atPath path: String, includeRemote: Bool) async throws -> [GitBranchInfo] {
        try requireRepository(path)
        return queue.sync {
            let all = storage.branches[path] ?? []
            guard includeRemote else { return all.filter { !$0.isRemote } }
            return all
        }
    }

    public func checkout(branch: String, atPath path: String) async throws {
        try requireRepository(path)
        let failure = queue.sync { storage.checkoutFailures[branch] }
        if let failure {
            throw GitBranchError.checkoutFailed(failure)
        }
        queue.sync {
            storage.currentBranch[path] = branch
            storage.branches[path] = (storage.branches[path] ?? []).map { info in
                GitBranchInfo(
                    name: info.name,
                    isCurrent: info.name == branch,
                    isRemote: info.isRemote,
                    upstream: info.upstream
                )
            }
        }
    }

    public func createBranch(named name: String, atPath path: String) async throws {
        try requireRepository(path)
        let failure = queue.sync { storage.createFailures[name] }
        if let failure {
            throw GitBranchError.createFailed(failure)
        }
        queue.sync {
            let existing = storage.branches[path] ?? []
            if !existing.contains(where: { $0.name == name && !$0.isRemote }) {
                storage.branches[path] = existing + [
                    GitBranchInfo(name: name, isCurrent: true, isRemote: false, upstream: nil)
                ]
            }
            storage.currentBranch[path] = name
        }
    }

    private func requireRepository(_ path: String) throws {
        guard queue.sync(execute: { storage.repositories.contains(path) }) else {
            throw GitBranchError.notARepository(path: path)
        }
    }
}
