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
    func parsesMultipleFallbackStrongSegments() {
        let attributed = MarkdownInlineParser.parse("中文**“第一段”**以及**（第二段）**结束")

        #expect(containsStrongRun(in: attributed, text: "“第一段”"))
        #expect(containsStrongRun(in: attributed, text: "（第二段）"))
        #expect(String(attributed.characters) == "中文“第一段”以及（第二段）结束")
    }

    @Test
    func parsesPunctuationStartedStrongSegmentsAfterCJKText() {
        let samples = [
            ("一个**“加粗”**。", "“加粗”"),
            ("一个**（加粗）**。", "（加粗）"),
            ("一个**《加粗》**。", "《加粗》"),
            ("一个**:加粗**。", ":加粗"),
        ]

        for sample in samples {
            let attributed = MarkdownInlineParser.parse(sample.0)
            #expect(containsStrongRun(in: attributed, text: sample.1))
        }
    }

    @Test
    func preservesUnclosedStrongDelimiterAsPlainText() {
        let text = "中文**“未闭合”。"
        let attributed = MarkdownInlineParser.parse(text)

        #expect(String(attributed.characters) == text)
        #expect(!containsStrongRun(in: attributed, text: "“未闭合”。"))
    }

    @Test
    func preservesEmptyStrongDelimiterAsPlainText() {
        let text = "中文****结束"
        let attributed = MarkdownInlineParser.parse(text)

        #expect(String(attributed.characters) == text)
        #expect(!attributed.runs.contains { $0.inlinePresentationIntent == .stronglyEmphasized })
    }

    @Test
    func preservesWhitespaceOnlyStrongDelimiterAsPlainText() {
        let text = "中文**   **结束"
        let attributed = MarkdownInlineParser.parse(text)

        #expect(String(attributed.characters) == text)
        #expect(!attributed.runs.contains { $0.inlinePresentationIntent == .stronglyEmphasized })
    }

    @Test
    func preservesNativeMarkdownParsingWhenItAlreadyWorks() throws {
        let attributed = MarkdownInlineParser.parse("这是一段 **加粗** 文本。")

        #expect(containsStrongRun(in: attributed, text: "加粗"))
    }

    @Test
    func preservesNativeInlineCodeParsingWhenItAlreadyWorks() {
        let attributed = MarkdownInlineParser.parse("使用 `code` 和 **加粗**。")

        #expect(containsStrongRun(in: attributed, text: "加粗"))
        #expect(attributed.runs.contains { run in
            run.inlinePresentationIntent == .code && String(attributed.characters[run.range]) == "code"
        })
    }

    @Test
    func preservesNativeLinkParsingWhenItAlreadyWorks() {
        let attributed = MarkdownInlineParser.parse("查看 [Lumi](https://example.com) 和 **加粗**。")

        #expect(containsStrongRun(in: attributed, text: "加粗"))
        #expect(attributed.runs.contains { run in
            run.link?.absoluteString == "https://example.com" && String(attributed.characters[run.range]) == "Lumi"
        })
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
