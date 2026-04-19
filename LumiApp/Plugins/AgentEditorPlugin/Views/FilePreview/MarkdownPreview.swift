import SwiftUI
import Markdown

/// Markdown 预览 Popover
/// 在面包屑导航右侧的预览按钮点击后弹出，展示当前 md 文件的渲染效果
struct MarkdownPreview: View {

    /// 编辑器状态（读取文件内容）
    @ObservedObject var state: EditorState

    /// Popover 内容高度（自适应内容）
    @State private var contentHeight: CGFloat = 400

    /// Popover 内容宽度
    private let popoverWidth: CGFloat = 520

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                if let content = state.content?.string, !content.isEmpty {
                    MarkdownPreviewContent(markdown: content)
                        .padding(20)
                } else {
                    emptyState
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(width: popoverWidth, height: min(contentHeight, 600))
        .background(Color(nsColor: .textBackgroundColor))
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 24, weight: .thin))
                .foregroundColor(AppUI.Color.semantic.textTertiary)
            Text("No content to preview")
                .font(.system(size: 12))
                .foregroundColor(AppUI.Color.semantic.textTertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(40)
    }
}

// MARK: - Markdown Preview Content

/// Markdown 内容渲染视图（复用 AgentMessageRendererPlugin 的渲染逻辑）
private struct MarkdownPreviewContent: View {

    let markdown: String

    @State private var blocks: [PreviewBlock] = []

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(Array(blocks.enumerated()), id: \.offset) { _, block in
                blockView(block)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .task(id: markdown) {
            blocks = PreviewMarkdownParser.parse(markdown)
        }
    }

    // MARK: - Block Views

    @ViewBuilder
    private func blockView(_ block: PreviewBlock) -> some View {
        switch block {
        case let .heading(level, text):
            inlineText(text)
                .font(headingFont(level: level))
                .fontWeight(level <= 2 ? .bold : .semibold)
                .padding(.top, level <= 2 ? 8 : 4)
                .padding(.bottom, 4)

        case let .paragraph(text):
            inlineText(text)
                .font(.system(size: 13))
                .lineSpacing(4)

        case let .unorderedList(items):
            VStack(alignment: .leading, spacing: 4) {
                ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                    HStack(alignment: .top, spacing: 8) {
                        taskBulletView(state: item.taskState)
                        inlineText(item.text)
                            .font(.system(size: 13))
                            .lineSpacing(4)
                    }
                }
            }

        case let .orderedList(items):
            VStack(alignment: .leading, spacing: 4) {
                ForEach(Array(items.enumerated()), id: \.offset) { _, entry in
                    HStack(alignment: .top, spacing: 8) {
                        Text("\(entry.index).")
                            .font(.system(size: 13, design: .monospaced))
                            .foregroundColor(AppUI.Color.semantic.textSecondary)
                        inlineText(entry.text)
                            .font(.system(size: 13))
                            .lineSpacing(4)
                    }
                }
            }

        case let .codeBlock(language, code):
            codeBlockView(language: language, code: code)

        case let .quote(text):
            HStack(alignment: .top, spacing: 10) {
                RoundedRectangle(cornerRadius: 1.5)
                    .fill(AppUI.Color.semantic.textSecondary.opacity(0.3))
                    .frame(width: 3)
                inlineText(text)
                    .font(.system(size: 13))
                    .foregroundColor(AppUI.Color.semantic.textSecondary)
                    .lineSpacing(4)
            }
            .padding(.vertical, 4)

        case let .table(headers, rows):
            tableView(headers: headers, rows: rows)

        case .thematicBreak:
            Divider()
                .padding(.vertical, 4)
        }
    }

    // MARK: - Code Block

    @ViewBuilder
    private func codeBlockView(language: String?, code: String) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            if let language, !language.isEmpty {
                HStack {
                    Text(language)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(AppUI.Color.semantic.textTertiary)
                    Spacer()
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(AppUI.Color.semantic.textTertiary.opacity(0.08))
            }

            ScrollView(.horizontal, showsIndicators: false) {
                Text(verbatim: code)
                    .font(.system(size: 12, design: .monospaced))
                    .textSelection(.enabled)
                    .padding(10)
            }
        }
        .background(AppUI.Color.semantic.textTertiary.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .strokeBorder(AppUI.Color.semantic.textTertiary.opacity(0.1), lineWidth: 1)
        )
    }

    // MARK: - Table

    @ViewBuilder
    private func tableView(headers: [String], rows: [[String]]) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            tableRowView(headers, isHeader: true)
            ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                Divider().opacity(0.4)
                tableRowView(row, isHeader: false)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .strokeBorder(AppUI.Color.semantic.textTertiary.opacity(0.1), lineWidth: 1)
        )
    }

    @ViewBuilder
    private func tableRowView(_ cells: [String], isHeader: Bool) -> some View {
        HStack(alignment: .top, spacing: 0) {
            ForEach(Array(cells.enumerated()), id: \.offset) { idx, cell in
                inlineText(cell)
                    .font(isHeader ? .system(size: 12, weight: .semibold) : .system(size: 12))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                if idx < cells.count - 1 {
                    Divider().opacity(0.25)
                }
            }
        }
        .background(isHeader ? AppUI.Color.semantic.textTertiary.opacity(0.06) : Color.clear)
    }

    // MARK: - Helpers

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
        case 1: return .system(size: 24, weight: .bold)
        case 2: return .system(size: 20, weight: .semibold)
        case 3: return .system(size: 17, weight: .semibold)
        default: return .system(size: 15, weight: .semibold)
        }
    }

    @ViewBuilder
    private func taskBulletView(state: PreviewTaskState?) -> some View {
        switch state {
        case .todo:
            Image(systemName: "square")
                .font(.system(size: 12))
                .foregroundColor(.secondary)
                .padding(.top, 3)
        case .done:
            Image(systemName: "checkmark.square.fill")
                .font(.system(size: 12))
                .foregroundColor(.green)
                .padding(.top, 3)
        case .none:
            Text("•")
                .font(.system(size: 13))
        }
    }
}

