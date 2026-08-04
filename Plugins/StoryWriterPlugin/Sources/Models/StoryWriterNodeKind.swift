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

    public var displayName: String {
        switch self {
        case .draft: return "Draft"
        case .inProgress: return "In Progress"
        case .done: return "Done"
        }
    }
}
