import Foundation
import Testing
@testable import PluginConversationTitle

/// 标题占位符的有界前缀（见 issue #1287）。
///
/// 原先对全量消息跑一次 ICU 正则（`\s+` → 空格），代价是 O(全文长度)，
/// 而结果只需要 40 个字符。修复后先取有界前缀再折叠空白，
/// 语义必须与「全量折叠再截断」完全一致。
@Suite("标题占位符的空白折叠")
struct PlaceholderTitleCollapsingTests {

    /// 参照实现：原先的全量折叠。
    private func referenceTitle(_ text: String) -> String {
        let collapsed = text
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard collapsed.count > 40 else { return collapsed }
        let end = collapsed.index(collapsed.startIndex, offsetBy: 40)
        return String(collapsed[..<end]) + "…"
    }

    @Test("短文本与参照实现一致")
    func shortTextMatchesReference() {
        let samples = [
            "hi",
            "第一行\n第二行\t第三行",
            "  \n ",
            "a b  c",
            "line1\n\nline2\n\n\nline3"
        ]
        for sample in samples {
            #expect(
                AutoConversationTitleService.placeholderTitle(forFirstUserMessage: sample)
                    == referenceTitle(sample),
                "sample: \(sample.debugDescription)"
            )
        }
    }

    @Test("长文本与参照实现一致")
    func longTextMatchesReference() {
        // 正常长度的空白（折叠后不会丢字符）。
        let dense = String(repeating: "word ", count: 500)
        #expect(
            AutoConversationTitleService.placeholderTitle(forFirstUserMessage: dense)
                == referenceTitle(dense)
        )

        // 长文本 + 大量空白：折叠会大幅缩短，必须仍与参照一致。
        let mixed = String(repeating: "a \n\t ", count: 500)
        #expect(
            AutoConversationTitleService.placeholderTitle(forFirstUserMessage: mixed)
                == referenceTitle(mixed)
        )
    }

    @Test("极长空白串仍与参照实现一致")
    func extremelyWhitespaceHeavyMatchesReference() {
        // 全是空白：折叠后只剩一个空格。
        let blank = String(repeating: " ", count: 5000)
        #expect(
            AutoConversationTitleService.placeholderTitle(forFirstUserMessage: blank)
                == referenceTitle(blank)
        )
    }

    @Test("结果长度有界")
    func resultLengthIsBounded() {
        let long = String(repeating: "x", count: 100_000)
        let result = AutoConversationTitleService.placeholderTitle(forFirstUserMessage: long)

        #expect(result.count <= 41)
        #expect(result.hasSuffix("…"))
    }
}
