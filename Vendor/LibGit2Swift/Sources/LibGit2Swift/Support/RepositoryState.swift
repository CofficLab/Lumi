import Clibgit2
import Foundation

/// 仓库操作状态。
///
/// 取代"探测 `.git/MERGE_HEAD` / `.git/CHERRY_PICK_HEAD` 文件是否存在"的做法。
/// 手写文件探测有两个问题：
///
/// 1. **worktree / submodule 下 `.git` 是文件**（内容为 `gitdir: ...`），
///    拼 `.git/MERGE_HEAD` 路径会失败。
/// 2. 无法区分 merge / cherry-pick / revert / rebase / bisect，UI 只能猜测。
///
/// `git_repository_state()` 是 libgit2 提供的权威判定，本类型是其 Swift 映射。
public enum LibGit2RepositoryState: String, Sendable, CaseIterable {
    /// 没有进行中的多步操作。
    case none
    /// `git merge` 中途（可能存在冲突，也可能仅等待提交）。
    case merge
    /// `git revert` 中途。
    case revert
    /// 连续 revert 序列。
    case revertSequence
    /// `git cherry-pick` 中途。
    case cherryPick
    /// 连续 cherry-pick 序列。
    case cherryPickSequence
    /// `git bisect` 进行中。
    case bisect
    /// `git rebase`（非交互式）中途。
    case rebase
    /// 交互式 rebase 中途。
    case rebaseInteractive
    /// `git rebase --merge` 中途。
    case rebaseMerge
    /// `git am` 中途。
    case applyMailbox
    /// `git am` 或 rebase 中途（libgit2 无法进一步区分）。
    case applyMailboxOrRebase

    /// 是否存在进行中的多步操作。
    public var isOperationInProgress: Bool {
        self != .none
    }

    /// 是否属于 rebase 家族（任一 rebase 变体）。
    public var isRebase: Bool {
        switch self {
        case .rebase, .rebaseInteractive, .rebaseMerge, .applyMailboxOrRebase:
            return true
        default:
            return false
        }
    }

    /// 是否属于 cherry-pick 家族。
    public var isCherryPick: Bool {
        self == .cherryPick || self == .cherryPickSequence
    }

    /// 是否属于 revert 家族。
    public var isRevert: Bool {
        self == .revert || self == .revertSequence
    }

    /// 是否属于 merge。
    public var isMerge: Bool {
        self == .merge
    }

    /// 操作进行中时用户可读的描述；无操作时返回 `nil`。
    public var userFacingDescription: String? {
        switch self {
        case .none: return nil
        case .merge: return "Merge in progress"
        case .revert: return "Revert in progress"
        case .revertSequence: return "Sequence of reverts in progress"
        case .cherryPick: return "Cherry-pick in progress"
        case .cherryPickSequence: return "Sequence of cherry-picks in progress"
        case .bisect: return "Bisect in progress"
        case .rebase: return "Rebase in progress"
        case .rebaseInteractive: return "Interactive rebase in progress"
        case .rebaseMerge: return "Merge rebase in progress"
        case .applyMailbox: return "Applying mailbox in progress"
        case .applyMailboxOrRebase: return "Apply mailbox or rebase in progress"
        }
    }

    /// 由 libgit2 C 层返回的状态原始值构造。
    ///
    /// `git_repository_state()` 返回 C 的匿名枚举（导入 Swift 后为 `Int32`），
    /// 而 `GIT_REPOSITORY_STATE_*` 常量为 `UInt32`，故统一以 `UInt32` 比较。
    init(rawValue: UInt32) {
        switch rawValue {
        case GIT_REPOSITORY_STATE_MERGE.rawValue: self = .merge
        case GIT_REPOSITORY_STATE_REVERT.rawValue: self = .revert
        case GIT_REPOSITORY_STATE_REVERT_SEQUENCE.rawValue: self = .revertSequence
        case GIT_REPOSITORY_STATE_CHERRYPICK.rawValue: self = .cherryPick
        case GIT_REPOSITORY_STATE_CHERRYPICK_SEQUENCE.rawValue: self = .cherryPickSequence
        case GIT_REPOSITORY_STATE_BISECT.rawValue: self = .bisect
        case GIT_REPOSITORY_STATE_REBASE.rawValue: self = .rebase
        case GIT_REPOSITORY_STATE_REBASE_INTERACTIVE.rawValue: self = .rebaseInteractive
        case GIT_REPOSITORY_STATE_REBASE_MERGE.rawValue: self = .rebaseMerge
        case GIT_REPOSITORY_STATE_APPLY_MAILBOX.rawValue: self = .applyMailbox
        case GIT_REPOSITORY_STATE_APPLY_MAILBOX_OR_REBASE.rawValue: self = .applyMailboxOrRebase
        default: self = .none
        }
    }
}

extension LibGit2 {
    /// 当前仓库的操作状态。
    ///
    /// - Parameter path: 仓库路径
    /// - Returns: 进行中的操作类型；无操作时为 `.none`
    public static func repositoryState(at path: String) throws -> LibGit2RepositoryState {
        try LibGit2.serialized(at: path) {
            let repo = try openRepositoryUnlocked(at: path)
            defer { git_repository_free(repo) }
            return LibGit2RepositoryState(rawValue: UInt32(bitPattern: git_repository_state(repo)))
        }
    }

    /// 是否存在进行中的多步操作（merge / rebase / cherry-pick / revert / bisect）。
    public static func hasOperationInProgress(at path: String) throws -> Bool {
        try repositoryState(at: path).isOperationInProgress
    }
}
