import Foundation
import ProviderMessage
import Testing
@testable import PluginConversationCacheHitRate

@Test @MainActor func cacheHitRatePluginInstantiates() async throws {
    let plugin = ConversationCacheHitRatePlugin()
    #expect(plugin.id == "com.coffic.lumi.plugin.conversation-cache-hit-rate")
}

@Test @MainActor func cacheHitRateToolbarStateForwardsTypedEvents() {
    let state = CacheHitRateToolbarState()
    let conversationID = UUID()
    var events: [CacheHitRateToolbarState.Event] = []
    let handle = state.addObserver { events.append($0) }

    state.setSelectedConversationID(conversationID)
    state.markMessagesChanged(conversationID: conversationID)

    #expect(events.count == 2)
    handle.cancel()
    state.markMessagesChanged(conversationID: conversationID)
    #expect(events.count == 2)
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

@Test func cacheHitRateUsesTokenWeightedRateAsPrimaryValue() async throws {
    let conversationID = UUID()
    let messages = [
        Message(
            conversationID: conversationID,
            role: .assistant,
            content: "large miss",
            cachedInputTokenCount: 0,
            cacheTotalInputTokenCount: 900
        ),
        Message(
            conversationID: conversationID,
            role: .assistant,
            content: "small hit",
            cachedInputTokenCount: 100,
            cacheTotalInputTokenCount: 100
        ),
    ]

    let stats = CacheHitRateStats.compute(messages: messages)

    #expect(stats.averageHitRate == 0.5)
    #expect(stats.weightedHitRate == 0.1)
    #expect(stats.percentText == "10%")
}

@Test func cacheHitRateExplainsMissingUsage() async throws {
    #expect(CacheHitRateUnavailability.noConversationSelected.localizedExplanation.contains("No conversation"))
    #expect(CacheHitRateUnavailability.waitingForResponse.localizedExplanation.contains("Waiting"))
    #expect(CacheHitRateUnavailability.providerDidNotReportUsage.localizedExplanation.contains("did not report"))
}
