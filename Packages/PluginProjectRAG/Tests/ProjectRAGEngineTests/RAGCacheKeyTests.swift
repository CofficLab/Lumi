import Foundation
import Testing
@testable import ProjectRAGEngine

/// 缓存键必须对字段边界无歧义：query 与项目路径里的分隔符不能移动字段边界。
@Suite struct RAGCacheKeyTests {

    private func result(_ content: String) -> RAGSearchResult {
        RAGSearchResult(
            content: content,
            source: "Sources/\(content).swift",
            score: 1,
            matchKind: .semantic,
            lineRange: nil
        )
    }

    @Test func collidingQueryAndPathProduceDifferentKeys() {
        let cache = RAGCache()
        let first = cache.buildKey(query: "alpha|/tmp/B", projectPath: "/tmp/A", topK: 3)
        let second = cache.buildKey(query: "alpha", projectPath: "/tmp/B|/tmp/A", topK: 3)
        #expect(first != second)
    }

    @Test func cacheMissesAcrossCollidingTriples() {
        let cache = RAGCache()
        let firstKey = cache.buildKey(query: "alpha|/tmp/B", projectPath: "/tmp/A", topK: 3)
        cache.set(key: firstKey, results: [result("fromA")])

        let secondKey = cache.buildKey(query: "alpha", projectPath: "/tmp/B|/tmp/A", topK: 3)
        #expect(cache.get(key: secondKey) == nil)
    }

    @Test func identicalTriplesShareCacheEntry() {
        let cache = RAGCache()
        let firstKey = cache.buildKey(query: "alpha", projectPath: "/tmp/A", topK: 3)
        cache.set(key: firstKey, results: [result("shared")])

        let secondKey = cache.buildKey(query: "alpha", projectPath: "/tmp/A", topK: 3)
        #expect(firstKey == secondKey)
        #expect(cache.get(key: secondKey)?.first?.content == "shared")
    }

    @Test func topKParticipatesInTheKey() {
        let cache = RAGCache()
        let firstKey = cache.buildKey(query: "alpha", projectPath: "/tmp/A", topK: 3)
        let secondKey = cache.buildKey(query: "alpha", projectPath: "/tmp/A", topK: 4)
        #expect(firstKey != secondKey)
    }

    @Test func replacedProjectPathStillMisses() {
        let cache = RAGCache()
        let firstKey = cache.buildKey(query: "alpha", projectPath: "/tmp/A", topK: 3)
        cache.set(key: firstKey, results: [result("fromA")])

        let secondKey = cache.buildKey(query: "alpha", projectPath: "/tmp/B", topK: 3)
        #expect(cache.get(key: secondKey) == nil)
    }
}
