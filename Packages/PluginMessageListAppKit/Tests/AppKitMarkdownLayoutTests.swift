import AppKit
import Foundation
import Testing
@testable import MessageListAppKitPlugin

@Suite(.serialized)
@MainActor
struct AppKitMarkdownLayoutTests {
    private let theme = AppKitMessageTheme.systemDefault()

    private func document(_ source: String) -> AppKitMarkdownDocument {
        AppKitMarkdownParser.parse(source)
    }

    @Test("短文本有确定高度且大于 0")
    func shortTextHeight() {
        let height = AppKitMarkdownView.measureHeight(
            document: document("Hello"),
            width: 600,
            theme: theme
        )
        #expect(height > 0)
        #expect(height < 100)
    }

    @Test("长 CJK 文本换行后高度大于单行")
    func longCJKWraps() {
        let long = String(repeating: "这是一段很长的中文文本用于测试换行与行高计算。", count: 8)
        let height = AppKitMarkdownView.measureHeight(
            document: document(long),
            width: 300,
            theme: theme
        )
        // 单行约 18pt；8 句 × 20 字 × 2 ≈ 320 字在 300pt 宽下应换行多次。
        #expect(height > 40)
    }

    @Test("宽度收窄时高度增加")
    func narrowerWidthIncreasesHeight() {
        let source = "Some reasonably long prose that will wrap differently at different widths."
        let wide = AppKitMarkdownView.measureHeight(document: document(source), width: 700, theme: theme)
        let narrow = AppKitMarkdownView.measureHeight(document: document(source), width: 200, theme: theme)
        #expect(narrow > wide)
    }

    @Test("标题块高度不低于正文")
    func headingIsAtLeastBodyHeight() {
        let headingHeight = AppKitMarkdownView.measureHeight(
            document: document("# Big Heading"), width: 600, theme: theme
        )
        let bodyHeight = AppKitMarkdownView.measureHeight(
            document: document("Body"), width: 600, theme: theme
        )
        #expect(headingHeight >= bodyHeight)
    }

    @Test("列表与引用渲染出确定高度")
    func listAndQuoteHeights() {
        let listHeight = AppKitMarkdownView.measureHeight(
            document: document("- item one\n- item two\n- item three"),
            width: 600,
            theme: theme
        )
        #expect(listHeight > 0)

        let quoteHeight = AppKitMarkdownView.measureHeight(
            document: document("> quoted line\n> second line"),
            width: 600,
            theme: theme
        )
        #expect(quoteHeight > 0)
    }

    @Test("测量确定性：同输入同输出")
    func measurementDeterminism() {
        let source = "# Title\n\nSome **bold** and *italic* with `code`."
        let a = AppKitMarkdownView.measureHeight(document: document(source), width: 400, theme: theme)
        let b = AppKitMarkdownView.measureHeight(document: document(source), width: 400, theme: theme)
        #expect(a == b)
    }

    @Test("视图无嵌套滚动视图，正文可选")
    func viewIsNotScrollableAndSelectable() {
        let view = AppKitMarkdownView(frame: .zero)
        view.render(
            document: document("Selectable **text** here"),
            width: 400,
            theme: theme
        )
        #expect(view.subviews.contains { $0 is NSScrollView } == false)

        let textView = view.subviews.first as? NSTextView
        #expect(textView?.isSelectable == true)
        #expect(textView?.isEditable == false)
        #expect(textView?.drawsBackground == false)
    }

    @Test("宽度变化触发一次重渲染并更新 frame 高度")
    func renderUpdatesFrameHeight() {
        let view = AppKitMarkdownView(frame: .zero)
        let source = String(repeating: "Word ", count: 40)
        view.render(document: document(source), width: 600, theme: theme)
        let tall = view.frame.height
        #expect(tall > 0)

        view.render(document: document(source), width: 150, theme: theme)
        #expect(view.frame.height > tall)
    }

    @Test("链接通过回调打开")
    func linkClickCallback() throws {
        let view = AppKitMarkdownView(frame: .zero)
        let expectation = LockedBox<URL?>(nil)
        view.render(
            document: document("Open [example](https://example.com) now"),
            width: 400,
            theme: theme
        ) { url in
            expectation.set(url)
        }

        let textView = view.subviews.first as? NSTextView
        let range = (textView?.string as NSString?)?.range(of: "example") ?? NSRange(location: 0, length: 0)
        guard range.location != NSNotFound else {
            Issue.record("link label not found")
            return
        }
        let attributes = textView?.textStorage?.attributes(at: range.location, effectiveRange: nil)
        let url = attributes?[.link] as? URL
        #expect(url?.absoluteString == "https://example.com")

        // 触发 delegate 点击回调。
        _ = view.textView(textView!, clickedOnLink: url ?? "", at: range.location)
        #expect(expectation.value?.absoluteString == "https://example.com")
    }
}

/// Minimal thread-safe box for capturing a value in a closure.
@MainActor
private final class LockedBox<T> {
    private var _value: T
    init(_ value: T) { _value = value }
    var value: T { _value }
    func set(_ value: T) { _value = value }
}
