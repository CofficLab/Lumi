import Foundation
import Testing
@testable import EditorKernel

/// 编辑器正文的轻量文本统计（见 issue #1329）。
struct EditorTextMetricsTests {

    @Test("换行统计与 filter 语义一致")
    func newlineCountMatchesFilterSemantics() {
        let samples = [
            "",
            "a",
            "a\n",
            "\n",
            "\n\n",
            "a\nb\nc",
            "第一行\n第二行\n第三行",
            "trailing\r\nwindows\r\nnewlines\r\n",
            "emoji 😀\nline"
        ]

        for sample in samples {
            let expected = sample.filter { $0 == "\n" }.count
            #expect(EditorTextMetrics.newlineCount(in: sample) == expected, "sample: \(sample.debugDescription)")
        }
    }

    @Test("总行数与 filter + 1 语义一致")
    func totalLineCountMatchesFilterPlusOne() {
        let samples = ["", "a", "a\n", "\n\n", "a\nb\nc", "第一行\n第二行"]

        for sample in samples {
            let expected = sample.filter { $0 == "\n" }.count + 1
            #expect(EditorTextMetrics.totalLineCount(in: sample) == expected, "sample: \(sample.debugDescription)")
        }
    }

    @Test("空正文算一行")
    func emptyContentIsOneLine() {
        #expect(EditorTextMetrics.totalLineCount(in: "") == 1)
    }

    @Test("CRLF 组合不单独计数，与既有 filter 语义一致")
    func carriageReturnFollowedByNewlineIsNotCounted() {
        // Swift 把 `\r\n` 视作单个 Character，因此紧跟 `\r` 的 `\n` 不计入换行数。
        // 字节扫描必须复刻这一规则，否则会改变 CRLF 文件的行数统计结果。
        #expect(EditorTextMetrics.newlineCount(in: "a\r\nb") == 0)
        #expect(EditorTextMetrics.newlineCount(in: "a\rb") == 0)
        #expect(EditorTextMetrics.newlineCount(in: "a\nb") == 1)
    }
}
