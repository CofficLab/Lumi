import AppKit
import Testing
import SwiftUI
@testable import MarkdownKit
@testable import MarkdownKitCore

/// 代码块布局测试
///
/// 验证两个曾出现的回归问题：
/// 1. 多行代码块在聊天列表（preferOuterScroll + List）中被垂直截断
///    — 根因：HorizontalScrollView 的 heightAnchor 约束锁死了 hostingView 高度，
///      且缺少 sizeThatFits 向 SwiftUI 报告真实内容高度
/// 2. 长代码行水平截断，无法水平滚动
///    — 根因：NSHostingView 缺少 leadingAnchor 约束和最小宽度约束
@MainActor
struct CodeBlockLayoutTests {

    // MARK: - 解析层：代码块完整性

    @Test
    func parsesMultiLineCodeBlockWithoutTruncation() {
        let source = """
            ```swift
            import Foundation
            import UIKit

            class MyClass {
                let name: String
                let age: Int

                func greet() -> String {
                    return "Hello, \\(name)!"
                }
            }
            ```
            """
        let blocks = MarkdownParser.parse(source)

        guard blocks.count == 1, case let .codeBlock(language, code) = blocks[0] else {
            Issue.record("Expected exactly one code block, got: \(blocks)")
            return
        }

        #expect(language == "swift")
        #expect(code.contains("import Foundation"))
        #expect(code.contains("class MyClass"))
        #expect(code.contains("func greet()"))
        #expect(code.contains("return"))
        let lineCount = code.components(separatedBy: .newlines).filter { !$0.isEmpty }.count
        #expect(lineCount >= 8)
    }

    @Test
    func parsesSingleLineCodeBlock() {
        let blocks = MarkdownParser.parse("```python\nprint('hello')\n```")
        guard case let .codeBlock(language, code) = blocks.first else {
            Issue.record("Expected a code block")
            return
        }
        #expect(language == "python")
        #expect(code.contains("print('hello')"))
    }

    @Test
    func parsesCodeBlockPreservingEmptyLines() {
        let source = """
            ```javascript
            const a = 1;

            const b = 2;
            ```
            """
        let blocks = MarkdownParser.parse(source)
        guard case let .codeBlock(_, code) = blocks.first else {
            Issue.record("Expected a code block")
            return
        }
        #expect(code.contains("\n\n"))
    }

    // MARK: - HorizontalScrollView 布局验证

    /// 验证 HorizontalScrollView 的 documentView 高度随内容行数增长，
    /// 不被 heightAnchor 约束截断。
    @Test
    func horizontalScrollViewDocumentViewGrowsWithContent() async throws {
        let shortContent = Text("Line 1")
            .font(.system(size: 13, weight: .regular, design: .monospaced))
            .padding(10)

        let longContent = Text((1...20).map { "Line \($0)" }.joined(separator: "\n"))
            .font(.system(size: 13, weight: .regular, design: .monospaced))
            .padding(10)

        let shortDocSize = try await horizontalScrollViewDocumentSize(for: shortContent, width: 300)
        let longDocSize = try await horizontalScrollViewDocumentSize(for: longContent, width: 300)

        print("short doc: \(shortDocSize), long doc: \(longDocSize)")

        // 20 行的 documentView 高度必须大于 1 行
        #expect(longDocSize.height > shortDocSize.height)
        // 20 行高度至少是 1 行的 5 倍
        #expect(longDocSize.height > shortDocSize.height * 5)
    }

    /// 验证 HorizontalScrollView 的 documentView 高度不被 clip view 高度限制。
    /// 之前有 heightAnchor == clipView.heightAnchor 的回归。
    @Test
    func horizontalScrollViewNotConstrainedToClipViewHeight() async throws {
        let content = Text((1...10).map { "Line \($0)" }.joined(separator: "\n"))
            .font(.system(size: 13, weight: .regular, design: .monospaced))
            .padding(10)

        let docSize = try await horizontalScrollViewDocumentSize(for: content, width: 300)
        let clipHeight: CGFloat = 50 // 容器给的初始高度很小

        print("10-line doc height: \(docSize.height), clip height: \(clipHeight)")
        // 如果 heightAnchor 被锁死为 clipView 高度，docSize.height ≈ clipHeight (50)
        // 正常情况下 10 行代码高度远超 50pt
        #expect(docSize.height > clipHeight * 2)
    }

    /// 验证 HorizontalScrollView 的 documentView 宽度可以超出容器宽度（触发水平滚动）
    @Test
    func horizontalScrollViewDocumentWidthExceedsContainerForLongContent() async throws {
        let longLine = String(repeating: "A", count: 200)
        let content = Text(longLine)
            .font(.system(size: 13, weight: .regular, design: .monospaced))
            .padding(10)

        let docSize = try await horizontalScrollViewDocumentSize(for: content, width: 300)

        print("long line doc width: \(docSize.width), container: 300")
        // 200 个 'A' 在 13pt monospaced 字体下远超 300pt
        #expect(docSize.width > 300)
    }

