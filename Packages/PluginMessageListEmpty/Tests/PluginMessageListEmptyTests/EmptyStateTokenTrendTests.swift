import Foundation
import Testing
@testable import PluginMessageListEmpty

/// Covers the token series that feeds the trend line under the activity strip.
///
/// These tests exercise the pure date-bucketing helpers rather than the async
/// load path, so they stay deterministic without a live message store.
///
/// `@MainActor` is required on the suite because constructing the view model and
/// reading its stored totals are main-actor state; only the bucketing helpers
/// and the formatter are `nonisolated`.
@MainActor
@Suite("Empty state token trend")
struct EmptyStateTokenTrendTests {
    private let calendar = Calendar(identifier: .gregorian)

    @Test("token days fill the whole window including idle days")
    func tokenDaysFillWindow() throws {
        let today = calendar.startOfDay(for: .now)
        let start = try #require(calendar.date(byAdding: .day, value: -2, to: today))

        let days = EmptyStateActivityViewModel.makeTokenDays(
            counts: [start: 120],
            startDate: start,
            endDate: today,
            calendar: calendar
        )

        #expect(days.count == 3)
        #expect(days.map(\.count) == [120, 0, 0])
        #expect(days.map(\.date) == [start, try #require(calendar.date(byAdding: .day, value: 1, to: start)), today])
    }

    @Test("token days normalize timestamps falling inside the same day")
    func tokenDaysNormalizeToDayBuckets() throws {
        let today = calendar.startOfDay(for: .now)
        let start = try #require(calendar.date(byAdding: .day, value: -1, to: today))
        let midday = try #require(calendar.date(byAdding: .hour, value: 12, to: start))
        let evening = try #require(calendar.date(byAdding: .hour, value: 20, to: start))

        let days = EmptyStateActivityViewModel.makeTokenDays(
            counts: [midday: 30, evening: 12],
            startDate: start,
            endDate: today,
            calendar: calendar
        )

        // Two writes on the same calendar day must merge into one bucket, and
        // the merged value is the larger of the two, not their sum: the provider
        // already returns per-day totals, so summing would double count.
        #expect(days.map(\.count) == [30, 0])
    }

    @Test("no token consumption keeps the trend hidden")
    func tokenActivityIsHiddenWhenEmpty() async throws {
        let today = calendar.startOfDay(for: .now)
        let start = try #require(calendar.date(byAdding: .day, value: -2, to: today))

        let model = EmptyStateActivityViewModel(
            messages: nil,
            calendar: calendar,
            seededTokenDays: EmptyStateActivityViewModel.makeTokenDays(
                counts: [:],
                startDate: start,
                endDate: today,
                calendar: calendar
            )
        )

        #expect(model.hasTokenActivity == false)
    }

    @Test("seeded token days make the trend visible")
    func seededTokenDaysEnableTrend() throws {
        let today = calendar.startOfDay(for: .now)
        let start = try #require(calendar.date(byAdding: .day, value: -2, to: today))

        let model = EmptyStateActivityViewModel(
            messages: nil,
            calendar: calendar,
            seededTokenDays: EmptyStateActivityViewModel.makeTokenDays(
                counts: [start: 4_200],
                startDate: start,
                endDate: today,
                calendar: calendar
            )
        )

        #expect(model.hasTokenActivity == true)
        #expect(model.totalTokens == 4_200)
    }
}

/// The compact token formatter is used for both the chart tooltip and the
/// caption, so its thresholds are part of the visible copy.
@Suite("Compact token formatting")
struct CompactTokenCountTests {
    @Test("values below one thousand are shown verbatim")
    func smallValuesVerbatim() {
        #expect(ActivityTokenTrendView.compactTokenCount(0) == "0")
        #expect(ActivityTokenTrendView.compactTokenCount(999) == "999")
    }

    @Test("thousands switch to one decimal below one hundred units")
    func thousandsFormatting() {
        #expect(ActivityTokenTrendView.compactTokenCount(1_000) == "1.0K")
        #expect(ActivityTokenTrendView.compactTokenCount(12_345) == "12.3K")
        // At or above 100 units the decimal is noise and gets dropped.
        #expect(ActivityTokenTrendView.compactTokenCount(150_000) == "150K")
    }

    @Test("millions and billions use their own suffixes")
    func largeMagnitudes() {
        #expect(ActivityTokenTrendView.compactTokenCount(1_000_000) == "1.0M")
        // 43.98M is still below the 100-unit cutoff, so it keeps one decimal.
        #expect(ActivityTokenTrendView.compactTokenCount(43_982_407) == "44.0M")
        #expect(ActivityTokenTrendView.compactTokenCount(150_000_000) == "150M")
        #expect(ActivityTokenTrendView.compactTokenCount(1_000_000_000) == "1.0B")
    }
}
