import Foundation

// MARK: - Git 工作区变更项

/// 单个文件的变更类型（契约层枚举，供 UI 渲染徽标）。
public enum GitWorkingChangeState: String, Codable, Sendable, Equatable {
    case modified
    case added
    case deleted
    case renamed
    case untracked
}

/// 工作区中单个文件的变更记录。
///
/// 由 ``GitStatus/workingChanges()`` 合成：把 ``GitStatus`` 的 staged / added /
/// deleted / renamed / modified / untracked 数组合并为一个统一的文件列表，
/// 每行带变更类型与是否已暂存标记，便于 UI 直接渲染。
public struct GitWorkingChange: Codable, Sendable, Equatable, Identifiable {
    public var id: String { path }
    public let path: String
    public let state: GitWorkingChangeState
    public let isStaged: Bool

    public init(path: String, state: GitWorkingChangeState, isStaged: Bool) {
        self.path = path
        self.state = state
        self.isStaged = isStaged
    }
}

// MARK: - Git Commit 变更项

/// 单个 commit 中某文件的变更记录。
public struct GitCommitChange: Codable, Sendable, Equatable, Identifiable {
    public var id: String { path }
    public let path: String
    public let state: GitWorkingChangeState

    public init(path: String, state: GitWorkingChangeState) {
        self.path = path
        self.state = state
    }
}

// MARK: - Git 仓库状态

/// 一次仓库状态读取的结果。
public struct GitStatus: Codable, Sendable, Equatable {
    public let branch: String
    public let remote: String?
    public let modified: [String]
    public let added: [String]
    public let deleted: [String]
    public let renamed: [String]
    public let staged: [String]
    /// 已暂存文件的具体变更类型（`path -> state`，相对 HEAD）。
    ///
    /// 旧数据或调用方未提供时为空；此时 ``workingChanges()`` 对仅暂存的文件
    /// 回退为 `.modified`，与历史行为一致。
    public let stagedStates: [String: GitWorkingChangeState]
    /// 未跟踪文件（工作区有、Git 未纳入版本控制）。
    public let untracked: [String]

    public init(
        branch: String,
        remote: String? = nil,
        modified: [String] = [],
        added: [String] = [],
        deleted: [String] = [],
        renamed: [String] = [],
        staged: [String] = [],
        stagedStates: [String: GitWorkingChangeState] = [:],
        untracked: [String] = []
    ) {
        self.branch = branch
        self.remote = remote
        self.modified = modified
        self.added = added
        self.deleted = deleted
        self.renamed = renamed
        self.staged = staged
        self.stagedStates = stagedStates
        self.untracked = untracked
    }

    // 自定义解码以兼容旧 JSON（untracked / stagedStates 缺失时回退为空）。
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        branch = try container.decode(String.self, forKey: .branch)
        remote = try container.decodeIfPresent(String.self, forKey: .remote)
        modified = try container.decodeIfPresent([String].self, forKey: .modified) ?? []
        added = try container.decodeIfPresent([String].self, forKey: .added) ?? []
        deleted = try container.decodeIfPresent([String].self, forKey: .deleted) ?? []
        renamed = try container.decodeIfPresent([String].self, forKey: .renamed) ?? []
        staged = try container.decodeIfPresent([String].self, forKey: .staged) ?? []
        stagedStates = try container.decodeIfPresent([String: GitWorkingChangeState].self, forKey: .stagedStates) ?? [:]
        untracked = try container.decodeIfPresent([String].self, forKey: .untracked) ?? []
    }

    /// 工作区与暂存区的全部变更文件（去重、排序），含未跟踪。
    public var allChangedFiles: [String] {
        Array(Set(modified + added + deleted + renamed + staged + untracked)).sorted()
    }

    /// 把 ``modified/added/deleted/renamed/staged/untracked`` 合成为统一的
    /// ``GitWorkingChange`` 列表。
    ///
    /// 合成规则（staged 优先）：
    /// - staged 中的文件：state 取 `stagedStates[path]`（暂存区相对 HEAD 的类型）；
    ///   旧数据没有该映射时，若同一路径有未暂存记录则沿用其 state，否则回退 `.modified`。
    /// - 非 staged 的 modified/added/deleted/renamed/untracked：state 为对应枚举，
    ///   `isStaged = false`。
    /// - 同一文件在 staged 与非 staged 都出现时，返回 staged 版本（isStaged=true）。
    public func workingChanges() -> [GitWorkingChange] {
        var changes: [String: GitWorkingChange] = [:]

        for p in modified { changes[p] = GitWorkingChange(path: p, state: .modified, isStaged: false) }
        for p in added { changes[p] = GitWorkingChange(path: p, state: .added, isStaged: false) }
        for p in deleted { changes[p] = GitWorkingChange(path: p, state: .deleted, isStaged: false) }
        for p in renamed { changes[p] = GitWorkingChange(path: p, state: .renamed, isStaged: false) }
        for p in untracked { changes[p] = GitWorkingChange(path: p, state: .untracked, isStaged: false) }

        // staged 覆盖：优先使用暂存区相对 HEAD 的具体类型，避免仅暂存的新增/删除/重命名
        // 被统一显示为修改。
        for p in staged {
            let state = stagedStates[p] ?? changes[p]?.state ?? .modified
            changes[p] = GitWorkingChange(path: p, state: state, isStaged: true)
        }

        return changes.values.sorted { $0.path < $1.path }
    }
}

// MARK: - Git 提交

/// 提交历史中的一条记录。
///
/// `date` 保留 libgit2 产出的 ISO-8601 字符串，避免在契约层引入日期解析
/// 依赖；需要 `Date` 的消费者自行解析（见 ``GitDateFormatting``）。
public struct GitCommitLog: Codable, Sendable, Equatable {
    public let hash: String
    public let author: String
    public let email: String
    public let date: String
    public let message: String

    public init(hash: String, author: String, email: String, date: String, message: String) {
        self.hash = hash
        self.author = author
        self.email = email
        self.date = date
        self.message = message
    }
}

// MARK: - 日期解析

/// 把 ``GitCommitLog/date`` 这类 ISO-8601 字符串解析为 `Date`。
///
/// 契约层只声明解析规则，不依赖任何 Git 实现，消费者可安全复用。
public enum GitDateFormatting {
    /// 依次尝试的格式。
    public static let formatHandlers: [DateFormatter] = [
        "yyyy-MM-dd HH:mm:ss Z", "yyyy-MM-dd'T'HH:mm:ssZ", "yyyy-MM-dd'T'HH:mm:ss.SSSZ",
        "yyyy-MM-dd'T'HH:mm:ss", "yyyy-MM-dd HH:mm:ss",
    ].map {
        let formatter = DateFormatter()
        formatter.dateFormat = $0
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        return formatter
    }

    /// 解析 ISO-8601 或 ``formatHandlers`` 中的任一格式；失败返回 `nil`。
    public static func date(from value: String) -> Date? {
        if let date = ISO8601DateFormatter().date(from: value) { return date }
        return formatHandlers.lazy.compactMap { $0.date(from: value) }.first
    }
}