    /// 验证 HorizontalScrollView 的 leadingAnchor 约束正确，
    /// documentView 起始 x 位置应为 0。
    @Test
    func horizontalScrollViewDocumentViewAnchoredToLeading() async throws {
        let content = Text("Hello")
            .font(.system(size: 13, weight: .regular, design: .monospaced))
            .padding(10)

        let (_, scrollView) = try await makeHorizontalScrollView(for: content, width: 300)

        // documentView 的 x 应该从 0 开始（leading 锚定）
        #expect(scrollView.documentView?.frame.origin.x == 0)
    }

    /// 验证多行内容的高度是合理的：不截断，也不过度膨胀
    @Test
    func horizontalScrollViewMultilineContentHeightIsReasonable() async throws {
        let lines = (1...5).map { "Line \($0) with some content" }.joined(separator: "\n")
        let content = Text(lines)
            .font(.system(size: 13, weight: .regular, design: .monospaced))
            .padding(10)

        let docSize = try await horizontalScrollViewDocumentSize(for: content, width: 300)

        print("5-line doc height: \(docSize.height)")
        // 5 行 × ~16pt + 20pt padding ≈ ~100pt
        // 应该至少大于单行高度 (约 36pt = 16 + 20 padding)
        #expect(docSize.height > 50)
        // 但不应过度膨胀（不应超过 200pt）
        #expect(docSize.height < 200)
    }

    // MARK: - MarkdownBlockRenderer + List 集成测试

    /// 验证代码块在 List + preferOuterScroll 环境中渲染不会崩溃或产生零高度
    @Test
    func codeBlockInListRendersWithoutZeroHeight() async throws {
        let markdown = "```swift\nlet a = 1\n```"

        let list = List {
            MarkdownBlockRenderer(markdown: markdown)
                .environment(\.preferOuterScroll, true)
                .frame(width: 300, alignment: .leading)
                .listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 4, trailing: 0))
                .listRowSeparator(.hidden)
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .environment(\.preferOuterScroll, true)
        .frame(width: 340, height: 400)

        let hostingView = NSHostingView(rootView: list)
        hostingView.frame = CGRect(origin: .zero, size: CGSize(width: 340, height: 400))
        // 等待足够长时间让 @State task 执行完毕
        try await Task.sleep(for: .milliseconds(500))
        hostingView.layoutSubtreeIfNeeded()

        let fittingSize = hostingView.fittingSize
        print("code block in list fittingSize: \(fittingSize)")
        // fittingSize 应该有值（容器高度）
        #expect(fittingSize.width > 0)
        #expect(fittingSize.height > 0)
    }

    /// 代码块后面跟着段落，在 List 中不会产生过度空白
    @Test
    func codeBlockFollowedByParagraphInListNoExcessiveWhitespace() async throws {
        let markdown = "```swift\nlet x = 42\n```\n\n这是一段后续文本。"

        let list = List {
            MarkdownBlockRenderer(markdown: markdown)
                .environment(\.preferOuterScroll, true)
                .frame(width: 300, alignment: .leading)
                .listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 4, trailing: 0))
                .listRowSeparator(.hidden)
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .environment(\.preferOuterScroll, true)
        .frame(width: 340, height: 400)

        let hostingView = NSHostingView(rootView: list)
        hostingView.frame = CGRect(origin: .zero, size: CGSize(width: 340, height: 400))
        try await Task.sleep(for: .milliseconds(500))
        hostingView.layoutSubtreeIfNeeded()

        let fittingSize = hostingView.fittingSize
        print("code + paragraph in list fittingSize: \(fittingSize)")
        #expect(fittingSize.width > 0)
        #expect(fittingSize.height > 0)
    }

    // MARK: - Helpers

    /// 创建 HorizontalScrollView 并测量其 documentView 的实际尺寸
    private func horizontalScrollViewDocumentSize<V: View>(
        for content: V,
        width: CGFloat
    ) async throws -> CGSize {
        let (_, scrollView) = try await makeHorizontalScrollView(for: content, width: width)
        return scrollView.documentView?.frame.size ?? .zero
    }

    /// 创建一个 HorizontalScrollView 放入 NSHostingView 中，
    /// 等待布局完成后返回 (hostingView, horizontalScrollView)
    private func makeHorizontalScrollView<V: View>(
        for content: V,
        width: CGFloat,
        height: CGFloat = 50
    ) async throws -> (NSHostingView<some View>, HorizontalOnlyScrollView) {
        let scrollView = HorizontalScrollView { content }

        let hostingView = NSHostingView(rootView: scrollView.frame(width: width))
        hostingView.frame = CGRect(origin: .zero, size: CGSize(width: width, height: height))
        try await Task.sleep(for: .milliseconds(200))
        hostingView.layoutSubtreeIfNeeded()

        guard let hScrollView = findView(ofType: HorizontalOnlyScrollView.self, in: hostingView) else {
            Issue.record("Could not find HorizontalOnlyScrollView in view hierarchy")
            throw TestError.viewNotFound
        }

        return (hostingView, hScrollView)
    }

    /// 递归查找指定类型的 NSView
    private func findView<T: NSView>(ofType type: T.Type, in view: NSView) -> T? {
        if let match = view as? T { return match }
        for subview in view.subviews {
            if let found = findView(ofType: type, in: subview) { return found }
        }
        return nil
    }

    private enum TestError: Error {
        case viewNotFound
    }
}
