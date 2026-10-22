import Foundation
import ProviderGit

/// Chat Toolbar 的 Git 窄能力协议。
///
/// 遵循「插件 Capabilities 能力边界规范」：ViewModel/View 只面向本协议，
/// 不直接持有 `any GitRepositoryReading`。插件入口在 `onBoot` 创建
/// `GitChatCapabilityAdapter` 并注入 ViewModel。
///
/// 协议继承 `AnyObject` 以便 ViewModel 以弱引用持有 capability，避免
/// 插件入口与 ViewModel 形成循环引用（与 PluginGitToolbar 的
/// `GitBranchCapability` 同一定位）。
@MainActor
public protocol GitChatCapability: AnyObject, Sendable {
    /// 判断给定路径是否位于 Git 仓库内（不抛错）。
    func isRepository(atPath path: String?) async -> Bool

    /// 读取工作区状态（含 untracked）。
    func status(atPath path: String?) async throws -> GitStatus

    /// 分页读取提交历史。
    func log(atPath path: String?, count: Int, skip: Int) async throws -> [GitCommitLog]

    /// 读取某个 commit 的变更文件列表。
    func commitChanges(atPath path: String?, hash: String) async throws -> [GitCommitChange]
}

/// 将 `GitRepositoryReading` 收窄为 ``GitChatCapability``。
///
/// 适配器由插件入口持有；`GitRepositoryReading` 契约实例由内核服务注册表持有，
/// 二者不构成循环引用。
@MainActor
public final class GitChatCapabilityAdapter: GitChatCapability, @unchecked Sendable {
    private let provider: (any GitRepositoryReading)?

    public init(provider: (any GitRepositoryReading)?) {
        self.provider = provider
    }

    public func isRepository(atPath path: String?) async -> Bool {
        guard let provider else { return false }
        return await provider.isRepository(atPath: path)
    }

    public func status(atPath path: String?) async throws -> GitStatus {
        guard let provider else { throw GitReadError.repositoryNotFound(path: path) }
        return try await provider.status(atPath: path)
    }

    public func log(atPath path: String?, count: Int, skip: Int) async throws -> [GitCommitLog] {
        guard let provider else { throw GitReadError.repositoryNotFound(path: path) }
        return try await provider.log(atPath: path, count: count, skip: skip)
    }

    public func commitChanges(atPath path: String?, hash: String) async throws -> [GitCommitChange] {
        guard let provider else { throw GitReadError.repositoryNotFound(path: path) }
        return try await provider.commitChanges(atPath: path, hash: hash)
    }
}
