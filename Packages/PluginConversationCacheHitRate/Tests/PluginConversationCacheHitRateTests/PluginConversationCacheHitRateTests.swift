import Foundation
import ProviderMessage
import Testing
@testable import PluginConversationCacheHitRate

@Test @MainActor func cacheHitRatePluginInstantiates() async throws {
    let plugin = ConversationCacheHitRatePlugin()
    #expect(plugin.id == "com.coffic.lumi.plugin.conversation-cache-hit-rate")
}

@Test func cacheHitRateStatsUseTypedTokenFields() async throws {
    let conversationID = UUID()
    let messages = [
        Message(
            conversationID: conversationID,
            role: .assistant,
            content: "first",
            cachedInputTokenCount: 80,
            cacheTotalInputTokenCount: 100
        ),
        Message(
            conversationID: conversationID,
            role: .assistant,
            content: "second",
            cachedInputTokenCount: 0,
            cacheTotalInputTokenCount: 100
        ),
    ]

    let stats = CacheHitRateStats.compute(messages: messages)

    #expect(stats.sampleCount == 2)
    #expect(stats.averageHitRate == 0.4)
    #expect(stats.totalCachedTokens == 80)
    #expect(stats.totalInputTokens == 200)
    #expect(stats.weightedHitRate == 0.4)
}

@Test func cacheHitRateStatsKeepLegacyMetadataCompatibility() async throws {
    let message = Message(
        conversationID: UUID(),
        role: .assistant,
        content: "legacy",
        metadata: [
            "cachedInputTokens": "50",
            "cacheTotalInputTokens": "100",
        ]
    )

    let stats = CacheHitRateStats.compute(messages: [message])

    #expect(stats.sampleCount == 1)
    #expect(stats.averageHitRate == 0.5)
}

@Test func cacheHitRateStatsIgnoreUnsupportedRequests() async throws {
    let message = Message(
        conversationID: UUID(),
        role: .assistant,
        content: "unsupported",
        inputTokenCount: 100
    )

    #expect(CacheHitRateStats.compute(messages: [message]) == .empty)
}
