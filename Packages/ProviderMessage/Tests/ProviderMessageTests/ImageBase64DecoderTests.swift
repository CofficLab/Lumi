import Foundation
import Testing
@testable import ProviderMessage

/// 图片 Base64 解码缓存的行为契约（Issue #1268）。
///
/// 核心诉求：一次会话的多个 LLM step 不再重复解码同一批历史图片，
/// 同时**解码结果必须与直接解码逐字节一致**。
@Suite("ImageBase64Decoder 图片解码缓存")
struct ImageBase64DecoderTests {

    // MARK: - 正确性

    @Test("解码结果与 Data(base64Encoded:) 完全一致")
    func decodedResultMatchesDirectDecoding() throws {
        let decoder = ImageBase64Decoder()
        let data = Data(repeating: 0x42, count: 4096)
        let base64 = data.base64EncodedString()

        let decoded = try #require(decoder.decode(base64))

        #expect(decoded == data)
    }

    @Test("缓存命中返回与首次一致的结果")
    func cachedDecodeReturnsSameResult() throws {
        let decoder = ImageBase64Decoder()
        let data = Data(repeating: 0x33, count: 2048)
        let base64 = data.base64EncodedString()

        let first = try #require(decoder.decode(base64))
        let second = try #require(decoder.decode(base64))

        #expect(first == second)
        #expect(first == data)
    }

    @Test("内容相同的不同字符串实例命中同一条缓存")
    func distinctInstancesWithSameContentReuseEntry() throws {
        let decoder = ImageBase64Decoder()
        let bytes = [UInt8](repeating: 0x11, count: 2048)
        let base64 = Data(bytes).base64EncodedString()

        let first = try #require(decoder.decode(base64))
        let second = try #require(decoder.decode(String(base64)))

        #expect(first == second)
        // 内容一致即视为同一张图，不应产生第二条条目。
        #expect(decoder.statistics.entries == 1)
    }

    @Test("不同内容的图片不会互相污染")
    func differentContentDoesNotCollide() throws {
        let decoder = ImageBase64Decoder()
        let first = Data(repeating: 0x01, count: 1024).base64EncodedString()
        let second = Data(repeating: 0x02, count: 1024).base64EncodedString()

        let firstDecoded = try #require(decoder.decode(first))
        let secondDecoded = try #require(decoder.decode(second))

        #expect(firstDecoded == Data(repeating: 0x01, count: 1024))
        #expect(secondDecoded == Data(repeating: 0x02, count: 1024))
        #expect(firstDecoded != secondDecoded)
    }

    @Test("非法 base64 返回 nil")
    func rejectsInvalidBase64() {
        let decoder = ImageBase64Decoder()

        #expect(decoder.decode("not valid base64!!!") == nil)
    }

    @Test("空字符串返回 nil")
    func rejectsEmptyString() {
        let decoder = ImageBase64Decoder()

        #expect(decoder.decode("") == nil)
    }

    @Test("非法 base64 不占用缓存条目")
    func invalidInputDoesNotCreateEntry() {
        let decoder = ImageBase64Decoder()

        _ = decoder.decode("!!!not base64!!!")

        #expect(decoder.statistics.entries == 0)
    }

    @Test("空字符串不占用缓存条目")
    func emptyStringDoesNotCreateEntry() {
        let decoder = ImageBase64Decoder()

        _ = decoder.decode("")

        #expect(decoder.statistics.entries == 0)
    }

    // MARK: - 有界性

    @Test("条目数超过上限时被淘汰")
    func evictsWhenEntryLimitExceeded() {
        let decoder = ImageBase64Decoder(maxEntries: 4, maxTotalBytes: .max)

        for index in 0..<20 {
            _ = decoder.decode(Data(repeating: UInt8(index), count: 64).base64EncodedString())
        }

        #expect(decoder.statistics.entries <= 4)
    }

    @Test("累计字节数超过上限时被淘汰")
    func evictsWhenByteLimitExceeded() {
        let decoder = ImageBase64Decoder(maxEntries: .max, maxTotalBytes: 300)

        for index in 0..<20 {
            _ = decoder.decode(Data(repeating: UInt8(index), count: 64).base64EncodedString())
        }

        #expect(decoder.statistics.bytes <= 300)
    }

    @Test("淘汰后重新解码仍得到正确结果")
    func evictedEntriesStillDecodeCorrectly() throws {
        let decoder = ImageBase64Decoder(maxEntries: 2, maxTotalBytes: .max)
        let first = Data(repeating: 0x07, count: 128).base64EncodedString()
        let second = Data(repeating: 0x08, count: 128).base64EncodedString()

        _ = decoder.decode(first)
        _ = decoder.decode(second)
        // 触发淘汰。
        _ = decoder.decode(Data(repeating: 0x09, count: 128).base64EncodedString())

        #expect(try #require(decoder.decode(first)) == Data(repeating: 0x07, count: 128))
        #expect(try #require(decoder.decode(second)) == Data(repeating: 0x08, count: 128))
    }

    @Test("清空缓存后统计归零")
    func removeAllResetsStatistics() {
        let decoder = ImageBase64Decoder()
        _ = decoder.decode(Data(repeating: 0x05, count: 512).base64EncodedString())

        #expect(decoder.statistics.entries == 1)

        decoder.removeAll()

        #expect(decoder.statistics.entries == 0)
        #expect(decoder.statistics.bytes == 0)
    }

    // MARK: - 性能回归

    @Test("重复解码同一张图片的耗时显著低于首次解码")
    func repeatedDecodeIsCheaperThanFirstDecode() {
        // 1 MB 级图片：工具把截图塞进结果并不罕见。
        let data = Data(repeating: 0x5A, count: 1_000_000)
        let base64 = data.base64EncodedString()
        let decoder = ImageBase64Decoder()

        // 预热：把图片放进缓存。
        _ = decoder.decode(base64)

        let iterations = 30

        let firstStart = DispatchTime.now().uptimeNanoseconds
        for _ in 0..<iterations {
            _ = Data(base64Encoded: base64)
        }
        let firstElapsed = DispatchTime.now().uptimeNanoseconds - firstStart

        let cachedStart = DispatchTime.now().uptimeNanoseconds
        for _ in 0..<iterations {
            _ = decoder.decode(base64)
        }
        let cachedElapsed = DispatchTime.now().uptimeNanoseconds - cachedStart

        // 命中缓存必须明显更快；放宽到「至少快 2 倍」以稳定抓住回归。
        #expect(cachedElapsed * 2 < firstElapsed)
    }
}
