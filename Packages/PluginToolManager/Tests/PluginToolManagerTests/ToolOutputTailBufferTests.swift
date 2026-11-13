import Foundation
import Testing
@testable import PluginToolManager

/// 工具输出尾部的字节缓冲（见 issue #1310）。
///
/// 原先每次 chunk 都执行 `Data(job.latestOutput.utf8) + data`，
/// 每次都要把整个 64 KiB 尾重新编码成字节再拼接，
/// 总代价是 O(chunk 数 × 尾部字节数)。
@Suite("工具输出尾部缓冲")
struct ToolOutputTailBufferTests {

    /// 参照实现：原先的「重新编码 + 拼接 + 取尾」。
    private func referenceTail(
        _ current: String,
        appending chunk: String,
        maxBytes: Int
    ) -> String {
        let combined = Data(current.utf8) + Data(chunk.utf8)
        return String(decoding: combined.suffix(maxBytes), as: UTF8.self)
    }

    @Test("追加后与参照实现一致")
    func matchesReferenceImplementation() {
        let maxBytes = 64 * 1024
        var buffer = ToolExecutionManager.OutputTailBuffer(maxBytes: maxBytes)
        var reference = ""

        let chunks = ["hello ", "world ", "more output ", "tail"]
        for chunk in chunks {
            buffer.append(Data(chunk.utf8))
            reference = referenceTail(reference, appending: chunk, maxBytes: maxBytes)
            #expect(buffer.string == reference)
        }
    }

    @Test("超出预算时保留尾部")
    func keepsTailWhenOverBudget() {
        var buffer = ToolExecutionManager.OutputTailBuffer(maxBytes: 8)
        buffer.append(Data("0123456789ABCDEF".utf8))

        #expect(buffer.string == "89ABCDEF")
    }

    @Test("单块超过预算时只保留该块尾部")
    func singleOversizedChunkKeepsItsTail() {
        var buffer = ToolExecutionManager.OutputTailBuffer(maxBytes: 4)
        buffer.append(Data("ABCDEFGH".utf8))

        #expect(buffer.string == "EFGH")
    }

    @Test("初始化内容超出预算时截断")
    func initialContentIsTruncated() {
        var buffer = ToolExecutionManager.OutputTailBuffer(maxBytes: 4, initial: Data("ABCDEFGH".utf8))

        #expect(buffer.string == "EFGH")
    }

    @Test("空追加不改变内容")
    func emptyAppendIsNoop() {
        var buffer = ToolExecutionManager.OutputTailBuffer(maxBytes: 8)
        buffer.append(Data("abc".utf8))
        buffer.append(Data())

        #expect(buffer.string == "abc")
    }

    @Test("多字节字符按字节截断，与参照实现一致")
    func truncatesOnByteBoundary() {
        var buffer = ToolExecutionManager.OutputTailBuffer(maxBytes: 4)
        buffer.append(Data("中文".utf8)) // 6 字节

        // 截断可能落在多字节字符中间，解码时非法序列被替换为 U+FFFD，
        // 因此解码后的字节数可能超过预算 —— 这与原实现一致。
        let expected = referenceTail("", appending: "中文", maxBytes: 4)
        #expect(buffer.string == expected)
    }
}
