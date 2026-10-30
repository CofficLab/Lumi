import Foundation
import ProviderGit
import ProviderGitRepositoryWatch

/// 标题栏分支胶囊需要的最小 Git 能力。
///
/// 收窄自 ``GitBranchManaging``，让 ViewModel 不必依赖完整契约；
/// 实现由 ``GitBranchCapabilityAdapter`` 提供。
@MainActor
protocol GitBranchCapability: AnyObject, Sendable {
    /// 路径是否位于 Git 仓库内。
    func isRepository(atPath path: String) async -> Bool

    /// 当前分支名；detached HEAD 时为 `nil`。
    func currentBranch(atPath path: String) async throws -> String?

    /// 列出本地分支（可选包含远程分支）。
    func listBranches(atPath path: String, includeRemote: Bool) async throws -> [GitBranchInfo]

    /// 切换到指定分支。
    func checkout(branch: String, atPath path: String) async throws

    /// 创建新分支并切换过去。
    func createBranch(named name: String, atPath path: String) async throws

    /// 订阅仓库 HEAD / refs 变化事件。
    ///
    /// 返回 `nil` 表示当前环境没有启用仓库监听（例如未安装
    /// `PluginGitRepositoryWatch`），此时胶囊仍可正常工作，只是不会跟随
    /// 外部工具的分支切换刷新。
    @discardableResult
    func addRepositoryObserver(
        _ callback: @escaping (GitRepositoryWatchingEvent) -> Void
    ) -> (any GitRepositoryWatchingObserverHandle)?
}

/// 将内核的 `GitBranchManaging` 收窄为插件能力。
@MainActor
final class GitBranchCapabilityAdapter: GitBranchCapability, @unchecked Sendable {
    /// 契约没有 `AnyObject` 约束，无法弱引用；此处用强引用持有。
    ///
    /// 适配器由插件入口持有，且契约实现由内核注册表持有，二者不构成循环引用。
    private let provider: (any GitBranchManaging)?

    /// 仓库监听能力；未注册 `GitRepositoryWatching` 时为 `nil`。
    private let watch: (any GitRepositoryWatching)?

    init(provider: any GitBranchManaging, watch: (any GitRepositoryWatching)? = nil) {
        self.provider = provider
        self.watch = watch
    }

    func isRepository(atPath path: String) async -> Bool {
        await provider?.isRepository(atPath: path) ?? false
    }

    func currentBranch(atPath path: String) async throws -> String? {
        guard let provider else { throw GitBranchError.notARepository(path: path) }
        return try await provider.currentBranch(atPath: path)
    }

    func listBranches(atPath path: String, includeRemote: Bool) async throws -> [GitBranchInfo] {
        guard let provider else { throw GitBranchError.notARepository(path: path) }
        return try await provider.listBranches(atPath: path, includeRemote: includeRemote)
    }

    func checkout(branch: String, atPath path: String) async throws {
        guard let provider else { throw GitBranchError.notARepository(path: path) }
        try await provider.checkout(branch: branch, atPath: path)
    }

    func createBranch(named name: String, atPath path: String) async throws {
        guard let provider else { throw GitBranchError.notARepository(path: path) }
        try await provider.createBranch(named: name, atPath: path)
    }

    @discardableResult
    func addRepositoryObserver(
        _ callback: @escaping (GitRepositoryWatchingEvent) -> Void
    ) -> (any GitRepositoryWatchingObserverHandle)? {
        watch?.addObserver(callback)
    }
}
