import Foundation

/// Story writer node kinds (used by the outline tree).
public enum StoryWriterNodeKind: String, Codable, Sendable, CaseIterable {
    case story
    case chapter
    case character
}

/// Chapter writing status.
public enum ChapterStatus: String, Codable, Sendable, CaseIterable {
    case draft
    case inProgress
    case done

    /// 对外工具契约使用的令牌（`draft` / `in_progress` / `done`），
    /// 与持久化 `rawValue`（`inProgress`）解耦，保证读写工具可无损往返。
    public var token: String {
        switch self {
        case .draft: return "draft"
        case .inProgress: return "in_progress"
        case .done: return "done"
        }
    }

    /// 接受公开令牌以及历史输出中的 `rawValue`，避免按旧读取结果调用时被拒绝。
    public init?(token: String) {
        switch token {
        case "draft": self = .draft
        case "in_progress", "inProgress": self = .inProgress
        case "done": self = .done
        default: return nil
        }
    }

    public var displayName: String {
        switch self {
        case .draft: return "Draft"
        case .inProgress: return "In Progress"
        case .done: return "Done"
        }
    }
}
