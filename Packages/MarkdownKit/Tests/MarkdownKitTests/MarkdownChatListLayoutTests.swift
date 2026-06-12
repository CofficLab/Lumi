import MarkdownKitTesting
import Testing
import SwiftUI
@testable import MarkdownKit

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
}
