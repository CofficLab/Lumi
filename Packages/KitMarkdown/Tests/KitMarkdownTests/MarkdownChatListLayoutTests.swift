import KitMarkdownTesting
import Testing
import SwiftUI
@testable import KitMarkdown

/// Regression tests for markdown body truncation in chat-style scroll containers.
@MainActor
struct MarkdownChatListLayoutTests {

    private static let multiLineCodeMarkdown = """
        ```swift
        \(Array(1...15).map { "let line\($0) = \($0)" }.joined(separator: "\n"))
        ```

        Trailing paragraph after the code block.
        """

    @Test
    func multiLineCodeBlockInChatScrollMatchesStandaloneHeight() async throws {
        let standaloneHeight = try await MarkdownLayoutTestSupport.standaloneMarkdownHeight(
            markdown: Self.multiLineCodeMarkdown,
            preferOuterScroll: true,
            settleMilliseconds: 200
        )
        let scrollRowHeight = try await MarkdownLayoutTestSupport.markdownRowContentHeightInChatScroll(
            markdown: Self.multiLineCodeMarkdown,
            preferOuterScroll: true,
            settleMilliseconds: 200
        )

        #expect(scrollRowHeight >= standaloneHeight * 0.85)
        #expect(scrollRowHeight > 80)
    }

    @Test
    func multiLineCodeBlockDocumentViewGrowsInsideHorizontalScrollView() async throws {
        let lines = (1...12).map { "let item\($0) = \($0)" }.joined(separator: "\n")
        let markdown = "```swift\n\(lines)\n```"
        // headless 宿主会取消 `.task`,预热保证首帧同步可用(生产由消息列表预热)
        MarkdownRenderCache.warm(markdown: markdown)

        let documentSize = try await MarkdownLayoutTestSupport.horizontalScrollViewDocumentSize(
            for: Text(lines)
                .font(.system(size: 13, weight: .regular, design: .monospaced))
                .padding(10),
            width: 300
        )
        let standaloneHeight = try await MarkdownLayoutTestSupport.standaloneMarkdownHeight(
            markdown: markdown,
            preferOuterScroll: true,
            settleMilliseconds: 200
        )

        #expect(documentSize.height > 60)
        #expect(standaloneHeight > 60)
    }

    @Test
    func preferOuterScrollStandaloneCodeBlockIsNotTruncated() async throws {
        let lines = (1...10).map { "Line \($0)" }.joined(separator: "\n")
        let markdown = "```swift\n\(lines)\n```"
        MarkdownRenderCache.warm(markdown: markdown)

        let withOuterScroll = try await MarkdownLayoutTestSupport.standaloneMarkdownHeight(
            markdown: markdown,
            preferOuterScroll: true,
            settleMilliseconds: 200
        )
        let withoutOuterScroll = try await MarkdownLayoutTestSupport.standaloneMarkdownHeight(
            markdown: markdown,
            preferOuterScroll: false,
            settleMilliseconds: 200
        )

        #expect(withOuterScroll > 80)
        #expect(withoutOuterScroll >= withOuterScroll * 0.85)
    }

    @Test
    func codeBlockFollowedByParagraphRetainsBottomContentHeight() async throws {
        let markdown = "```swift\nlet x = 42\n```\n\nBottom paragraph that must not be clipped."

        let standaloneHeight = try await MarkdownLayoutTestSupport.standaloneMarkdownHeight(
            markdown: markdown,
            preferOuterScroll: true,
            settleMilliseconds: 200
        )
        let scrollRowHeight = try await MarkdownLayoutTestSupport.markdownRowContentHeightInChatScroll(
            markdown: markdown,
            preferOuterScroll: true,
            settleMilliseconds: 200
        )

        #expect(scrollRowHeight >= standaloneHeight * 0.85)
    }

    @Test
    func legacyTableCellTextDoesNotWrapOneCharacterPerLine() async throws {
        let markdown = """
            | 步骤 | 动作 | 说明 |
            | --- | --- | --- |
            | 1 | 创建共享包 | 保持旧主题表格正常显示 |
            """
        MarkdownRenderCache.warm(markdown: markdown)

        let height = try await MarkdownLayoutTestSupport.standaloneMarkdownHeight(
            markdown: markdown,
            width: 360,
            preferOuterScroll: true,
            settleMilliseconds: 200
        )

        #expect(height > 0)
        #expect(height < 120, "表头和一行数据不应逐字换行，实际高度为 \(height)")
    }
}
