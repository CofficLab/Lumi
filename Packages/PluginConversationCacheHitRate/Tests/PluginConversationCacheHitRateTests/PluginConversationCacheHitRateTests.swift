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

@Test func cacheHitRateExplainsMissingUsageWithDistinctNonEmptyText() {
    let explanations = [
        CacheHitRateUnavailability.noConversationSelected.localizedExplanation,
        CacheHitRateUnavailability.waitingForResponse.localizedExplanation,
        CacheHitRateUnavailability.providerDidNotReportUsage.localizedExplanation,
    ]

    #expect(explanations.allSatisfy { !$0.isEmpty })
    #expect(Set(explanations).count == 3)
}

@Test func cacheHitRateLocalizationCatalogDefinesAllReasons() throws {
    let catalogURL = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .appendingPathComponent("Resources/Localizable.xcstrings")
    let data = try Data(contentsOf: catalogURL)
    let json = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
    let strings = try #require(json["strings"] as? [String: Any])

    let keys = [
        "No conversation selected. Select a conversation to see cache hit rate.",
        "Waiting for the first assistant response with cache usage data.",
        "The provider did not report cache token usage for this conversation. The model or endpoint may not support caching, the stable prefix may be too short, or no cache has been created yet.",
    ]

    for key in keys {
        let entry = try #require(strings[key] as? [String: Any], "Missing catalog entry for \(key)")
        let localizations = try #require(entry["localizations"] as? [String: Any])
        for language in ["en", "zh-Hans"] {
            let localization = try #require(localizations[language] as? [String: Any])
            let unit = try #require(localization["stringUnit"] as? [String: Any])
            let value = try #require(unit["value"] as? String)
            #expect(!value.isEmpty)
        }
    }
}

@Test func cacheHitRatePrecisePercentTextRendersOneDecimal() {
    let stats = CacheHitRateStats(
        sampleCount: 1,
        averageHitRate: 0.15,
        totalCachedTokens: 15,
        totalInputTokens: 100
    )

    #expect(stats.weightedHitRate == 0.15)
    #expect(stats.percentText == "15%")
    #expect(stats.precisePercentText == "15.0%")
}

@Test func cacheHitRateEmptyStatsHaveZeroWeightedRate() {
    #expect(CacheHitRateStats.empty.weightedHitRate == 0)
    #expect(CacheHitRateStats.empty.percentText == "0%")
}

@Test @MainActor func toolbarStateDoesNotNotifyWhenSelectedConversationIsUnchanged() {
    let state = CacheHitRateToolbarState()
    let id = UUID()
    var events: [CacheHitRateToolbarState.Event] = []
    let handle = state.addObserver { events.append($0) }

    state.setSelectedConversationID(id)
    state.setSelectedConversationID(id)
    #expect(events.count == 1)

    state.setSelectedConversationID(nil)
    #expect(events.count == 2)
    handle.cancel()
}

@Test func cacheHitRateBoundsCachedTokensToTotalTokens() {
    let messages = [
        Message(
            conversationID: UUID(),
            role: .assistant,
            content: "overflow",
            cachedInputTokenCount: 150,
            cacheTotalInputTokenCount: 100
        ),
    ]

    let stats = CacheHitRateStats.compute(messages: messages)

    #expect(stats.sampleCount == 1)
    #expect(stats.totalCachedTokens == 100)
    #expect(stats.totalInputTokens == 100)
    #expect(stats.weightedHitRate == 1.0)
}

@Test func cacheHitRateIgnoresNonAssistantMessages() {
    let messages = [
        Message(
            conversationID: UUID(),
            role: .user,
            content: "hi",
            cachedInputTokenCount: 50,
            cacheTotalInputTokenCount: 100
        ),
        Message(
            conversationID: UUID(),
            role: .assistant,
            content: "ok",
            cachedInputTokenCount: 25,
            cacheTotalInputTokenCount: 100
        ),
    ]

    let stats = CacheHitRateStats.compute(messages: messages)

    #expect(stats.sampleCount == 1)
    #expect(stats.totalCachedTokens == 25)
    #expect(stats.totalInputTokens == 100)
}

@Test func cacheHitRateSkipsRequestsWithNonPositiveTotal() {
    let messages = [
        Message(
            conversationID: UUID(),
            role: .assistant,
            content: "zero",
            cachedInputTokenCount: 0,
            cacheTotalInputTokenCount: 0
        ),
    ]

    #expect(CacheHitRateStats.compute(messages: messages) == .empty)
}

@Test func cacheHitRateSkipsRequestsWithNegativeCachedTokens() {
    let messages = [
        Message(
            conversationID: UUID(),
            role: .assistant,
            content: "negative",
            cachedInputTokenCount: -5,
            cacheTotalInputTokenCount: 100
        ),
    ]

    #expect(CacheHitRateStats.compute(messages: messages) == .empty)
}

@Test func cacheHitRateFallsBackToInputTokenCountWhenTotalIsMissing() {
    let messages = [
        Message(
            conversationID: UUID(),
            role: .assistant,
            content: "legacy-total",
            inputTokenCount: 100,
            cachedInputTokenCount: 30
        ),
    ]

    let stats = CacheHitRateStats.compute(messages: messages)

    #expect(stats.sampleCount == 1)
    #expect(stats.totalCachedTokens == 30)
    #expect(stats.totalInputTokens == 100)
    #expect(stats.weightedHitRate == 0.3)
}
