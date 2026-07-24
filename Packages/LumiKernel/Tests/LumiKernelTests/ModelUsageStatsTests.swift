import Foundation
import Testing
@testable import LumiKernel

@Suite("ModelUsageStatsService")
struct ModelUsageStatsTests {
    private var calendar: Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        return cal
    }

    /// 构造一条带 token 元数据的 assistant 消息。
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
            inputTokenCount: inputTokens,
            outputTokenCount: outputTokens
        )
    }

    private func calendar(from components: DateComponents) -> Date {
        calendar.date(from: components)!
    }

    // MARK: - Daily usage

    @Test func dailyUsageAggregatesSameDay() throws {
        let now = calendar(from: DateComponents(year: 2026, month: 6, day: 26, hour: 12))
        let today = calendar.startOfDay(for: now)
        let provider = LumiLLMProviderInfo(
            id: "openai", displayName: "OpenAI", description: "",
            defaultModel: "gpt", availableModels: ["gpt"],
            websiteURL: URL(string: "https://example.com")!
        )

        let messages = [
            assistantMessage(provider: "openai", model: "gpt", createdAt: today, inputTokens: 100, outputTokens: 200),
            assistantMessage(provider: "openai", model: "gpt", createdAt: today.addingTimeInterval(60), inputTokens: 50, outputTokens: 10),
        ]

        let snapshot = ModelUsageStatsService.buildSnapshot(
            messages: messages,
            providers: [provider],
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
        let now = calendar(from: DateComponents(year: 2026, month: 6, day: 26, hour: 12))
        let today = calendar.startOfDay(for: now)
        let provider = LumiLLMProviderInfo(
            id: "openai", displayName: "OpenAI", description: "",
            defaultModel: "gpt", availableModels: ["gpt"],
            websiteURL: URL(string: "https://example.com")!
        )

        // Only one message today, nothing in between.
        let messages = [
            assistantMessage(provider: "openai", model: "gpt", createdAt: today, inputTokens: 10, outputTokens: 20),
        ]

        let snapshot = ModelUsageStatsService.buildSnapshot(
            messages: messages,
            providers: [provider],
            dailyUsageWindowDays: 5,
            calendar: calendar,
            now: now
        )

        let series = try #require(snapshot.dailyUsage["openai|gpt"])
        #expect(series.buckets.count == 5)
        // First four buckets are zero, last (today) holds the usage.
        #expect(series.buckets.dropLast().allSatisfy { $0.totalTokens == 0 })
        #expect(series.buckets.last?.totalTokens == 30)
    }

    @Test func dailyUsageSplitsDaysAtMidnightBoundary() throws {
        let now = calendar(from: DateComponents(year: 2026, month: 6, day: 26, hour: 12))
        let today = calendar.startOfDay(for: now)
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today)!
        let provider = LumiLLMProviderInfo(
            id: "openai", displayName: "OpenAI", description: "",
            defaultModel: "gpt", availableModels: ["gpt"],
            websiteURL: URL(string: "https://example.com")!
        )

        let messages = [
            assistantMessage(provider: "openai", model: "gpt", createdAt: today, inputTokens: 0, outputTokens: 5),
            assistantMessage(provider: "openai", model: "gpt", createdAt: yesterday, inputTokens: 0, outputTokens: 7),
        ]

        let snapshot = ModelUsageStatsService.buildSnapshot(
            messages: messages,
            providers: [provider],
            dailyUsageWindowDays: 3,
            calendar: calendar,
            now: now
        )

        let series = try #require(snapshot.dailyUsage["openai|gpt"])
        #expect(series.buckets.count == 3)
        // window = [day-before-yesterday, yesterday, today]
        #expect(series.buckets[1].day == yesterday)
        #expect(series.buckets[1].totalTokens == 7)
        #expect(series.buckets[2].day == today)
        #expect(series.buckets[2].totalTokens == 5)
    }

    @Test func dailyUsageIgnoresMessagesOutsideWindow() {
        let now = calendar(from: DateComponents(year: 2026, month: 6, day: 26, hour: 12))
        let provider = LumiLLMProviderInfo(
            id: "openai", displayName: "OpenAI", description: "",
            defaultModel: "gpt", availableModels: ["gpt"],
            websiteURL: URL(string: "https://example.com")!
        )

        // 30 days ago is outside a 7-day window.
        let old = calendar.date(byAdding: .day, value: -30, to: calendar.startOfDay(for: now))!
        let messages = [
            assistantMessage(provider: "openai", model: "gpt", createdAt: old, inputTokens: 999, outputTokens: 999),
        ]

        let snapshot = ModelUsageStatsService.buildSnapshot(
            messages: messages,
            providers: [provider],
            dailyUsageWindowDays: 7,
            calendar: calendar,
            now: now
        )

        // No buckets produced for this provider|model (all-zero series is not emitted).
        #expect(snapshot.dailyUsage["openai|gpt"] == nil)
    }

    @Test func dailyUsageIsolatesModelsOnSameDay() {
        let now = calendar(from: DateComponents(year: 2026, month: 6, day: 26, hour: 12))
        let today = calendar.startOfDay(for: now)
        let provider = LumiLLMProviderInfo(
            id: "openai", displayName: "OpenAI", description: "",
            defaultModel: "gpt", availableModels: ["gpt", "gpt-mini"],
            websiteURL: URL(string: "https://example.com")!
        )

        let messages = [
            assistantMessage(provider: "openai", model: "gpt", createdAt: today, inputTokens: 100, outputTokens: 0),
            assistantMessage(provider: "openai", model: "gpt-mini", createdAt: today, inputTokens: 0, outputTokens: 50),
        ]

        let snapshot = ModelUsageStatsService.buildSnapshot(
            messages: messages,
            providers: [provider],
            dailyUsageWindowDays: 7,
            calendar: calendar,
            now: now
        )

        #expect(snapshot.dailyUsage["openai|gpt"]?.buckets.last?.totalTokens == 100)
        #expect(snapshot.dailyUsage["openai|gpt-mini"]?.buckets.last?.totalTokens == 50)
    }

    @Test func dailyUsageToleratesMissingTokenMetadata() {
        let now = calendar(from: DateComponents(year: 2026, month: 6, day: 26, hour: 12))
        let provider = LumiLLMProviderInfo(
            id: "openai", displayName: "OpenAI", description: "",
            defaultModel: "gpt", availableModels: ["gpt"],
            websiteURL: URL(string: "https://example.com")!
        )

        // No token metadata at all → contributes 0.
        let message = LumiChatMessage(
            conversationID: UUID(),
            role: .assistant,
            content: "x",
            createdAt: calendar.startOfDay(for: now),
            providerID: "openai",
            modelName: "gpt"
        )

        let snapshot = ModelUsageStatsService.buildSnapshot(
            messages: [message],
            providers: [provider],
            dailyUsageWindowDays: 3,
            calendar: calendar,
            now: now
        )

        // All-zero series is not emitted.
        #expect(snapshot.dailyUsage["openai|gpt"] == nil)
    }

    // MARK: - TPS aggregation

    @Test func statsAggregatesTPS() {
        let provider = LumiLLMProviderInfo(
            id: "openai",
            displayName: "OpenAI",
            description: "Test",
            defaultModel: "gpt-fast",
            availableModels: ["gpt-fast", "gpt-slow"],
            websiteURL: URL(string: "https://example.com")!
        )

        let messages = [
            LumiChatMessage(
                conversationID: UUID(),
                role: .assistant,
                content: "fast",
                providerID: "openai",
                modelName: "gpt-fast",
                inputTokenCount: 1,
                outputTokenCount: 100,
                latencyMs: 3_000,
                timeToFirstTokenMs: 500,
                streamingDurationMs: 1_000
            ),
            LumiChatMessage(
                conversationID: UUID(),
                role: .assistant,
                content: "slow",
                providerID: "openai",
                modelName: "gpt-slow",
                inputTokenCount: 1,
                outputTokenCount: 50,
                latencyMs: 6_000,
                timeToFirstTokenMs: 1_000,
                streamingDurationMs: 5_000
            ),
        ]

        let snapshot = ModelUsageStatsService.buildSnapshot(messages: messages, providers: [provider])

        #expect(snapshot.detailedStats["openai|gpt-fast"]?.avgTPS == 100)
        #expect(snapshot.detailedStats["openai|gpt-slow"]?.avgTPS == 10)
        #expect(snapshot.fastModels.first?.model == "gpt-fast")
        #expect(snapshot.fastModels.first?.avgTPS == 100)
    }
}
