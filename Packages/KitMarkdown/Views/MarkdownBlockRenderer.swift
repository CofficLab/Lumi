import SwiftUI
import AppKit
import BeautifulMermaid
import LumiUI
import KitMarkdownCore

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
        // 缓存命中(历史行常见)时同步初始化,首屏即有 measured height;
        // miss 时(长文本首次出现)用空数组初始化,避免主线程同步全量解析,
        // 由 body 的 .task 异步解析后填充。
        let initial = MarkdownBlockCache.shared.cachedBlocks(for: markdown) ?? []
        self._blocks = State(initialValue: initial)
    }

    /// Blocks are initialized from the bounded process cache so their measured
    /// height is available during the first layout pass. On a cache miss the
    /// view starts empty and is populated asynchronously by `.task` below,
    /// keeping full Markdown parsing off the main thread's first render.
    @State private var blocks: [MarkdownBlock]
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
            // 缓存命中(init 已填充)时 blocks 不会变,这里是一次廉价的不变赋值;
            // miss 时解析在后台线程完成(注意:`.task` 继承视图的 MainActor,
            // 直接同步调用会把全量解析留在主线程 —— 审计 P8),主线程只接收结果。
            // markdown 变化时 SwiftUI 取消旧任务,await 返回后丢弃过期结果。
            let source = markdown
            let parsed = await Task.detached(priority: .userInitiated) {
                MarkdownBlockCache.shared.blocks(for: source)
            }.value
            guard !Task.isCancelled else { return }
            if parsed != blocks {
                blocks = parsed
            }
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
        CachedMarkdownInlineText(text: text)
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

// MARK: - MarkdownBlockCache

/// Synchronous bounded cache for block parsing.
///
/// Markdown block parsing must be available during the first layout pass so
/// ScrollView can measure the message's height correctly. The cache keeps that
/// necessary first parse from repeating whenever SwiftUI reconstructs a View
/// value during scrolling.
///
/// For the streaming row the content changes on every token, so a full-content
/// key would miss every frame and re-parse the whole document each time. A
/// dedicated streaming slot therefore remembers the last streamed content and,
/// when the new content is a prefix-append of it (the common token-by-token
/// case), re-parses only the still-changing tail instead of the whole string.
final class MarkdownBlockCache: @unchecked Sendable {
    static let shared = MarkdownBlockCache()

    private let limit = 384
    private let lock = NSLock()
    private var cache: [String: [MarkdownBlock]] = [:]
    private var keys: [String] = []

    /// Streaming slot: the source up to the last stable block boundary and the
    /// blocks parsed from just that stable prefix. Everything after the boundary
    /// may still be growing, so on each append only the tail is re-parsed.
    private var streamingSlot: (stableSource: String, stableBlocks: [MarkdownBlock])?

    func blocks(for markdown: String) -> [MarkdownBlock] {
        lock.lock()
        defer { lock.unlock() }

        // 1) Exact hit — the common case for stable history rows.
        if let cached = cache[markdown] {
            return cached
        }

        // 2) Streaming append — new content starts with the last content seen.
        //    Re-parse only the tail beyond the stable boundary.
        if let slot = streamingSlot,
           markdown.hasPrefix(slot.stableSource) {
            let stableLength = slot.stableSource.count
            let tail = markdown.count > stableLength
                ? String(markdown.dropFirst(stableLength))
                : ""
            let tailBlocks = tail.isEmpty ? [] : MarkdownParser.parse(tail)
            let merged = slot.stableBlocks + tailBlocks
            // Advance the stable boundary for the next append. Do not write into
            // the bounded history cache — this content is still changing.
            let boundary = nextStableBoundary(in: markdown)
            streamingSlot = (
                stableSource: String(markdown.prefix(boundary)),
                stableBlocks: boundary == stableLength
                    ? slot.stableBlocks
                    : MarkdownParser.parse(String(markdown.prefix(boundary)))
            )
            return merged
        }

        // 3) Miss — full parse. Seed the streaming slot so the next append can
        //    reuse the stable prefix.
        let parsed = MarkdownParser.parse(markdown)
        cache[markdown] = parsed
        keys.append(markdown)
        evictIfNeeded()
        let boundary = nextStableBoundary(in: markdown)
        streamingSlot = (
            stableSource: String(markdown.prefix(boundary)),
            stableBlocks: boundary == markdown.count
                ? parsed
                : MarkdownParser.parse(String(markdown.prefix(boundary)))
        )
        return parsed
    }

