import Foundation
import Testing
@testable import MarkdownKit

struct MarkdownInlineParserTests {

    // MARK: - Strong Emphasis

    @Test
    func parsesStrongTextAfterChineseWithoutWhitespace() {
        let attributed = MarkdownInlineParser.parse(
            "如果你要，我下一步可以直接帮你画一个**“哪些文件可迁移到哪个 package”的分层图**。"
        )

        #expect(
            containsStrongRun(
                in: attributed,
                text: "“哪些文件可迁移到哪个 package”的分层图"
            )
        )
    }

    @Test
    func preservesNativeMarkdownParsingWhenItAlreadyWorks() throws {
        let attributed = MarkdownInlineParser.parse("这是一段 **加粗** 文本。")

        #expect(containsStrongRun(in: attributed, text: "加粗"))
    }

    @Test
    func preservesPlainTextWhenNoMarkdownExists() {
        let text = "这是一段普通文本。"
        let attributed = MarkdownInlineParser.parse(text)

        #expect(String(attributed.characters) == text)
        #expect(!attributed.runs.contains { $0.inlinePresentationIntent != nil })
    }

    // MARK: - Helpers

    private func containsStrongRun(in attributed: AttributedString, text: String) -> Bool {
        attributed.runs.contains { run in
            run.inlinePresentationIntent == .stronglyEmphasized
                && String(attributed.characters[run.range]) == text
        }
    }
}
