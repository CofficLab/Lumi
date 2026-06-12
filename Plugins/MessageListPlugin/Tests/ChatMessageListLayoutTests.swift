import MarkdownKitTesting
import SwiftUI
import Testing
@testable import MessageListPlugin

@MainActor
struct ChatMessageListLayoutTests {

    @Test
    func prefersOuterScrollForMarkdownIsEnabled() {
        #expect(ChatMessageListLayout.prefersOuterScrollForMarkdown)
    }

    @Test
    func chatListLayoutMatchesMarkdownKitChatStyleFixture() {
        #expect(ChatMessageListLayout.messageRowInsets == MarkdownLayoutTestSupport.chatListRowInsets)
    }

    @Test
    func multiLineCodeBlockKeepsHeightInChatStyledScrollRow() async throws {
        let markdown = """
            ```swift
            \(Array(1...12).map { "let value\($0) = \($0)" }.joined(separator: "\n"))
            ```

            Bottom paragraph in assistant reply.
            """

        let standaloneHeight = try await MarkdownLayoutTestSupport.standaloneMarkdownHeight(
            markdown: markdown,
            preferOuterScroll: ChatMessageListLayout.prefersOuterScrollForMarkdown,
            settleMilliseconds: 300
        )
        let scrollRowHeight = try await MarkdownLayoutTestSupport.markdownRowContentHeightInChatScroll(
            markdown: markdown,
            preferOuterScroll: ChatMessageListLayout.prefersOuterScrollForMarkdown,
            settleMilliseconds: 300
        )

        #expect(scrollRowHeight >= standaloneHeight * 0.85)
        #expect(scrollRowHeight > 80)
    }
}
