import Foundation
import Testing
@testable import KitLLM

/// `APIKeyMemoryCache` 的 TTL 语义：read-through 命中、过期回源、负缓存、
/// stale-if-error 回退所需的「最近已知条目」。
struct APIKeyMemoryCacheTests {

    @Test("TTL 内命中，过期后视为未命中")
    func freshWithinTTL() {
        let cache = APIKeyMemoryCache()
        let t0 = Date(timeIntervalSince1970: 1_000)

        cache.remember("sk-1", forKey: "k", now: t0)

        #expect(cache.entry(forKey: "k", maxAge: 60, now: t0.addingTimeInterval(59))?.value == "sk-1")
        #expect(cache.entry(forKey: "k", maxAge: 60, now: t0.addingTimeInterval(60))?.value == "sk-1")
        #expect(cache.entry(forKey: "k", maxAge: 60, now: t0.addingTimeInterval(61)) == nil)
    }

    @Test("负缓存条目区分「确认不存在」与「未命中」")
    func negativeEntry() {
        let cache = APIKeyMemoryCache()
        let t0 = Date(timeIntervalSince1970: 1_000)

        cache.rememberMissing(forKey: "k", now: t0)

        let entry = cache.entry(forKey: "k", maxAge: 60, now: t0)
        #expect(entry != nil)
        #expect(entry?.value == nil)
    }

    @Test("lastKnownEntry 不校验新鲜度，供 stale-if-error 回退")
    func lastKnownIgnoresTTL() {
        let cache = APIKeyMemoryCache()
        let t0 = Date(timeIntervalSince1970: 1_000)

        cache.remember("sk-old", forKey: "k", now: t0)

        // 过期后 entry 未命中，但 lastKnownEntry 仍返回旧值。
        #expect(cache.entry(forKey: "k", maxAge: 1, now: t0.addingTimeInterval(100)) == nil)
        #expect(cache.lastKnownEntry(forKey: "k")?.value == "sk-old")
    }

    @Test("remove 立即清空条目")
    func removeClears() {
        let cache = APIKeyMemoryCache()
        cache.remember("sk-1", forKey: "k")

        cache.remove(forKey: "k")

        #expect(cache.entry(forKey: "k", maxAge: 60) == nil)
        #expect(cache.lastKnownEntry(forKey: "k") == nil)
    }

    @Test("remember 覆盖同 key 的旧条目（含负缓存）")
    func rememberOverwrites() {
        let cache = APIKeyMemoryCache()
        cache.rememberMissing(forKey: "k")

        cache.remember("sk-2", forKey: "k")

        #expect(cache.entry(forKey: "k", maxAge: 60)?.value == "sk-2")
    }
}
