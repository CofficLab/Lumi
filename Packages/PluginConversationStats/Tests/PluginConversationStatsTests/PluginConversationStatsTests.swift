import Testing
@testable import PluginConversationStats

@Test func cacheHitRateStatsEmpty() async throws {
    let stats = CacheHitRateStats.compute(messages: [])
    #expect(stats.sampleCount == 0)
    #expect(stats.averageHitRate == 0)
}

@Test func tokenFormatting() async throws {
    #expect(1000.formattedTokensShort == "1K")
    #expect(1500.formattedTokensShort == "2K")
    #expect(128000.formattedContextSize == "128K")
    #expect(1000000.formattedContextSize == "1M")
}
