import Foundation
import Testing
@testable import KitLLM

/// 图片 Base64 缓存的行为契约（Issue #1269）。
///
/// 核心诉求：一次会话内多次 LLM step 不再重复编码同一张历史图片，
/// 同时缓存必须是有界的，不能因为长会话里的大量截图把内存吃满。
@Suite("ImageBase64Cache 图片 Base64 编码缓存")
struct ImageBase64CacheTests {

    // MARK: - 正确性

    @Test("缓存命中返回与直接编码完全一致的 Base64")
    func cachedResultMatchesDirectEncoding() {
        let cache = ImageBase64Cache()
        let data = Data(repeating: 0xAB, count: 4096)

        let first = cache.base64(for: data)
        let second = cache.base64(for: data)

        #expect(first == data.base64EncodedString())
        #expect(second == first)
    }

    @Test("内容相同的不同 Data 实例命中同一条缓存")
    func distinctInstancesWithSameContentReuseEntry() {
        let cache = ImageBase64Cache()
        let bytes = [UInt8](repeating: 0x11, count: 2048)

        let first = cache.base64(for: Data(bytes))
        let second = cache.base64(for: Data(bytes))

        #expect(first == second)
        // 内容一致即视为同一张图，不应产生第二条条目。
        #expect(cache.statistics.entries == 1)
    }

    @Test("不同内容的图片不会互相污染")
    func differentContentDoesNotCollide() {
        let cache = ImageBase64Cache()
        let first = Data(repeating: 0x01, count: 1024)
        let second = Data(repeating: 0x02, count: 1024)

        let firstEncoded = cache.base64(for: first)
        let secondEncoded = cache.base64(for: second)

        #expect(firstEncoded == first.base64EncodedString())
        #expect(secondEncoded == second.base64EncodedString())
        #expect(firstEncoded != secondEncoded)
    }

    @Test("空图片直接编码且不占用缓存条目")
    func emptyDataIsEncodedDirectly() {
        let cache = ImageBase64Cache()

        #expect(cache.base64(for: Data()) == "")
        #expect(cache.statistics.entries == 0)
    }

    @Test("单字节与极小图片同样得到正确结果")
    func tinyDataProducesCorrectEncoding() {
        let cache = ImageBase64Cache()
        let data = Data([0x00])

        #expect(cache.base64(for: data) == data.base64EncodedString())
    }

    // MARK: - 有界性

    @Test("条目数超过上限时被淘汰")
    func evictsWhenEntryLimitExceeded() {
        let cache = ImageBase64Cache(maxEntries: 4, maxTotalCharacters: .max)

        for index in 0..<10 {
            cache.base64(for: Data(repeating: UInt8(index), count: 64))
        }

        #expect(cache.statistics.entries <= 4)
    }

    @Test("累计字符数超过上限时被淘汰")
    func evictsWhenCharacterLimitExceeded() {
        // 每张图片编码后约 4/3 * 64 = 86 个字符，上限设为 300 只能容纳约 3 张。
        let cache = ImageBase64Cache(maxEntries: .max, maxTotalCharacters: 300)

        for index in 0..<20 {
            cache.base64(for: Data(repeating: UInt8(index), count: 64))
        }

        #expect(cache.statistics.characters <= 300)
    }

    @Test("淘汰后缓存仍然返回正确结果")
    func evictedEntriesStillEncodeCorrectly() {
        let cache = ImageBase64Cache(maxEntries: 2, maxTotalCharacters: .max)
        let first = Data(repeating: 0x07, count: 128)
        let second = Data(repeating: 0x08, count: 128)

        _ = cache.base64(for: first)
        _ = cache.base64(for: second)
        // 触发淘汰。
        _ = cache.base64(for: Data(repeating: 0x09, count: 128))

        #expect(cache.base64(for: first) == first.base64EncodedString())
        #expect(cache.base64(for: second) == second.base64EncodedString())
    }

    @Test("清空缓存后统计归零")
    func removeAllResetsStatistics() {
        let cache = ImageBase64Cache()
        cache.base64(for: Data(repeating: 0x05, count: 512))

        #expect(cache.statistics.entries == 1)

        cache.removeAll()

        #expect(cache.statistics.entries == 0)
        #expect(cache.statistics.characters == 0)
    }

    // MARK: - 性能回归

    @Test("重复编码同一张图片的耗时显著低于首次编码")
    func repeatedEncodingIsCheaperThanFirstEncoding() {
        // 1 MB 级别的图片：单次编码足够大，让噪声不影响结论。
        let data = Data(repeating: 0x5A, count: 1_000_000)
        let cache = ImageBase64Cache()

        // 预热：把图片放进缓存。
        _ = cache.base64(for: data)

        let iterations = 50

        let firstStart = DispatchTime.now().uptimeNanoseconds
        for _ in 0..<iterations {
            _ = data.base64EncodedString()
        }
        let firstElapsed = DispatchTime.now().uptimeNanoseconds - firstStart

        let cachedStart = DispatchTime.now().uptimeNanoseconds
        for _ in 0..<iterations {
            _ = cache.base64(for: data)
        }
        let cachedElapsed = DispatchTime.now().uptimeNanoseconds - cachedStart

        // 缓存命中必须明显更快。这里放宽到「至少快 2 倍」，既能稳定抓住
        // 「缓存没有生效」这类回归，又不依赖机器性能差异。
        #expect(cachedElapsed * 2 < firstElapsed)
    }
}
