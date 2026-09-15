import Foundation
import Testing
@testable import PluginWebFetch

@Suite("Web fetch cache")
struct WebFetchCacheTests {
    @Test("keeps other entries when replacing a value at capacity")
    func updatingExistingValueDoesNotEvict() {
        let cache = WebFetchCache(maxEntries: 2, ttl: 100)
        cache.set("first", value: value("first", fetchedAt: 0), now: date(0))
        cache.set("second", value: value("old second", fetchedAt: 1), now: date(1))

        cache.set("second", value: value("new second", fetchedAt: 2), now: date(2))

        #expect(cache.get("first", now: date(2))?.content == "first")
        #expect(cache.get("second", now: date(2))?.content == "new second")
    }

    @Test("evicts only the oldest entry when adding a new key at capacity")
    func addingAtCapacityEvictsOldest() {
        let cache = WebFetchCache(maxEntries: 2, ttl: 100)
        cache.set("first", value: value("first", fetchedAt: 0), now: date(0))
        cache.set("second", value: value("second", fetchedAt: 1), now: date(1))

        cache.set("third", value: value("third", fetchedAt: 2), now: date(2))

        #expect(cache.get("first", now: date(2)) == nil)
        #expect(cache.get("second", now: date(2))?.content == "second")
        #expect(cache.get("third", now: date(2))?.content == "third")
    }

    @Test("expires entries after the configured lifetime")
    func expiresStaleValues() {
        let cache = WebFetchCache(maxEntries: 2, ttl: 10)
        cache.set("entry", value: value("cached", fetchedAt: 100), now: date(100))

        #expect(cache.get("entry", now: date(110))?.content == "cached")
        #expect(cache.get("entry", now: date(110.001)) == nil)
    }

    @Test("does not store entries when capacity is zero")
    func zeroCapacityDisablesStorage() {
        let cache = WebFetchCache(maxEntries: 0)
        cache.set("entry", value: value("not cached"), now: date(0))

        #expect(cache.get("entry", now: date(0)) == nil)
    }

    @Test("clear removes all cached entries")
    func clearRemovesEntries() {
        let cache = WebFetchCache()
        cache.set("entry", value: value("cached"), now: date(0))

        cache.clear()

        #expect(cache.get("entry", now: date(0)) == nil)
    }

    private func value(_ content: String, fetchedAt: TimeInterval = 0) -> CachedContent {
        CachedContent(
            content: content,
            contentType: "text/plain",
            statusCode: 200,
            contentSize: content.utf8.count,
            duration: 1,
            fetchedAt: date(fetchedAt)
        )
    }

    private func date(_ seconds: TimeInterval) -> Date {
        Date(timeIntervalSince1970: seconds)
    }
}
