import Foundation

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

    public init(
        branch: String,
        remote: String? = nil,
        modified: [String] = [],
        added: [String] = [],
        deleted: [String] = [],
        renamed: [String] = [],
        staged: [String] = []
    ) {
        self.branch = branch
        self.remote = remote
        self.modified = modified
        self.added = added
        self.deleted = deleted
        self.renamed = renamed
        self.staged = staged
    }

    /// 工作区与暂存区的全部变更文件（去重、排序）。
    public var allChangedFiles: [String] {
        Array(Set(modified + added + deleted + renamed + staged)).sorted()
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
