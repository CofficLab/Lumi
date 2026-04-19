import Foundation
import Markdown

/// Markdown 文档解析器
/// 基于 Apple swift-markdown 框架，将 Markdown 文本解析为 [MarkdownBlock] 数组。
/// 支持标题、段落、列表（含任务列表）、代码块、引用、表格、分隔线。
/// 代码块支持通过 language 字段识别 Mermaid 等图表语言。
public enum MarkdownParser {

    /// 将 Markdown 文本解析为块级元素数组
    public static func parse(_ content: String) -> [MarkdownBlock] {
        let document = Document(parsing: content)
        var blocks: [MarkdownBlock] = []
        for child in document.children {
            appendBlock(from: child, into: &blocks)
        }
        return blocks
    }

    /// 判断代码块是否为 Mermaid 图表
    public static func isMermaidCodeBlock(language: String?) -> Bool {
        guard let language else { return false }
        return language.lowercased() == "mermaid"
    }

    // MARK: - Internal

    private static func appendBlock(from markup: Markup, into blocks: inout [MarkdownBlock]) {
        switch markup {
        case let heading as Heading:
            let text = heading.plainText.trimmingCharacters(in: .whitespacesAndNewlines)
            if !text.isEmpty {
                blocks.append(.heading(level: heading.level, text: text))
            }
        case let paragraph as Paragraph:
            let text = paragraph.format().trimmingCharacters(in: .whitespacesAndNewlines)
            if !text.isEmpty {
                blocks.append(.paragraph(text: text))
            }
        case let unordered as UnorderedList:
            let items = Array(unordered.listItems).compactMap { parseListItem($0) }
            if !items.isEmpty {
                blocks.append(.unorderedList(items: items))
            }
        case let ordered as OrderedList:
            let start = Int(ordered.startIndex)
            let values: [MarkdownOrderedItem] = Array(ordered.listItems).enumerated().compactMap { offset, item in
                guard let parsed = parseListItem(item) else { return nil }
                return MarkdownOrderedItem(index: start + offset, text: parsed.text)
            }
            if !values.isEmpty {
                blocks.append(.orderedList(items: values))
            }
        case let code as CodeBlock:
            blocks.append(.codeBlock(language: code.language, code: code.code))
        case let quote as BlockQuote:
            let text = quote.children.map { $0.format() }.joined(separator: "\n")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if !text.isEmpty {
                blocks.append(.quote(text: text))
            }
        case _ as ThematicBreak:
            blocks.append(.thematicBreak)
        default:
            let fallback = markup.format().trimmingCharacters(in: .whitespacesAndNewlines)
            if let table = parseTableBlock(from: fallback) {
                blocks.append(table)
            } else if !fallback.isEmpty {
                blocks.append(.paragraph(text: fallback))
            }
        }
    }

    private static func parseListItem(_ item: ListItem) -> MarkdownListItem? {
        let text = item.children.map { $0.format() }.joined(separator: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return nil }
        let stripped = stripListPrefix(text)
        if let task = parseTaskState(stripped) {
            return MarkdownListItem(text: task.text, taskState: task.state)
        }
        return MarkdownListItem(text: stripped)
    }

    private static func stripListPrefix(_ text: String) -> String {
        if let range = text.range(of: #"^(\d+)\.\s+"#, options: .regularExpression) {
            return String(text[range.upperBound...]).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        if let range = text.range(of: #"^[-*+]\s+"#, options: .regularExpression) {
            return String(text[range.upperBound...]).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return text
    }

    private static func parseTaskState(_ text: String) -> (state: MarkdownTaskState, text: String)? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if let range = trimmed.range(of: #"^\[( |x|X)\]\s+"#, options: .regularExpression) {
            let marker = trimmed[trimmed.index(after: trimmed.startIndex)]
            let rest = String(trimmed[range.upperBound...]).trimmingCharacters(in: .whitespacesAndNewlines)
            return (marker == "x" || marker == "X" ? .done : .todo, rest)
        }
        return nil
    }

    private static func parseTableBlock(from text: String) -> MarkdownBlock? {
        let lines = text
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }

        guard lines.count >= 2 else { return nil }
        let headers = parseTableRow(lines[0])
        guard headers.count >= 2 else { return nil }
        let separator = parseTableRow(lines[1])
        guard separator.count == headers.count else { return nil }
        guard separator.allSatisfy({ $0.range(of: #"^:?-{3,}:?$"#, options: .regularExpression) != nil }) else { return nil }

        var rows: [[String]] = []
        for raw in lines.dropFirst(2) {
            var row = parseTableRow(raw)
            if row.isEmpty { continue }
            if row.count < headers.count {
                row.append(contentsOf: Array(repeating: "", count: headers.count - row.count))
            } else if row.count > headers.count {
                row = Array(row.prefix(headers.count))
            }
            rows.append(row)
        }
        return .table(headers: headers, rows: rows)
    }

    private static func parseTableRow(_ line: String) -> [String] {
        let normalized = line
            .trimmingCharacters(in: .whitespaces)
            .trimmingCharacters(in: CharacterSet(charactersIn: "|"))
        guard !normalized.isEmpty else { return [] }
        return normalized
            .split(separator: "|", omittingEmptySubsequences: false)
            .map { $0.trimmingCharacters(in: .whitespaces) }
    }
}
