import Testing
import Foundation
@testable import KitShell

/// Regression for #172: the streaming text path decoded each raw `Data` chunk
/// independently, so a multibyte character split across two chunks was dropped
/// from the live callback (the byte callback and final aggregate kept it).
@Suite("Shell streaming UTF-8")
struct ShellStreamingUTF8Tests {

    // MARK: - End-to-end through the real subprocess chain

    @Test("流式回调不得丢弃跨 chunk 拆分的多字节字符（emoji）")
    func streamingPreservesMultibyteCharSplitAcrossChunks() async throws {
        let live = LockedText()
        // U+1F600 😀 = F0 9F 98 80. Write the lead byte, pause so it lands in
        // its own chunk, then write the three continuation bytes.
        let result = try await ShellExecutor.executeStreaming(
            "printf '\\360'; sleep 0.2; printf '\\237\\230\\200'",
            onOutput: { live.append($0) }
        )

        #expect(result.stdout == "\u{1F600}")
        #expect(live.value.contains("\u{1F600}"), "live text dropped the split character: \(live.value)")
    }

    @Test("流式 stderr 回调不得丢弃跨 chunk 拆分的多字节字符")
    func streamingPreservesSplitMultibyteOnStderr() async throws {
        let live = LockedText()
        let result = try await ShellExecutor.executeStreaming(
            "printf '\\360' >&2; sleep 0.2; printf '\\237\\230\\200' >&2",
            onOutput: { _ in },
            onError: { live.append($0) }
        )

        #expect(result.stderr == "\u{1F600}")
        #expect(live.value.contains("\u{1F600}"), "live stderr dropped the split character: \(live.value)")
    }

    @Test("流式回调不得丢弃跨 chunk 拆分的三字节字符（中文）")
    func streamingPreservesSplitChineseCharacter() async throws {
        let live = LockedText()
        // U+4E2D 中 = E4 B8 AD.
        let result = try await ShellExecutor.executeStreaming(
            "printf '\\344'; sleep 0.2; printf '\\270\\255'",
            onOutput: { live.append($0) }
        )

        #expect(result.stdout == "\u{4E2D}")
        #expect(live.value.contains("\u{4E2D}"), "live text dropped the split character: \(live.value)")
    }

    // MARK: - Decoder unit tests (deterministic, no subprocess timing)

    @Test("解码器必须拼接跨 chunk 的四字节序列")
    func decoderJoinsFourByteSequenceSplitAcrossChunks() {
        let decoder = StreamingUTF8Decoder()
        #expect(decoder.decode(Data([0xF0])) == nil)
        #expect(decoder.decode(Data([0x9F, 0x98, 0x80])) == "\u{1F600}")
        #expect(decoder.flush() == nil)
    }

    @Test("解码器必须拼接跨 chunk 的三字节序列")
    func decoderJoinsThreeByteSequenceSplitAcrossChunks() {
        let decoder = StreamingUTF8Decoder()
        #expect(decoder.decode(Data([0xE4])) == nil)
        #expect(decoder.decode(Data([0xB8, 0xAD])) == "\u{4E2D}")
    }

    @Test("解码器立即输出 ASCII")
    func decoderEmitsAsciiImmediately() {
        let decoder = StreamingUTF8Decoder()
        #expect(decoder.decode(Data("hi".utf8)) == "hi")
    }

    @Test("解码器在 EOF 把不完整的尾部替换为 U+FFFD")
    func decoderFlushReplacesIncompleteTailAtEOF() {
        let decoder = StreamingUTF8Decoder()
        #expect(decoder.decode(Data([0xF0])) == nil)
        #expect(decoder.flush() == "\u{FFFD}")
        // Residue is consumed; a second flush yields nothing.
        #expect(decoder.flush() == nil)
    }

    @Test("解码器遇到非法字节不得卡死，后续合法输入仍能解出")
    func decoderDoesNotStallOnInvalidBytes() {
        let decoder = StreamingUTF8Decoder()
        let text = decoder.decode(Data([0xFF, 0x41]))
        #expect(text == "\u{FFFD}A")
        #expect(decoder.decode(Data("ok".utf8)) == "ok")
    }

    @Test("解码器逐字节喂入多字符仍拼出完整文本")
    func decoderHandlesManyChunksAndMultipleCharacters() {
        let decoder = StreamingUTF8Decoder()
        var collected = ""
        for byte in [UInt8](Array("\u{1F600}ok".utf8)) {
            if let piece = decoder.decode(Data([byte])) {
                collected += piece
            }
        }
        if let tail = decoder.flush() { collected += tail }
        #expect(collected == "\u{1F600}ok")
    }

    @Test("解码器保留拆分字符前的 ASCII 前缀，只缓冲不完整尾部")
    func decoderPreservesAsciiAroundSplitCharacter() {
        let decoder = StreamingUTF8Decoder()
        #expect(decoder.decode(Data([0x61, 0xF0])) == "a")
        #expect(decoder.decode(Data([0x9F, 0x98, 0x80, 0x62])) == "\u{1F600}b")
    }
}

private final class LockedText: @unchecked Sendable {
    private let lock = NSLock()
    private var text = ""

    var value: String {
        lock.lock()
        defer { lock.unlock() }
        return text
    }

    func append(_ value: String) {
        lock.lock()
        text += value
        lock.unlock()
    }
}
