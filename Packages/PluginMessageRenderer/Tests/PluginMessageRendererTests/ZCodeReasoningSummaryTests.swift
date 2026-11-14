import Foundation
import Testing
@testable import PluginMessageRenderer

/// ZCode reasoning 摘要提取（见 issue #1273）。
///
/// 摘要原先用 `components(separatedBy: .newlines)` 全量分割整段 reasoning，
/// 再逐行 trim 分配字符串。折叠态是默认态，且每次 body 求值都会重算，
/// 因此改成反向扫描找最后一个非空行。
///
/// 关键约束：**语义必须完全一致**，包括 CRLF 的处理。
struct ZCodeReasoningSummaryTests {

    /// 参照实现：原先的全量分割版本。
    private func referenceSummary(text: String) -> String? {
        let lines = text
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        return lines.last
    }

    @Test("与全量分割实现语义一致")
    func matchesReferenceImplementation() {
        let samples = [
            "",
            "   ",
            "\n\n\n",
            "single line",
            "first\nsecond\nthird",
            "first\n\n\nlast",
            "trailing\n   \n   ",
            "trailing\n\t \t",
            "中文\n第二行\n第三行",
            "line with  spaces  inside",
            "a\nb\r\nc",
            "\r\n\r\nvalue",
            "multi\nline\n\n\n\nend",
            "no trailing newline\n",
            "\nleading newline\nsecond"
        ]

        for sample in samples {
            let expected = referenceSummary(text: sample)
            let actual = ZCodeReasoningStyle.summary(text: sample)
            #expect(actual == expected, "sample: \(sample.debugDescription)")
        }
    }

    @Test("空内容返回 nil")
    func emptyContentReturnsNil() {
        #expect(ZCodeReasoningStyle.summary(text: "") == nil)
        #expect(ZCodeReasoningStyle.summary(text: "   \n\t ") == nil)
    }

    @Test("取最后一个非空行")
    func picksLastNonEmptyLine() {
        #expect(ZCodeReasoningStyle.summary(text: "a\nb\nc") == "c")
        #expect(ZCodeReasoningStyle.summary(text: "a\n\n\nb") == "b")
    }

    @Test("首尾空白被去掉")
    func trimsSurroundingWhitespace() {
        #expect(ZCodeReasoningStyle.summary(text: "  indented  ") == "indented")
        #expect(ZCodeReasoningStyle.summary(text: "a\n   last   ") == "last")
    }

    @Test("CRLF 行尾按两个分隔符处理")
    func handlesCRLF() {
        // `components(separatedBy: .newlines)` 会把 CRLF 拆成两个分隔符，
        // 因此 CRLF 之后的那一行才是最后一行。
        #expect(ZCodeReasoningStyle.summary(text: "a\r\nb") == "b")
    }
}
