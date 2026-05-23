import SwiftUI
import AppKit
import BeautifulMermaid
import MarkdownKitCore

/// Markdown 块级元素渲染器
/// 基于 Apple swift-markdown 框架，将 Markdown 文本解析为 SwiftUI 原生视图。
/// 支持标题、段落、列表（含任务列表）、代码块、引用、表格、分隔线。
/// Mermaid 代码块通过 beautiful-mermaid-swift 原生渲染为图片。
public struct MarkdownBlockRenderer: View {

    /// Markdown 原始文本
    private let markdown: String
    /// 渲染主题
    private let theme: MarkdownTheme

    /// 创建 Markdown 渲染器
    /// - Parameters:
    ///   - markdown: Markdown 原始文本
    ///   - theme: 渲染主题，默认使用 `.standard`
    public init(
        markdown: String,
        theme: MarkdownTheme = .standard
    ) {
        self.markdown = markdown
        self.theme = theme
    }

    @State private var blocks: [MarkdownBlock] = []
    @Environment(\.preferOuterScroll) private var preferOuterScroll

    public var body: some View {
        VStack(alignment: .leading, spacing: theme.blockSpacing) {
            ForEach(Array(blocks.enumerated()), id: \.offset) { _, block in
                blockView(block)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .foregroundStyle(theme.textColor ?? .primary)
        .task(id: markdown) {
            blocks = await MarkdownParseCache.shared.blocks(for: markdown)
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
                            .foregroundColor(theme.secondaryTextColor ?? .secondary)
                        inlineText(item.text)
                            .font(theme.bodyFont)
                            .lineSpacing(4)
                    }
                }
            }

        case let .codeBlock(language, code):
            if MarkdownParser.isMermaidCodeBlock(language: language) {
                MermaidDiagramView(source: code)
                    .frame(maxHeight: 300)
                    .padding(.vertical, 8)
                    .background(theme.codeBlockBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .strokeBorder(Color.secondary.opacity(0.12), lineWidth: 1)
                    )
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
                    .foregroundColor(theme.secondaryTextColor ?? .secondary)
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
                        .foregroundColor(theme.secondaryTextColor ?? .secondary)
                    Spacer()
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Color.secondary.opacity(0.08))
            }

            HighlightedCodeView(
                code: code,
                language: language,
                font: theme.codeFont,
                preferOuterScroll: preferOuterScroll
            )
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
        Text(MarkdownInlineParser.parse(text))
            .textSelection(.enabled)
    }

    @ViewBuilder
    private func taskBulletView(state: MarkdownTaskState?) -> some View {
        switch state {
        case .todo:
            Image(systemName: "square")
                .font(.system(size: 12))
                .foregroundColor(theme.secondaryTextColor ?? .secondary)
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

// MARK: - MarkdownParseCache

private actor MarkdownParseCache {
    static let shared = MarkdownParseCache()

    private let limit = 128
    private var cache: [String: [MarkdownBlock]] = [:]
    private var keys: [String] = []

    func blocks(for markdown: String) -> [MarkdownBlock] {
        if let cached = cache[markdown] {
            return cached
        }

        let parsed = MarkdownParser.parse(markdown)
        cache[markdown] = parsed
        keys.append(markdown)

        if keys.count > limit {
            let overflow = keys.count - limit
            for key in keys.prefix(overflow) {
                cache.removeValue(forKey: key)
            }
            keys.removeFirst(overflow)
        }

        return parsed
    }
}

// MARK: - HorizontalScrollView

/// 仅支持水平滚动的 NSScrollView 包装。
/// 垂直方向的滚轮事件会被转发给视图层级中的外层 NSScrollView（即聊天列表），
/// 从而实现：代码块水平可滚动、垂直滚动由外层列表接管。
///
/// 关键设计：使用 `sizeThatFits` 让 SwiftUI 布局系统感知到内容的真实高度，
/// 避免 NSScrollView 作为 documentView 时高度被外层 List 行高估算截断。
struct HorizontalScrollView<Content: View>: NSViewRepresentable {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    func sizeThatFits(
        _ proposal: ProposedViewSize,
        nsView: HorizontalOnlyScrollView,
        context: Context
    ) -> CGSize? {
        guard let hostingView = nsView.documentView as? NSHostingView<Content> else {
            return nil
        }
        // 让 NSHostingView 根据内容计算自身所需尺寸
        let size = hostingView.fittingSize
        return CGSize(width: proposal.width ?? size.width, height: size.height)
    }

    func makeNSView(context: Context) -> HorizontalOnlyScrollView {
        let scrollView = HorizontalOnlyScrollView()
        scrollView.drawsBackground = false
        scrollView.hasHorizontalScroller = false
        scrollView.hasVerticalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.horizontalScrollElasticity = .allowed
        scrollView.verticalScrollElasticity = .none

        let hostingView = NSHostingView(rootView: content)
        hostingView.translatesAutoresizingMaskIntoConstraints = false
        // 让内容按 intrinsic content size 自然撑开，以触发水平滚动
        hostingView.setContentHuggingPriority(.required, for: .horizontal)
        hostingView.setContentCompressionResistancePriority(.required, for: .horizontal)
        scrollView.documentView = hostingView

        // hostingView 顶部和左侧锚定 clip view；
        // 宽度至少等于可见区域（更宽时自然撑开触发水平滚动）；
        // 高度由内容自适应（不锁定），确保多行代码完整显示。
        NSLayoutConstraint.activate([
            hostingView.topAnchor.constraint(equalTo: scrollView.contentView.topAnchor),
            hostingView.leadingAnchor.constraint(equalTo: scrollView.contentView.leadingAnchor),
            hostingView.widthAnchor.constraint(greaterThanOrEqualTo: scrollView.contentView.widthAnchor),
        ])

        return scrollView
    }

    func updateNSView(_ nsView: HorizontalOnlyScrollView, context: Context) {
        if let hostingView = nsView.documentView as? NSHostingView<Content> {
            hostingView.rootView = content
        }
    }
}

/// NSScrollView 子类：仅消费水平方向的滚轮事件，垂直方向转发给外层 ScrollView。
class HorizontalOnlyScrollView: NSScrollView {
    override func scrollWheel(with event: NSEvent) {
        // 判断滚动方向：trackpad 可能同时包含 deltaX 和 deltaY
        // 水平位移大于垂直位移时视为水平滚动，由自身消费
        let isHorizontalGesture = abs(event.scrollingDeltaX) >= abs(event.scrollingDeltaY)

        if isHorizontalGesture {
            // 水平方向自己处理
            super.scrollWheel(with: event)
        } else {
            // 垂直方向转发给外层 ScrollView
            nextResponder?.scrollWheel(with: event)
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
