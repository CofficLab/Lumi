import Foundation

// MARK: - Block Types

/// Markdown 文档解析后的块级元素
public enum MarkdownBlock: Equatable {
    case heading(level: Int, text: String)
    case paragraph(text: String)
    case unorderedList(items: [MarkdownListItem])
    case orderedList(items: [MarkdownOrderedItem])
    case codeBlock(language: String?, code: String)
    case quote(text: String)
    case table(headers: [String], rows: [[String]])
    case thematicBreak
}

// MARK: - List Item

/// 无序列表项
public struct MarkdownListItem: Identifiable, Equatable {
    public let id = UUID()
    public let text: String
    public let taskState: MarkdownTaskState?

    public init(text: String, taskState: MarkdownTaskState? = nil) {
        self.text = text
        self.taskState = taskState
    }

    public static func == (lhs: MarkdownListItem, rhs: MarkdownListItem) -> Bool {
        lhs.text == rhs.text && lhs.taskState == rhs.taskState
    }
}

/// 有序列表项
public struct MarkdownOrderedItem: Identifiable, Equatable {
    public let id = UUID()
    public let index: Int
    public let text: String

    public init(index: Int, text: String) {
        self.index = index
        self.text = text
    }

    public static func == (lhs: MarkdownOrderedItem, rhs: MarkdownOrderedItem) -> Bool {
        lhs.index == rhs.index && lhs.text == rhs.text
    }
}

// MARK: - Task State

/// 任务列表状态
public enum MarkdownTaskState: Equatable {
    case todo
    case done

    public var isCompleted: Bool { self == .done }
}
