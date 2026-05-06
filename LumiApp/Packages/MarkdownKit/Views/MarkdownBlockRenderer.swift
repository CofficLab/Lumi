import SwiftUI
import BeautifulMermaid

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

            if preferOuterScroll {
                // 外层列表控制垂直滚动时，使用自定义容器避免水平 ScrollView 捕获垂直滚轮事件
                PassthroughHorizontalScrollView {
                    Text(verbatim: code)
                        .font(theme.codeFont)
                        .textSelection(.enabled)
                        .multilineTextAlignment(.leading)
                        .padding(10)
                }
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    Text(verbatim: code)
                        .font(theme.codeFont)
                        .textSelection(.enabled)
                        .multilineTextAlignment(.leading)
                        .padding(10)
                }
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

// MARK: - PassthroughHorizontalScrollView

/// 一个水平滚动容器，不会拦截垂直方向的滚轮事件。
///
/// 解决嵌套在垂直 `List`/`ScrollView` 中的水平 `ScrollView` 捕获垂直滚轮、
/// 导致外层无法滚动的问题。
///
/// 原理：底层使用 `NSScrollView`，在 `scrollWheel(with:)` 中：
/// - **垂直滚轮** → 直接转发给 responder 链上的上层视图
/// - **水平滚轮 / Shift+滚轮 / 触控板横扫** → 由自身处理水平滚动
struct PassthroughHorizontalScrollView<Content: View>: NSViewRepresentable {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    func makeNSView(context: Context) -> PassthroughHorizontalScrollViewHost {
        let host = PassthroughHorizontalScrollViewHost()
        host.setup(content: content, context: context)
        return host
    }

    func updateNSView(_ nsView: PassthroughHorizontalScrollViewHost, context: Context) {
        nsView.update(content: content)
    }
}

/// 承载 `PassthroughHorizontalScrollView` 的 NSView 宿主
///
/// 内部使用 `NSScrollView` 进行水平滚动，但通过重写 `scrollWheel(with:)`
/// 将垂直滚轮事件转发给 responder 链上的上层视图。
final class PassthroughHorizontalScrollViewHost: NSView {
    private var hostingView: NSHostingView<AnyView>?
    private var scrollView: NSScrollView?

    func setup(content: some View, context: NSViewRepresentableContext<some NSViewRepresentable>) {
        wantsLayer = true

        let hosting = NSHostingView(rootView: AnyView(content))
        hosting.translatesAutoresizingMaskIntoConstraints = false
        self.hostingView = hosting

        let scroll = NSScrollView()
        scroll.translatesAutoresizingMaskIntoConstraints = false
        scroll.documentView = hosting
        scroll.hasHorizontalScroller = false
        scroll.hasVerticalScroller = false
        scroll.horizontalScrollElasticity = .allowed
        scroll.verticalScrollElasticity = .none
        scroll.drawsBackground = false
        scroll.automaticallyAdjustsContentInsets = false
        scroll.contentInsets = NSEdgeInsets(top: 0, left: 0, bottom: 0, right: 0)
        self.scrollView = scroll

        addSubview(scroll)
        NSLayoutConstraint.activate([
            scroll.leadingAnchor.constraint(equalTo: leadingAnchor),
            scroll.trailingAnchor.constraint(equalTo: trailingAnchor),
            scroll.topAnchor.constraint(equalTo: topAnchor),
            scroll.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])

        // 让 hostingView 宽度自适应内容，高度跟随容器
        NSLayoutConstraint.activate([
            hosting.topAnchor.constraint(equalTo: scroll.contentView.topAnchor),
            hosting.heightAnchor.constraint(equalTo: scroll.heightAnchor),
        ])
    }

    func update(content: some View) {
        hostingView?.rootView = AnyView(content)
    }

    override func scrollWheel(with event: NSEvent) {
        // 判断是否为水平滚动意图
        let isHorizontalGesture: Bool
        if event.phase == .mayBegin || event.phase == .began {
            // 触控板：根据初始 deltaX/deltaY 判断方向
            isHorizontalGesture = abs(event.deltaX) > abs(event.deltaY)
        } else if event.modifierFlags.contains(.shift) {
            // Shift + 滚轮 = 水平滚动
            isHorizontalGesture = true
        } else {
            // 普通鼠标滚轮：deltaX 几乎为 0，属于垂直意图
            isHorizontalGesture = abs(event.deltaX) > abs(event.deltaY)
        }

        if isHorizontalGesture {
            // 水平滚动：由自身 NSScrollView 处理
            super.scrollWheel(with: event)
        } else {
            // 垂直滚动：转发给 responder 链（交给外层 List/ScrollView）
            nextResponder?.scrollWheel(with: event)
        }
    }

    override var intrinsicContentSize: NSSize {
        // 宽度跟随父容器，高度由内容决定
        return NSSize(width: NSView.noIntrinsicMetric, height: hostingView?.intrinsicContentSize.height ?? NSView.noIntrinsicMetric)
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
