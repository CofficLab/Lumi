import Foundation
import ProviderMessage
import Testing
@testable import PluginConversationCacheHitRate

// MARK: - 构造

private func assistantMessage(
    cached: Int?,
    total: Int?,
    inputTokens: Int? = nil,
    conversationID: UUID = UUID(),
    createdAt: Date = Date(),
    metadata: [String: String] = [:]
) -> Message {
    Message(
        conversationID: conversationID,
        role: .assistant,
        content: "assistant",
        createdAt: createdAt,
        metadata: metadata,
        inputTokenCount: inputTokens,
        cachedInputTokenCount: cached,
        cacheTotalInputTokenCount: total
    )
}

// MARK: - 采样

@Test func historyBuildsOneSamplePerUsableAssistantMessage() {
    let conversationID = UUID()
    let messages = [
        Message(conversationID: conversationID, role: .user, content: "hi"),
        assistantMessage(cached: 80, total: 100, conversationID: conversationID),
        // 未上报缓存用量：既不计入采样，也不影响累计输入。
        assistantMessage(cached: nil, total: nil, inputTokens: 500, conversationID: conversationID),
        assistantMessage(cached: 40, total: 200, conversationID: conversationID),
    ]

    let history = CacheHitRateHistory.build(from: messages)

    #expect(history.samples.count == 2)
    #expect(history.samples.map(\.hitRate) == [0.8, 0.2])
}

@Test func historyAssignsSequentialIndexesInChronologicalOrder() {
    let conversationID = UUID()
    let early = Date(timeIntervalSince1970: 100)
    let late = Date(timeIntervalSince1970: 200)
    // 故意逆序传入，验证内部按 createdAt 排序后重新编号。
    let messages = [
        assistantMessage(cached: 10, total: 100, conversationID: conversationID, createdAt: late),
        assistantMessage(cached: 90, total: 100, conversationID: conversationID, createdAt: early),
    ]

    let history = CacheHitRateHistory.build(from: messages)

    #expect(history.samples.map(\.index) == [0, 1])
    #expect(history.samples.map(\.date) == [early, late])
    #expect(history.samples.map(\.hitRate) == [0.9, 0.1])
}

@Test func historyCumulativeHitRateIsTokenWeighted() {
    let conversationID = UUID()
    let base = Date(timeIntervalSince1970: 0)
    let messages = [
        // 累计：0 / 100 = 0
        assistantMessage(cached: 0, total: 100, conversationID: conversationID, createdAt: base),
        // 累计：50 / 200 = 0.25
        assistantMessage(cached: 50, total: 100, conversationID: conversationID, createdAt: base.addingTimeInterval(1)),
        // 累计：250 / 400 = 0.625
        assistantMessage(cached: 200, total: 200, conversationID: conversationID, createdAt: base.addingTimeInterval(2)),
    ]

    let history = CacheHitRateHistory.build(from: messages)

    #expect(history.samples.map(\.cumulativeHitRate) == [0, 0.25, 0.625])
    #expect(history.latestCumulativeHitRate == 0.625)
}

@Test func historyClampsCachedTokensToTotal() {
    let messages = [assistantMessage(cached: 150, total: 100)]

    let history = CacheHitRateHistory.build(from: messages)

    #expect(history.samples.count == 1)
    #expect(history.samples[0].hitRate == 1.0)
    #expect(history.samples[0].cachedTokens == 100)
}

@Test func historyFallsBackToInputTokenCountWhenTotalIsMissing() {
    let messages = [assistantMessage(cached: 30, total: nil, inputTokens: 100)]

    let history = CacheHitRateHistory.build(from: messages)

    #expect(history.samples.count == 1)
    #expect(history.samples[0].totalTokens == 100)
    #expect(history.samples[0].hitRate == 0.3)
}

@Test func historyReadsLegacyMetadataKeys() {
    let messages = [
        assistantMessage(
            cached: nil,
            total: nil,
            metadata: ["cachedInputTokens": "50", "cacheTotalInputTokens": "100"]
        ),
    ]

    let history = CacheHitRateHistory.build(from: messages)

    #expect(history.samples.count == 1)
    #expect(history.samples[0].hitRate == 0.5)
}

@Test func historySkipsNonAssistantAndInvalidSamples() {
    let conversationID = UUID()
    let messages = [
        Message(
            conversationID: conversationID,
            role: .user,
            content: "user with cache fields",
            cachedInputTokenCount: 50,
            cacheTotalInputTokenCount: 100
        ),
        assistantMessage(cached: 0, total: 0, conversationID: conversationID),
        assistantMessage(cached: -5, total: 100, conversationID: conversationID),
        assistantMessage(cached: 25, total: 100, conversationID: conversationID),
    ]

    let history = CacheHitRateHistory.build(from: messages)

    #expect(history.samples.count == 1)
    #expect(history.samples[0].hitRate == 0.25)
}

// MARK: - 统计

@Test func historyStatisticsMatchSamples() {
    let history = CacheHitRateHistory.build(from: [
        assistantMessage(cached: 0, total: 100),
        assistantMessage(cached: 50, total: 100),
        assistantMessage(cached: 100, total: 100),
    ])

    #expect(history.minimumHitRate == 0)
    #expect(history.maximumHitRate == 1)
    #expect(history.averageHitRate == 0.5)
    #expect(history.isEmpty == false)
}

@Test func emptyHistoryHasNoStatistics() {
    let history = CacheHitRateHistory.empty

    #expect(history.isEmpty)
    #expect(history.samples.isEmpty)
    #expect(history.minimumHitRate == nil)
    #expect(history.maximumHitRate == nil)
    #expect(history.averageHitRate == nil)
    #expect(history.latestCumulativeHitRate == nil)
}

// MARK: - 与聚合统计的口径一致性

@Test func historyAndStatsAgreeOnParsing() {
    let messages = [
        assistantMessage(cached: 80, total: 100),
        assistantMessage(cached: nil, total: nil, inputTokens: 500),
        assistantMessage(cached: 40, total: 200),
    ]

    let history = CacheHitRateHistory.build(from: messages)
    let stats = CacheHitRateStats.compute(messages: messages)

    #expect(history.samples.count == stats.sampleCount)
    #expect(history.averageHitRate == stats.averageHitRate)
    #expect(history.latestCumulativeHitRate == stats.weightedHitRate)
}

// MARK: - 百分比格式化

@Test func percentTextKeepsOneDecimalForSmallNonZeroRates() {
    #expect(CacheHitRateLineChart.percentText(0) == "0%")
    #expect(CacheHitRateLineChart.percentText(0.004) == "0.4%")
    #expect(CacheHitRateLineChart.percentText(0.1) == "10%")
    #expect(CacheHitRateLineChart.percentText(0.625) == "62%")
    #expect(CacheHitRateLineChart.percentText(1) == "100%")
}
