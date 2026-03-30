import SwiftUI
import MagicKit
import Markdown

/// 原生 Markdown 渲染视图（自研块级解析 + 轻量行内样式）
struct NativeMarkdownContent: View {
    let content: String

    @Environment(\.preferOuterScroll) private var preferOuterScroll
    @State private var blocks: [NativeMarkdownBlock] = []

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(Array(blocks.enumerated()), id: \.offset) { _, block in
                blockView(block)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .task(id: content) {
            blocks = NativeMarkdownParser.parse(content)
        }
    }

    @ViewBuilder
    private func blockView(_ block: NativeMarkdownBlock) -> some View {
        switch block {
        case let .heading(level, text):
            inlineText(text)
                .font(headingFont(level: level))
                .fontWeight(.semibold)
                .padding(.top, level <= 2 ? 4 : 2)
        case let .paragraph(text):
            inlineText(text)
                .font(AppUI.Typography.body)
        case let .unorderedList(items):
            VStack(alignment: .leading, spacing: 4) {
                ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                    HStack(alignment: .top, spacing: 8) {
                        taskBulletView(state: item.taskState)
                        inlineText(item.text)
                            .font(AppUI.Typography.body)
                    }
                }
            }
        case let .orderedList(items):
            VStack(alignment: .leading, spacing: 4) {
                ForEach(Array(items.enumerated()), id: \.offset) { _, entry in
                    HStack(alignment: .top, spacing: 8) {
                        Text("\(entry.index).")
                            .font(AppUI.Typography.body)
                            .monospacedDigit()
                        inlineText(entry.text)
                            .font(AppUI.Typography.body)
                    }
                }
            }
        case let .codeBlock(language, code):
            VStack(alignment: .leading, spacing: 6) {
                if let language, !language.isEmpty {
                    Text(language)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                Group {
                    if preferOuterScroll {
                        // 消息列表内避免嵌套 ScrollView：否则会截获滚轮，外层列表无法滚动（见 MarkdownView preferOuterScroll 说明）
                        Text(verbatim: code)
                            .font(AppUI.Typography.code)
                            .textSelection(.enabled)
                            .multilineTextAlignment(.leading)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(10)
                    } else {
                        ScrollView(.horizontal, showsIndicators: false) {
                            Text(verbatim: code)
                                .font(AppUI.Typography.code)
                                .textSelection(.enabled)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(10)
                        }
                    }
                }
                .modifier(SubtleMarkdownCardModifier())
            }
        case let .quote(text):
            HStack(alignment: .top, spacing: 10) {
                Rectangle()
                    .fill(AppUI.Color.semantic.textSecondary.opacity(0.35))
                    .frame(width: 3)
                inlineText(text)
                    .font(AppUI.Typography.body)
                    .foregroundStyle(.secondary)
            }
        case let .table(headers, rows):
            tableView(headers: headers, rows: rows)
        case .thematicBreak:
            Divider()
                .padding(.vertical, 2)
        }
    }

    @ViewBuilder
    private func inlineText(_ text: String) -> some View {
        if let attributed = try? AttributedString(
            markdown: text,
            options: AttributedString.MarkdownParsingOptions(
                interpretedSyntax: .inlineOnlyPreservingWhitespace
            )
        ) {
            Text(attributed)
                .textSelection(.enabled)
        } else {
            Text(verbatim: text)
                .textSelection(.enabled)
        }
    }

    private func headingFont(level: Int) -> Font {
        switch level {
        case 1:
            return .system(size: 24, weight: .bold)
        case 2:
            return .system(size: 20, weight: .semibold)
        case 3:
            return .system(size: 18, weight: .semibold)
        default:
            return .system(size: 16, weight: .semibold)
        }
    }

    @ViewBuilder
    private func taskBulletView(state: NativeTaskState?) -> some View {
        switch state {
        case .todo:
            Image(systemName: "square")
                .font(AppUI.Typography.caption1)
                .foregroundStyle(.secondary)
                .padding(.top, 4)
        case .done:
            Image(systemName: "checkmark.square.fill")
                .font(AppUI.Typography.caption1)
                .foregroundStyle(.green)
                .padding(.top, 4)
        case .none:
            Text("•")
                .font(AppUI.Typography.body)
        }
    }