    /// 只返回缓存命中或流式增量结果,不触发全量解析。
    ///
    /// 供 `MarkdownBlockRenderer.init` 用:命中时同步初始化(首屏即有 measured
    /// height);miss 时返回 nil,init 用空数组初始化,由 `.task` 异步解析后填充,
    /// 避免长文本首次出现时在主线程同步全量解析造成卡顿。
    func cachedBlocks(for markdown: String) -> [MarkdownBlock]? {
        lock.lock()
        defer { lock.unlock() }

        // 1) Exact hit.
        if let cached = cache[markdown] {
            return cached
        }

        // 2) Streaming append — already cheap (tail parse only), return inline.
        if let slot = streamingSlot,
           markdown.hasPrefix(slot.stableSource) {
            return nil // 仍交给 blocks(for:) 处理(它需要推进 stable boundary)
        }

        // 3) Miss — 需全量解析,返回 nil 让调用方异步处理。
        return nil
    }

    /// 后台预热:未缓存时解析并写入历史缓存。
    ///
    /// 与 `blocks(for:)` 的差异:不推进 `streamingSlot` —— 预热针对的是稳定的
    /// 历史内容,流式尾行的增量解析状态不应被后台任务改写。解析在锁外执行,
    /// 不阻塞滚动/流式路径上的缓存查询;已缓存时为一次加锁字典查询,近乎免费。
    /// 供会话加载后由宿主在后台线程批量调用,使用户滚动到未看过的行时同步命中,
    /// 行物化不再触发主线程解析。
    func warm(markdown: String) {
        lock.lock()
        let isCached = cache[markdown] != nil
        lock.unlock()
        guard !isCached else { return }

        let parsed = MarkdownParser.parse(markdown)

        lock.lock()
        defer { lock.unlock() }
        guard cache[markdown] == nil else { return }  // 并发下他人已写入
        cache[markdown] = parsed
        keys.append(markdown)
        evictIfNeeded()
    }

    /// Returns the length of the prefix of `markdown` that ends at the last
    /// block boundary (a blank line). Content after it may still be growing and
    /// must be re-parsed on the next append; content before it is stable.
    /// Falls back to 0 (re-parse everything) when there is no boundary yet.
    private func nextStableBoundary(in markdown: String) -> Int {
        if let range = markdown.range(of: "\n\n", options: .backwards) {
            return markdown.distance(from: markdown.startIndex, to: range.upperBound)
        }
        return 0
    }

    private func evictIfNeeded() {
        guard keys.count > limit else { return }
        let overflow = keys.count - limit
        for key in keys.prefix(overflow) {
            cache.removeValue(forKey: key)
        }
        keys.removeFirst(overflow)
    }
}

/// Synchronous bounded cache for inline Markdown parsing.
///
/// Inline parsing used to happen directly inside `body`, which meant that
/// rebuilding a message row could re-run `AttributedString(markdown:)` for
/// every paragraph, list item, quote, and table cell. The cache keeps that
/// work off the view evaluation path and bounds retained attributed strings.
///
/// 锁保护的同步缓存(与 `MarkdownBlockCache` 同构),使缓存命中可以在 `body`
/// 求值内同步返回 —— 列表滚动使行重新物化时,已解析过的文本首帧即富文本,
/// 不再经历"纯文本 → 异步升级"的两阶段布局跳变。miss 时的全量解析由调用方
/// 在 `.task`(后台线程)中完成,不占主线程。
private final class MarkdownInlineParseCache: @unchecked Sendable {
    static let shared = MarkdownInlineParseCache()

    private let limit = 2048
    private let lock = NSLock()
    private var cache: [String: AttributedString] = [:]
    private var keys: [String] = []

    /// 只返回缓存命中结果,不触发解析。
    ///
    /// 供 `CachedMarkdownInlineText.body` 在视图求值路径上同步调用:命中即首帧
    /// 富文本;miss 返回 nil,由 `.task` 调 `attributedString(for:)` 异步解析填充。
    func cachedAttributedString(for text: String) -> AttributedString? {
        lock.lock()
        defer { lock.unlock() }
        return cache[text]
    }

