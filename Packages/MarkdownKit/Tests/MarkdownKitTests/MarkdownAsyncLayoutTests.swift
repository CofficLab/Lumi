import MarkdownKitCore
import MarkdownKitTesting
import Testing
import SwiftUI
@testable import MarkdownKit

/// Verifies markdown layout is available on first render and stable in chat-style scroll rows.
@MainActor
struct MarkdownAsyncLayoutTests {

    @Test
    func markdownRendererInitializesWithSynchronouslyParsedBlocks() async throws {
        let markdown = """
            ## Heading

            - Bullet one
            - Bullet two

            Closing paragraph.
            """
        let parsedBlocks = MarkdownParser.parse(markdown)
        #expect(!parsedBlocks.isEmpty)

        let height = try await MarkdownLayoutTestSupport.standaloneMarkdownHeight(
            markdown: markdown,
            settleMilliseconds: 100
        )
        #expect(height > 80)
    }

    @Test
    func markdownInChatScrollMatchesStandaloneHeight() async throws {
        let markdown = """
            ## Section

            \(Array(1...12).map { "- Item \($0) with detail" }.joined(separator: "\n"))

            Closing paragraph that should remain visible at the bottom.
            """

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
    func markdownInChatScrollHeightIsStableShortlyAfterMount() async throws {
        let markdown = """
            ## Heading

            \(Array(1...10).map { "- Bullet \($0) with supporting detail" }.joined(separator: "\n"))

            Closing paragraph after mount.
            """

        let earlyHeight = try await MarkdownLayoutTestSupport.markdownRowContentHeightInChatScroll(
            markdown: markdown,
            preferOuterScroll: true,
            settleMilliseconds: 50
        )
        let lateHeight = try await MarkdownLayoutTestSupport.markdownRowContentHeightInChatScroll(
            markdown: markdown,
            preferOuterScroll: true,
            settleMilliseconds: 200
        )

        #expect(earlyHeight > 80)
        #expect(abs(lateHeight - earlyHeight) < 30)
    }
}
