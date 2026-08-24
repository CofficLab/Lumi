import AppKit
import Foundation
import Testing
@testable import MessageListAppKitPlugin

@Suite(.serialized)
@MainActor
struct AppKitCodeTableMermaidTests {
    private let theme = AppKitMessageTheme.systemDefault()

    // MARK: - Code block

    @Test("代码块高度确定且包含头部+多行")
    func codeBlockHeightDeterministic() {
        let code = "func hello() {\n    print(\"hi\")\n}"
        let a = AppKitCodeBlockView.measureHeight(code: code, width: 400, theme: theme)
        let b = AppKitCodeBlockView.measureHeight(code: code, width: 400, theme: theme)
        #expect(a == b)
        #expect(a > AppKitCodeBlockView.headerHeight + 40)

        let single = AppKitCodeBlockView.measureHeight(code: "one line", width: 400, theme: theme)
        #expect(a > single) // 多行更高
    }

    @Test("代码块含语言标签、复制按钮与横向滚动")
    func codeBlockHasChrome() {
        let view = AppKitCodeBlockView(frame: NSRect(x: 0, y: 0, width: 400, height: 120))
        view.configure(code: "let x = 1", language: "swift", theme: theme)

        let scrolls = view.subviews.compactMap { $0 as? NSScrollView }
        #expect(scrolls.count == 1)
        #expect(scrolls.first?.hasHorizontalScroller == true)

        // 语言标签可见。
        let labels = view.subviews.first?.subviews.compactMap { $0 as? NSTextField } ?? []
        #expect(labels.contains { $0.stringValue == "swift" })
    }

    // MARK: - Table

    @Test("表格高度 = 表头 + 行数 × 行高")
    func tableHeightDeterministic() {
        let headers = ["Name", "Type"]
        let rows = [["id", "UUID"], ["name", "String"]]
        let height = AppKitMarkdownTableView.measureHeight(headers: headers, rows: rows)
        #expect(height == (1 + 2) * AppKitMarkdownTableView.rowHeight + AppKitMarkdownTableView.headerPadding)
    }

    @Test("表格无嵌套垂直滚动视图")
    func tableHasNoVerticalNesting() {
        let view = AppKitMarkdownTableView(frame: NSRect(x: 0, y: 0, width: 400, height: 100))
        view.configure(headers: ["A", "B"], rows: [["1", "2"]], theme: theme)
        let scrolls = view.subviews.compactMap { $0 as? NSScrollView }
        #expect(scrolls.first?.hasVerticalScroller == false)
        #expect(scrolls.first?.hasHorizontalScroller == true)
    }

    // MARK: - Mermaid cache

    @Test("Mermaid 缓存命中与存储")
    func mermaidCacheHit() {
        let cache = AppKitMermaidCache(limit: 3)
        let source = "graph TD\nA --> B"
        #expect(cache.image(for: source) == nil)

        cache.store(NSImage(size: NSSize(width: 10, height: 10)), for: source)
        #expect(cache.image(for: source) != nil)
        #expect(cache.hits == 1)
        #expect(cache.misses == 1)
    }

    @Test("Mermaid 缓存 LRU 逐出")
    func mermaidCacheLRU() {
        let cache = AppKitMermaidCache(limit: 2)
        cache.store(NSImage(size: .zero), for: "one")
        cache.store(NSImage(size: .zero), for: "two")
        cache.store(NSImage(size: .zero), for: "three")
        #expect(cache.image(for: "one") == nil)
        #expect(cache.image(for: "two") != nil)
        #expect(cache.image(for: "three") != nil)
    }

    @Test("Mermaid 视图渲染失败显示诊断块")
    func mermaidErrorFallback() async {
        let view = AppKitMermaidView(frame: NSRect(x: 0, y: 0, width: 300, height: 120))
        let cache = AppKitMermaidCache()
        // 非法语法应导致渲染失败。
        view.configure(source: "not a mermaid diagram at all", cache: cache, theme: theme)

        try? await Task.sleep(nanoseconds: 400_000_000)
        let fallbackScroll = view.subviews.first { $0 is NSScrollView && !($0 as! NSScrollView).isHidden } as? NSScrollView
        #expect(fallbackScroll != nil)
    }

    @Test("Mermaid 有效图渲染出图片并入缓存")
    func mermaidSuccessfulRender() async {
        let view = AppKitMermaidView(frame: NSRect(x: 0, y: 0, width: 300, height: 120))
        let cache = AppKitMermaidCache()
        let source = "graph TD\n    A[Start] --> B[End]"
        view.configure(source: source, cache: cache, theme: theme)

        // 等待异步渲染（Elk 布局可能较慢）。
        var attempts = 0
        while cache.image(for: source) == nil, attempts < 40 {
            try? await Task.sleep(nanoseconds: 100_000_000)
            attempts += 1
        }
        #expect(cache.image(for: source) != nil)

        let imageView = view.subviews.compactMap { $0 as? NSImageView }.first
        #expect(imageView?.image != nil)
        #expect(imageView?.isHidden == false)
    }
}