    /// 命中即返回;miss 时同步解析并写入缓存。
    /// 调用方应在后台线程(如 `.task`)调用,避免长文本解析阻塞主线程。
    /// 解析在锁外执行,不阻塞并发的缓存查询。
    func attributedString(for text: String) -> AttributedString {
        lock.lock()
        let cached = cache[text]
        lock.unlock()
        if let cached {
            return cached
        }

        let parsed = MarkdownInlineParser.parse(text)

        lock.lock()
        defer { lock.unlock() }
        cache[text] = parsed
        keys.append(text)

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

/// 缓存命中时首帧直接渲染富文本;miss 时先显示纯文本,
/// 待后台解析完成后升级为富文本。
private struct CachedMarkdownInlineText: View {
    let text: String

    @State private var attributedText: AttributedString?

    var body: some View {
        Group {
            // 同步命中(历史行滚回视口的常见情况):首帧即富文本,
            // 无"纯文本 → 富文本"的高度跳变,也不占异步任务。
            if let attributedText {
                Text(attributedText)
            } else if let cached = MarkdownInlineParseCache.shared.cachedAttributedString(for: text) {
                Text(cached)
            } else {
                Text(verbatim: text)
            }
        }
        .task(id: text) {
            guard attributedText == nil else { return }
            // 与块级解析同理(P8):miss 时的解析下放后台线程,
            // 主线程只接收结果;text 变化时丢弃过期结果。
            let source = text
            let parsed = await Task.detached(priority: .userInitiated) {
                MarkdownInlineParseCache.shared.attributedString(for: source)
            }.value
            guard !Task.isCancelled else { return }
            if attributedText != parsed {
                attributedText = parsed
            }
        }
    }
}

// MARK: - HorizontalScrollView

/// 仅支持水平滚动的 NSScrollView 包装。
/// 垂直方向的滚轮事件会被转发给视图层级中的外层 NSScrollView（即聊天列表），
/// 从而实现：代码块水平可滚动、垂直滚动由外层 List 接管。
///
/// 关键设计：使用 `sizeThatFits` 让 SwiftUI 布局系统感知到内容的真实高度，
/// 避免 NSScrollView 作为 documentView 时高度被外层 List 行高估算截断。
///
/// 性能优化：`NSHostingView.fittingSize` 是昂贵操作（每帧调用会阻塞主线程）。
/// 测量结果按（内容指纹, proposal.width 分桶）缓存在 `HorizontalFittingSizeCache`
/// （可单测的纯逻辑单元）中；`updateNSView` 在内容指纹未变时不重设 rootView、
/// 不清缓存，流式间歇与父视图重求值不再触发全内容重测量（P1）。
struct HorizontalScrollView<Fingerprint: Hashable, Content: View>: NSViewRepresentable {
    /// 内容指纹：必须覆盖所有影响渲染结果的输入（文本、字体等）。
    /// 指纹未变时跳过 rootView 重设并复用测量缓存。
    let contentFingerprint: Fingerprint
    let content: Content

    init(
        contentFingerprint: Fingerprint,
        @ViewBuilder content: () -> Content
    ) {
        self.contentFingerprint = contentFingerprint
        self.content = content()
    }

    // MARK: - Coordinator

    /// 持有高度测量缓存与已安装的内容指纹。
    final class Coordinator {
        var cache = HorizontalFittingSizeCache<Fingerprint>()
        /// 当前已安装进 NSHostingView 的内容指纹。
        var installedFingerprint: Fingerprint?
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func sizeThatFits(
        _ proposal: ProposedViewSize,
        nsView: HorizontalOnlyScrollView,
        context: Context
    ) -> CGSize? {
        guard let hostingView = nsView.documentView as? NSHostingView<Content> else {
            return nil
        }

        let proposalWidth = proposal.width ?? 0

        // 缓存命中（内容指纹 + 宽度分桶一致）：直接返回缓存高度，
        // 不触碰昂贵的 fittingSize。三级查找:
        // 1) Coordinator 单槽(同视图实例帧间复用,无锁);
        // 2) 进程级共享存储(行被 List 拆除重建后跨物化复用);
        // 3) 测量,并双写两级缓存。
        if let cachedHeight = context.coordinator.cache.cachedHeight(
            fingerprint: contentFingerprint,
            proposedWidth: proposalWidth
        ) ?? HorizontalFittingSizeStore.shared.height(
            fingerprint: contentFingerprint,
            proposedWidth: proposalWidth
        ) {
            // 共享命中时回填本地单槽,后续帧走无锁路径
            context.coordinator.cache.store(
                fingerprint: contentFingerprint,
                proposedWidth: proposalWidth,
                height: cachedHeight
            )
            return CGSize(width: proposalWidth, height: cachedHeight)
        }

        // 缓存未命中：调用 fittingSize 并缓存结果
        let size = hostingView.fittingSize
        context.coordinator.cache.store(
            fingerprint: contentFingerprint,
            proposedWidth: proposalWidth,
            height: size.height
        )
        HorizontalFittingSizeStore.shared.store(
            fingerprint: contentFingerprint,
            proposedWidth: proposalWidth,
            height: size.height
        )
        return CGSize(width: proposalWidth, height: size.height)
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

        context.coordinator.installedFingerprint = contentFingerprint
        return scrollView
    }

    func updateNSView(_ nsView: HorizontalOnlyScrollView, context: Context) {
        guard let hostingView = nsView.documentView as? NSHostingView<Content> else {
            return
        }
        // 内容指纹未变（流式间歇、父视图重求值等）：不重设 rootView、
        // 保留测量缓存。旧实现此处无条件清缓存 + 重设 rootView，
        // 是流式输出后期每帧全内容重测量的根因（P1）。
        // 指纹变化时 `cachedHeight` 的指纹校验自然失效，无需显式清缓存。
        guard context.coordinator.installedFingerprint != contentFingerprint else {
            return
        }
        hostingView.rootView = content
        context.coordinator.installedFingerprint = contentFingerprint
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
