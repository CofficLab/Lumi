import SwiftUI

/// Markdown 块级元素渲染器
/// 基于 Apple swift-markdown 框架，将 Markdown 文本解析为 SwiftUI 原生视图。
/// 支持标题、段落、列表（含任务列表）、代码块、引用、表格、分隔线。
/// 代码块通过 `MarkdownParser.isMermaidCodeBlock(language:)` 可识别 Mermaid 语言，
/// 供调用方替换为原生 Mermaid 渲染。
public struct MarkdownBlockRenderer: View {

    /// Markdown 原始文本
    private let markdown: String
    /// 渲染主题
    private let theme: MarkdownTheme
    /// 可选的 Mermaid 代码块自定义渲染
    /// 当返回 nil 时，使用默认的代码块渲染
    private let mermaidRenderer: ((String) -> AnyView)?

    /// 创建 Markdown 渲染器
    /// - Parameters:
    ///   - markdown: Markdown 原始文本
    ///   - theme: 渲染主题，默认使用 `.standard`
    ///   - mermaidRenderer: Mermaid 代码块自定义渲染器。传入 mermaid 源码字符串，返回自定义视图。
    ///                      返回 nil 则使用默认代码块渲染。
    public init(
        markdown: String,
        theme: MarkdownTheme = .standard,
        mermaidRenderer: ((String) -> AnyView)? = nil
    ) {
        self.markdown = markdown
        self.theme = theme
        self.mermaidRenderer = mermaidRenderer
    }

    @State private var blocks: [MarkdownBlock] = []

    public var body: some View {
        VStack(alignment: .leading, spacing: theme.blockSpacing) {
            ForEach(Array(blocks.enumerated()), id: \.offset) { _, block in
                blockView(block)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .task(id: markdown) {
            blocks = MarkdownParser.parse(markdown)
        }
    }

    // MARK: - Block Rendering

    @ViewBuilder
    private func blockView(_ block: MarkdownBlock) -> some View {
        switch block {
        case let .heading(level, text):
            inlineText(text)
                .font(theme.headingFont(level))
                .fontWeight(level <= 2 ? .bold : .semibold)

        case let .paragraph(text):
            inlineText(text)
                .font(theme.bodyFont)
                .lineSpacing(4)

        case let .unorderedList(items):
            VStack(alignment: .leading, spacing: theme.listItemSpacing) {
                ForEach(items) { item in
                    HStack(alignment: .top, spacing: 8) {
                        taskBulletView(state: item.taskState)
                        inlineText(item.text)
                            .font(theme.bodyFont)
                            .lineSpacing(4)
                    }
                }
            }

        case let .orderedList(items):
            VStack(alignment: .leading, spacing: theme.listItemSpacing) {
                ForEach(items) { item in
                    HStack(alignment: .top, spacing: 8) {
                        Text("\(item.index).")
                            .font(theme.codeFont)
                            .foregroundColor(.secondary)
                        inlineText(item.text)
                            .font(theme.bodyFont)
                            .lineSpacing(4)
                    }
                }
            }

        case let .codeBlock(language, code):
            if let renderer = mermaidRenderer,
               MarkdownParser.isMermaidCodeBlock(language: language) {
                renderer(code)
            } else {
                codeBlockView(language: language, code: code)
            }

        case let .quote(text):
            HStack(alignment: .top, spacing: 10) {
                RoundedRectangle(cornerRadius: 1.5)
                    .fill(theme.quoteBorderColor)
                    .frame(width: 3)
                inlineText(text)
                    .font(theme.bodyFont)
                    .foregroundColor(.secondary)
                    .lineSpacing(4)
            }

        case let .table(headers, rows):
            tableView(headers: headers, rows: rows)

        case .thematicBreak:
            Divider()
        }
    }

    // MARK: - Code Block

    @ViewBuilder
    private func codeBlockView(language: String?, code: String) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            if let language, !language.isEmpty, theme.showLanguageLabel {
                HStack {
                    Text(language)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Color.secondary.opacity(0.08))
            }

            ScrollView(.horizontal, showsIndicators: false) {
                Text(verbatim: code)
                    .font(theme.codeFont)
                    .textSelection(.enabled)
                    .multilineTextAlignment(.leading)
                    .padding(10)
            }
        }
        .background(theme.codeBlockBackground)
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .strokeBorder(Color.secondary.opacity(0.12), lineWidth: 1)
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
                .strokeBorder(Color.secondary.opacity(0.12), lineWidth: 1)
        )
    }

    @ViewBuilder
    private func tableRowView(_ cells: [String], isHeader: Bool) -> some View {
        HStack(alignment: .top, spacing: 0) {
            ForEach(Array(cells.enumerated()), id: \.offset) { idx, cell in
                inlineText(cell)
                    .font(isHeader
                        ? .system(size: 12, weight: .semibold)
                        : .system(size: 12))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                if idx < cells.count - 1 {
                    Divider().opacity(0.25)
                }
            }
        }
        .background(isHeader ? theme.tableHeaderBackground : Color.clear)
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

    @ViewBuilder
    private func taskBulletView(state: MarkdownTaskState?) -> some View {
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
                .font(theme.bodyFont)
        }
    }
}

// MARK: - Preview

#Preview {
    MarkdownBlockRenderer(markdown: """
        # 标题 1

        这是一段 **加粗** 和 *斜体* 文本。

        ## 标题 2

        - [x] 已完成任务
        - [ ] 未完成任务

        1. 第一项
        2. 第二项

        > 这是一段引用文本

        ```swift
        let greeting = "Hello, World!"
        print(greeting)
        ```

        ---

        | 列 A | 列 B | 列 C |
        | --- | --- | --- |
        | A1 | B1 | C1 |
        | A2 | B2 | C2 |

        ```mermaid
        graph TD
        A[Start] --> B{Decision}
        B -->|Yes| C[Do Something]
        B -->|No| D[End]
        C --> D
        ```
        """)
    .padding()
}
