import Foundation
import Testing
import LumiCoreKit
@testable import LumiChatKit

@Suite struct ModelUsageStatsServiceTests {
    private var calendar: Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        return cal
    }

    private func assistantMessage(
        provider: String,
        model: String,
        createdAt: Date,
        inputTokens: Int = 0,
        outputTokens: Int = 0
    ) -> LumiChatMessage {
        LumiChatMessage(
            conversationID: UUID(),
            role: .assistant,
            content: "x",
            createdAt: createdAt,
            providerID: provider,
            modelName: model,
            metadata: LumiMessageTokenMetadata.metadata(inputTokens: inputTokens, outputTokens: outputTokens)
        )
    }

    private func provider(id: String, models: [String]) -> LumiLLMProviderInfo {
        LumiLLMProviderInfo(
            id: id, displayName: id, description: "",
            defaultModel: models.first ?? "m", availableModels: models,
            websiteURL: URL(string: "https://example.com")!
        )
    }

    // MARK: - Daily usage

    @Test func dailyUsageAggregatesSameDay() throws {
        let now = calendar.date(from: DateComponents(year: 2026, month: 6, day: 26, hour: 12))!
        let today = calendar.startOfDay(for: now)

        let messages = [
            assistantMessage(provider: "openai", model: "gpt", createdAt: today, inputTokens: 100, outputTokens: 200),
            assistantMessage(provider: "openai", model: "gpt", createdAt: today.addingTimeInterval(60), inputTokens: 50, outputTokens: 10),
        ]

        let snapshot = ModelUsageStatsService.buildSnapshot(
            messages: messages,
            providers: [provider(id: "openai", models: ["gpt"])],
            dailyUsageWindowDays: 7,
            calendar: calendar,
            now: now
        )

        let series = try #require(snapshot.dailyUsage["openai|gpt"])
        #expect(series.buckets.count == 7)
        #expect(series.buckets.last?.day == today)
        let todayBucket = try #require(series.buckets.last)
        #expect(todayBucket.inputTokens == 150)
        #expect(todayBucket.outputTokens == 210)
        #expect(todayBucket.totalTokens == 360)
        #expect(series.totalTokens == 360)
    }

    @Test func dailyUsageFillsZeroDaysToKeepSeriesContinuous() throws {
        let now = calendar.date(from: DateComponents(year: 2026, month: 6, day: 26, hour: 12))!
        let today = calendar.startOfDay(for: now)

        let messages = [
            assistantMessage(provider: "openai", model: "gpt", createdAt: today, inputTokens: 10, outputTokens: 20),
        ]

        let snapshot = ModelUsageStatsService.buildSnapshot(
            messages: messages,
            providers: [provider(id: "openai", models: ["gpt"])],
            dailyUsageWindowDays: 5,
            calendar: calendar,
            now: now
        )

        let series = try #require(snapshot.dailyUsage["openai|gpt"])
        #expect(series.buckets.count == 5)
        #expect(series.buckets.dropLast().allSatisfy { $0.totalTokens == 0 })
        #expect(series.buckets.last?.totalTokens == 30)
    }

    @Test func dailyUsageIgnoresMessagesOutsideWindow() {
        let now = calendar.date(from: DateComponents(year: 2026, month: 6, day: 26, hour: 12))!
        let old = calendar.date(byAdding: .day, value: -30, to: calendar.startOfDay(for: now))!
        let messages = [
            assistantMessage(provider: "openai", model: "gpt", createdAt: old, inputTokens: 999, outputTokens: 999),
        ]

        let snapshot = ModelUsageStatsService.buildSnapshot(
            messages: messages,
            providers: [provider(id: "openai", models: ["gpt"])],
            dailyUsageWindowDays: 7,
            calendar: calendar,
            now: now
        )

        #expect(snapshot.dailyUsage["openai|gpt"] == nil)
    }

    @Test func dailyUsageIsolatesModelsOnSameDay() {
        let now = calendar.date(from: DateComponents(year: 2026, month: 6, day: 26, hour: 12))!
        let today = calendar.startOfDay(for: now)

        let messages = [
            assistantMessage(provider: "openai", model: "gpt", createdAt: today, inputTokens: 100, outputTokens: 0),
            assistantMessage(provider: "openai", model: "gpt-mini", createdAt: today, inputTokens: 0, outputTokens: 50),
        ]

        let snapshot = ModelUsageStatsService.buildSnapshot(
            messages: messages,
            providers: [provider(id: "openai", models: ["gpt", "gpt-mini"])],
            dailyUsageWindowDays: 7,
            calendar: calendar,
            now: now
        )

        #expect(snapshot.dailyUsage["openai|gpt"]?.buckets.last?.totalTokens == 100)
        #expect(snapshot.dailyUsage["openai|gpt-mini"]?.buckets.last?.totalTokens == 50)
    }

    // MARK: - Performance stats / fast models

    @Test func fastModelsRankedByTPS() {
        let p = provider(id: "openai", models: ["gpt-fast", "gpt-slow"])
        let messages = [
            LumiChatMessage(
                conversationID: UUID(), role: .assistant, content: "fast",
                providerID: "openai", modelName: "gpt-fast",
                metadata: LumiMessageTokenMetadata.metadata(inputTokens: 1, outputTokens: 100)
                    .merging(LumiMessagePerformanceMetadata.metadata(
                        latencyMs: 3_000, timeToFirstTokenMs: 500, streamingDurationMs: 1_000
                    )) { _, new in new }
            ),
            LumiChatMessage(
                conversationID: UUID(), role: .assistant, content: "slow",
                providerID: "openai", modelName: "gpt-slow",
                metadata: LumiMessageTokenMetadata.metadata(inputTokens: 1, outputTokens: 50)
                    .merging(LumiMessagePerformanceMetadata.metadata(
                        latencyMs: 6_000, timeToFirstTokenMs: 1_000, streamingDurationMs: 5_000
                    )) { _, new in new }
            ),
        ]

        let snapshot = ModelUsageStatsService.buildSnapshot(messages: messages, providers: [p])
        #expect(snapshot.detailedStats["openai|gpt-fast"]?.avgTPS == 100)
        #expect(snapshot.fastModels.first?.model == "gpt-fast")
        #expect(snapshot.fastModels.first?.avgTPS == 100)
    }
}
