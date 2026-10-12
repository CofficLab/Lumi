import Foundation

// MARK: - SCM 中立契约（Phase 7 §15.6）
//
// Git 只是一个实现插件：编辑器侧消费者（Diff 基线、gutter、blame、
// Timeline）只面向本契约，通过 kernel.resolveService(SourceControlProviding.self)
// 获取。能力缺失（未注册/非仓库）是正常状态。

/// 单个文件的 SCM 变更状态。
public struct EditorSCMChange: Equatable, Sendable, Identifiable {
    public enum State: String, Equatable, Sendable {
        case modified
        case added
        case deleted
        case renamed
        case untracked
        case conflicted
    }

    public var id: String { uri.path }

    /// 变更文件 URI。
    public let uri: URL

    public let state: State

    /// 是否已暂存（staged）。
    public let isStaged: Bool

    public init(uri: URL, state: State, isStaged: Bool) {
        self.uri = uri
        self.state = state
        self.isStaged = isStaged
    }
}

/// 一个仓库的工作区状态快照。
public struct EditorSCMStatus: Equatable, Sendable {
    /// 仓库根（nil = 非 SCM 仓库）。
    public let repositoryRoot: URL?

    public let changes: [EditorSCMChange]

    public init(repositoryRoot: URL?, changes: [EditorSCMChange]) {
        self.repositoryRoot = repositoryRoot
        self.changes = changes
    }

    public static let none = EditorSCMStatus(repositoryRoot: nil, changes: [])

    public var isRepository: Bool { repositoryRoot != nil }
}

/// 源代码管理能力（首批切片：discovery/status/baseline/stage/commit）。
///
/// branch/tag/stash/push/pull/blame 等在后续切片扩展；
/// 所有方法都必须可在无仓库/无实现时安全调用。
@MainActor
public protocol SourceControlProviding: AnyObject {
    /// URI 所在仓库的根（非仓库返回 nil）。
    func repositoryRoot(for uri: URL) -> URL?

    /// URI 所在仓库的工作区状态（非仓库返回 `.none`）。
    func status(for uri: URL) async -> EditorSCMStatus

    /// 文件的基线（HEAD）内容：工作区 diff 对 SCM 基线时的 old 侧。
    /// 无历史（新文件）或不可得时返回 nil。
    func baselineContent(of uri: URL) async -> String?

    /// 暂存文件。
    func stage(uris: [URL]) async throws

    /// 取消暂存。
    func unstage(uris: [URL]) async throws

    /// 提交到指定仓库（nil = 提交全部已暂存变更；非 nil 时先暂存这些文件）。
    func commit(message: String, in repository: URL, uris: [URL]?) async throws
}
