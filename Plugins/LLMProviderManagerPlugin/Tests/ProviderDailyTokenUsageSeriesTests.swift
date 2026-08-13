import Foundation
import KernelLumi
import Testing
@testable import LLMProviderManagerPlugin

@Suite struct ProviderDailyTokenUsageSeriesTests {
    @Test func buildsSortedTotalsAndPeak() throws {
        let calendar = Calendar(identifier: .gregorian)
        let day1 = try #require(calendar.date(from: DateComponents(year: 2026, month: 7, day: 29)))
        let day2 = try #require(calendar.date(byAdding: .day, value: 1, to: day1))

        let series = ProviderDailyTokenUsageSeries.build(
            providerID: "openai",
            usages: [
                MessageTokenUsage(day: day2, inputTokens: 30, outputTokens: 70),
                MessageTokenUsage(day: day1, inputTokens: 10, outputTokens: 20),
            ]
        )

        #expect(series.providerID == "openai")
        #expect(series.points.map(\.day) == [day1, day2])
        #expect(series.inputTokens == 40)
        #expect(series.outputTokens == 90)
        #expect(series.totalTokens == 130)
        #expect(series.peakTokens == 100)
        #expect(series.hasData)
    }
}