// MARK: - Parser

private enum PreviewBlock {
    case heading(level: Int, text: String)
    case paragraph(text: String)
    case unorderedList(items: [PreviewListItem])
    case orderedList(items: [(index: Int, text: String)])
    case codeBlock(language: String?, code: String)
    case quote(text: String)
    case table(headers: [String], rows: [[String]])
    case thematicBreak
}

private struct PreviewListItem {
    let text: String
    let taskState: PreviewTaskState?
}

private enum PreviewTaskState {
    case todo
    case done
}

private enum PreviewMarkdownParser {
    static func parse(_ content: String) -> [PreviewBlock] {
        let document = Document(parsing: content)
        var blocks: [PreviewBlock] = []

        for child in document.children {
            appendBlock(from: child, into: &blocks)
        }
        return blocks
    }

    private static func appendBlock(from markup: Markup, into blocks: inout [PreviewBlock]) {
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

    private static func listItem(_ item: ListItem) -> PreviewListItem? {
        let text = item.children.map { $0.format() }.joined(separator: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return nil }
        let stripped = stripListPrefix(text)
        if let task = parseTaskState(stripped) {
            return PreviewListItem(text: task.text, taskState: task.state)
        }
        return PreviewListItem(text: stripped, taskState: nil)
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

    private static func parseTaskState(_ text: String) -> (state: PreviewTaskState, text: String)? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if let range = trimmed.range(of: #"^\[( |x|X)\]\s+"#, options: .regularExpression) {
            let marker = trimmed[trimmed.index(after: trimmed.startIndex)]
            let rest = String(trimmed[range.upperBound...]).trimmingCharacters(in: .whitespacesAndNewlines)
            return (marker == "x" || marker == "X" ? .done : .todo, rest)
        }
        return nil
    }

    private static func parseTableBlock(from text: String) -> PreviewBlock? {
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