    private func tableView(headers: [String], rows: [[String]]) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            rowView(headers, isHeader: true)
            ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                Divider().opacity(0.4)
                rowView(row, isHeader: false)
            }
        }
        .modifier(SubtleMarkdownCardModifier())
    }

    private func rowView(_ cells: [String], isHeader: Bool) -> some View {
        HStack(alignment: .top, spacing: 0) {
            ForEach(Array(cells.enumerated()), id: \.offset) { idx, cell in
                inlineText(cell)
                    .font(isHeader ? AppUI.Typography.bodyEmphasized : AppUI.Typography.body)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                if idx < cells.count - 1 {
                    Divider().opacity(0.25)
                }
            }
        }
        .background(isHeader ? AppUI.Color.semantic.textSecondary.opacity(0.10) : Color.clear)
    }
}

private struct SubtleMarkdownCardModifier: ViewModifier {
    func body(content: Content) -> some View {
        AppCard(
            style: .subtle,
            padding: EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0)
        ) {
            content
        }
    }
}

private enum NativeMarkdownBlock {
    case heading(level: Int, text: String)
    case paragraph(text: String)
    case unorderedList(items: [NativeListItem])
    case orderedList(items: [(index: Int, text: String)])
    case codeBlock(language: String?, code: String)
    case quote(text: String)
    case table(headers: [String], rows: [[String]])
    case thematicBreak
}

private struct NativeListItem {
    let text: String
    let taskState: NativeTaskState?
}

private enum NativeTaskState {
    case todo
    case done
}

private enum NativeMarkdownParser {
    static func parse(_ content: String) -> [NativeMarkdownBlock] {
        let document = Document(parsing: content)
        var blocks: [NativeMarkdownBlock] = []

        for child in document.children {
            appendBlock(from: child, into: &blocks)
        }
        return blocks
    }

    private static func appendBlock(from markup: Markup, into blocks: inout [NativeMarkdownBlock]) {
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
            let items = Array(unordered.listItems).compactMap { listItem($0) }
            if !items.isEmpty {
                blocks.append(.unorderedList(items: items))
            }
        case let ordered as OrderedList:
            let start = Int(ordered.startIndex)
            let values: [(index: Int, text: String)] = Array(ordered.listItems).enumerated().compactMap { offset, item in
                guard let parsed = listItem(item) else { return nil }
                return (index: start + offset, text: parsed.text)
            }
            if !values.isEmpty {
                blocks.append(.orderedList(items: values))
            }
        case let code as CodeBlock:
            blocks.append(.codeBlock(language: code.language, code: code.code))
        case let quote as BlockQuote:
            let text = quote.children.map { $0.format() }.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
            if !text.isEmpty {
                blocks.append(.quote(text: text))
            }
        case _ as ThematicBreak:
            blocks.append(.thematicBreak)
        default:
            // 其他块级节点（如表格/HTML）先尝试识别表格，否则退化为文本，避免内容丢失。
            let fallback = markup.format().trimmingCharacters(in: .whitespacesAndNewlines)
            if let table = parseTableBlock(from: fallback) {
                blocks.append(table)
            } else if !fallback.isEmpty {
                blocks.append(.paragraph(text: fallback))
            }
        }
    }

    private static func listItem(_ item: ListItem) -> NativeListItem? {
        let text = item.children.map { $0.format() }.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return nil }
        let stripped = stripListPrefix(text)
        if let task = parseTaskState(stripped) {
            return NativeListItem(text: task.text, taskState: task.state)
        }
        return NativeListItem(text: stripped, taskState: nil)
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

    private static func parseTaskState(_ text: String) -> (state: NativeTaskState, text: String)? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if let range = trimmed.range(of: #"^\[( |x|X)\]\s+"#, options: .regularExpression) {
            let marker = trimmed[trimmed.index(after: trimmed.startIndex)]
            let rest = String(trimmed[range.upperBound...]).trimmingCharacters(in: .whitespacesAndNewlines)
            return (marker == "x" || marker == "X" ? .done : .todo, rest)
        }
        return nil
    }

    private static func parseTableBlock(from text: String) -> NativeMarkdownBlock? {
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
