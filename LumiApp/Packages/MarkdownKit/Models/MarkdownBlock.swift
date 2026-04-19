import Foundation

// MARK: - Block Types

/// Markdown 文档解析后的块级元素
public enum MarkdownBlock {
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
public struct MarkdownListItem: Identifiable {
    public let id = UUID()
    public let text: String
    public let taskState: MarkdownTaskState?

    public init(text: String, taskState: MarkdownTaskState? = nil) {
        self.text = text
        self.taskState = taskState
    }
}

/// 有序列表项
public struct MarkdownOrderedItem: Identifiable {
    public let id = UUID()
    public let index: Int
    public let text: String

    public init(index: Int, text: String) {
        self.index = index
        self.text = text
    }
}

// MARK: - Task State

/// 任务列表状态
public enum MarkdownTaskState {
    case todo
    case done

    public var isCompleted: Bool { self == .done }
}
